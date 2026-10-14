package com.skytrace.monitor

import android.content.Context
import com.skytrace.proxy.ByteTransport
import com.skytrace.proxy.HttpParser
import com.skytrace.proxy.MessageReader
import com.skytrace.proxy.ParsedRequestHead
import com.skytrace.proxy.SocketTransport
import com.skytrace.proxy.headerValue
import com.skytrace.proxy.statusReason
import com.skytrace.repo.Graph
import com.skytrace.repo.TrafficFilter
import com.skytrace.repo.TrafficSummary
import com.skytrace.util.EventBus
import com.skytrace.util.Logger
import com.skytrace.util.NetUtil
import com.skytrace.vpn.LiveStats
import com.skytrace.vpn.VpnServiceManager
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

class MonitorSession(val ip: String, @Volatile var lastTouch: Long)

class MonitorServer(private val context: Context, private val scope: CoroutineScope) {

    private var server: ServerSocket? = null
    private var acceptJob: Job? = null
    private val sessions = ConcurrentHashMap<String, MonitorSession>()
    private val failures = ConcurrentHashMap<String, MutableList<Long>>()
    private val lockedUntil = ConcurrentHashMap<String, Long>()
    private val globalFailures = mutableListOf<Long>()
    @Volatile
    private var globalLockedUntil = 0L
    private val active = AtomicInteger(0)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val indexHtml: ByteArray by lazy { context.assets.open("monitor/index.html").use { it.readBytes() } }
    private val logoPng: ByteArray by lazy { context.assets.open("monitor/logo.png").use { it.readBytes() } }

    val sessionCount: Int
        get() {
            purge()
            return sessions.size
        }

    fun start(port: Int) {
        val s = ServerSocket()
        s.reuseAddress = true
        s.bind(InetSocketAddress(port))
        server = s
        acceptJob = scope.launch(Dispatchers.IO) {
            while (isActive && !s.isClosed) {
                try {
                    val client = s.accept()
                    if (active.get() >= MAX_CONNECTIONS) {
                        client.close()
                        continue
                    }
                    launch {
                        active.incrementAndGet()
                        try {
                            handle(client)
                        } finally {
                            active.decrementAndGet()
                        }
                    }
                } catch (e: Exception) {
                    if (!s.isClosed) Logger.w("monitor accept failed", e)
                }
            }
        }
    }

    fun invalidateSessions() {
        sessions.clear()
    }

    fun stop() {
        acceptJob?.cancel()
        acceptJob = null
        try {
            server?.close()
        } catch (e: Exception) {
            Logger.d("monitor close failed")
        }
        server = null
        sessions.clear()
    }

    private fun purge() {
        val now = System.currentTimeMillis()
        sessions.entries.removeIf { now - it.value.lastTouch > IDLE_MS }
    }

    private suspend fun handle(socket: Socket) {
        val transport = SocketTransport(socket)
        try {
            socket.soTimeout = 20_000
            val remote = socket.inetAddress
            if (!NetUtil.isLan(remote)) {
                respond(transport, 403, "text/plain; charset=utf-8", "Forbidden".toByteArray())
                return
            }
            val ip = remote.hostAddress ?: "unknown"
            val reader = MessageReader(transport)
            val raw = reader.readHead(16 * 1024) ?: return
            val head = HttpParser.parseRequestHead(raw)
            val body = HttpParser.readRequestBody(reader, head.headers, 64L * 1024)
            val path = head.target.substringBefore('?')
            val query = parseQuery(head.target.substringAfter('?', ""))
            route(transport, reader, socket, head, path, query, body, ip)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Logger.d("monitor connection ended: ${e.javaClass.simpleName}: ${e.message}")
        } finally {
            transport.close()
        }
    }

    private fun parseQuery(raw: String): Map<String, String> {
        if (raw.isEmpty()) return emptyMap()
        val out = HashMap<String, String>()
        for (pair in raw.split('&')) {
            if (pair.isEmpty()) continue
            val key = URLDecoder.decode(pair.substringBefore('='), "UTF-8")
            val value = URLDecoder.decode(pair.substringAfter('=', ""), "UTF-8")
            out[key] = value
        }
        return out
    }

    private fun filterFrom(q: Map<String, String>): TrafficFilter {
        fun s(key: String): String? = q[key]?.takeIf { it.isNotBlank() }
        return TrafficFilter(
            app = s("app"),
            method = s("method"),
            status = s("status"),
            domain = s("domain"),
            contentType = s("type"),
            search = s("q"),
            searchBodies = q["bodies"] == "1",
            onlyModified = q["modified"] == "1"
        )
    }

    private fun filterFromJson(obj: JsonObject): TrafficFilter {
        val map = HashMap<String, String>()
        for ((k, v) in obj) {
            val p = v as? JsonPrimitive ?: continue
            map[k] = p.content
            if (p.booleanOrNull == true) map[k] = "1"
        }
        return filterFrom(map)
    }

    private fun authenticate(head: ParsedRequestHead, ip: String): Pair<String, MonitorSession>? {
        val cookie = head.headers.headerValue("Cookie") ?: return null
        val token = cookie.split(';').map { it.trim() }.firstOrNull { it.startsWith("st_session=") }
            ?.substringAfter('=') ?: return null
        val session = sessions[token] ?: return null
        val now = System.currentTimeMillis()
        if (now - session.lastTouch > IDLE_MS || session.ip != ip) {
            sessions.remove(token)
            return null
        }
        return Pair(token, session)
    }

    private fun errorJson(code: String): JsonElement = buildJsonObject { put("error", code) }

    private suspend fun route(
        t: ByteTransport,
        reader: MessageReader,
        socket: Socket,
        head: ParsedRequestHead,
        path: String,
        query: Map<String, String>,
        body: ByteArray,
        ip: String
    ) {
        val method = head.method.uppercase()
        if (method == "GET" && path == "/") {
            respond(t, 200, "text/html; charset=utf-8", indexHtml, isHtml = true)
            return
        }
        if (method == "GET" && path == "/logo.png") {
            respond(t, 200, "image/png", logoPng, cacheable = true)
            return
        }
        if (method == "POST" && path == "/api/login") {
            login(t, head, body, ip)
            return
        }
        val auth = authenticate(head, ip)
        if (auth == null) {
            respondJson(t, 401, errorJson("unauthorized"))
            return
        }
        val token = auth.first
        val session = auth.second
        if (method != "GET" && head.headers.headerValue("X-SkyTrace") != "1") {
            respondJson(t, 403, errorJson("csrf"))
            return
        }
        session.lastTouch = System.currentTimeMillis()
        val repo = Graph.repository

        when {
            method == "GET" && path == "/ws" -> websocket(t, reader, socket, head, session)
            method == "POST" && path == "/api/touch" -> respondJson(t, 200, buildJsonObject { put("ok", true) })
            method == "POST" && path == "/api/logout" -> {
                sessions.remove(token)
                respondJson(
                    t, 200, buildJsonObject { put("ok", true) },
                    listOf(Pair("Set-Cookie", "st_session=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0"))
                )
            }
            method == "GET" && path == "/api/status" -> {
                val base = VpnServiceManager.statusJson().toMutableMap()
                base["total"] = JsonPrimitive(repo.count())
                respondJson(t, 200, JsonObject(base))
            }
            method == "GET" && path == "/api/facets" -> respondJson(t, 200, repo.facets())
            method == "GET" && path == "/api/traffic" -> {
                val limit = (query["limit"]?.toIntOrNull() ?: 60).coerceIn(1, 200)
                val offset = (query["offset"]?.toIntOrNull() ?: 0).coerceAtLeast(0)
                val list = repo.list(filterFrom(query), limit, offset)
                respond(
                    t, 200, "application/json; charset=utf-8",
                    json.encodeToString(ListSerializer(TrafficSummary.serializer()), list).toByteArray()
                )
            }
            method == "GET" && path.startsWith("/api/traffic/") -> {
                val id = path.substringAfterLast('/').toLongOrNull()
                val entity = if (id == null) null else repo.get(id)
                if (entity == null) respondJson(t, 404, errorJson("not_found")) else respondJson(t, 200, repo.detailJson(entity))
            }
            method == "DELETE" && path.startsWith("/api/traffic/") -> {
                val id = path.substringAfterLast('/').toLongOrNull()
                if (id == null) {
                    respondJson(t, 400, errorJson("bad_id"))
                } else {
                    repo.delete(listOf(id))
                    respondJson(t, 200, buildJsonObject { put("deleted", 1) })
                }
            }
            method == "POST" && path == "/api/traffic/clear" -> {
                val obj = try {
                    json.parseToJsonElement(String(body)).jsonObject
                } catch (e: Exception) {
                    JsonObject(emptyMap())
                }
                val mode = obj["mode"]?.jsonPrimitive?.content ?: "all"
                val deleted = if (mode == "filter") {
                    val filterObj = obj["filter"] as? JsonObject ?: JsonObject(emptyMap())
                    repo.deleteFiltered(filterFromJson(filterObj))
                } else {
                    val count = repo.count()
                    repo.clear()
                    count
                }
                respondJson(t, 200, buildJsonObject { put("deleted", deleted) })
            }
            method == "POST" && path == "/api/pause" -> {
                val paused = try {
                    json.parseToJsonElement(String(body)).jsonObject["paused"]?.jsonPrimitive?.booleanOrNull ?: false
                } catch (e: Exception) {
                    false
                }
                LiveStats.paused = paused
                VpnServiceManager.emitStats()
                respondJson(t, 200, buildJsonObject { put("paused", paused) })
            }
            method == "GET" && path == "/api/export" -> export(t, query)
            else -> respondJson(t, 404, errorJson("not_found"))
        }
    }

    private suspend fun export(t: ByteTransport, query: Map<String, String>) {
        val repo = Graph.repository
        val ids = query["ids"]?.split(',')?.mapNotNull { it.trim().toLongOrNull() }?.takeIf { it.isNotEmpty() }
        val list = repo.entities(filterFrom(query), ids)
        val stamp = System.currentTimeMillis()
        val format = query["format"] ?: "har"
        val (content, type, name) = when (format) {
            "curl" -> Triple(repo.exportCurl(list), "text/x-shellscript; charset=utf-8", "skytrace-$stamp.sh")
            "raw" -> Triple(repo.exportRaw(list), "text/plain; charset=utf-8", "skytrace-$stamp.txt")
            else -> Triple(repo.exportHar(list), "application/json; charset=utf-8", "skytrace-$stamp.har")
        }
        respond(t, 200, type, content.toByteArray(), listOf(Pair("Content-Disposition", "attachment; filename=\"$name\"")))
    }

    private suspend fun login(t: ByteTransport, head: ParsedRequestHead, body: ByteArray, ip: String) {
        if (head.headers.headerValue("X-SkyTrace") != "1") {
            respondJson(t, 403, errorJson("csrf"))
            return
        }
        val now = System.currentTimeMillis()
        val lock = maxOf(lockedUntil[ip] ?: 0L, globalLockedUntil)
        if (now < lock) {
            val wait = ((lock - now) / 1000).coerceAtLeast(1)
            respondJson(t, 429, errorJson("locked"), listOf(Pair("Retry-After", wait.toString())))
            return
        }
        val settings = Graph.settings
        if (settings.monitorPinHash.isEmpty()) {
            respondJson(t, 503, errorJson("pin_not_set"))
            return
        }
        val pin = try {
            json.parseToJsonElement(String(body)).jsonObject["pin"]?.jsonPrimitive?.content ?: ""
        } catch (e: Exception) {
            ""
        }
        if (MonitorAuth.isValidPin(pin) && MonitorAuth.matches(settings.monitorPinSalt, settings.monitorPinHash, pin)) {
            failures.remove(ip)
            lockedUntil.remove(ip)
            purge()
            if (sessions.size >= MAX_SESSIONS) {
                sessions.entries.minByOrNull { it.value.lastTouch }?.let { sessions.remove(it.key) }
            }
            val token = MonitorAuth.newToken()
            sessions[token] = MonitorSession(ip, now)
            respondJson(
                t, 200, buildJsonObject { put("ok", true) },
                listOf(Pair("Set-Cookie", "st_session=$token; Path=/; HttpOnly; SameSite=Strict"))
            )
            return
        }
        val list = failures.getOrPut(ip) { mutableListOf() }
        synchronized(list) {
            list.add(now)
            list.removeAll { now - it > FAIL_WINDOW_MS }
            if (list.size >= MAX_FAILURES) {
                lockedUntil[ip] = now + LOCK_MS
                list.clear()
            }
        }
        synchronized(globalFailures) {
            globalFailures.add(now)
            globalFailures.removeAll { now - it > FAIL_WINDOW_MS }
            if (globalFailures.size >= MAX_GLOBAL_FAILURES) {
                globalLockedUntil = now + LOCK_MS
                globalFailures.clear()
            }
        }
        delay(500)
        respondJson(t, 401, errorJson("invalid_pin"))
    }

    private suspend fun websocket(
        t: ByteTransport,
        reader: MessageReader,
        socket: Socket,
        head: ParsedRequestHead,
        session: MonitorSession
    ) {
        val key = head.headers.headerValue("Sec-WebSocket-Key")
        val upgrade = head.headers.headerValue("Upgrade")
        if (key == null || upgrade == null || !upgrade.equals("websocket", ignoreCase = true)) {
            respondJson(t, 400, errorJson("bad_upgrade"))
            return
        }
        val origin = head.headers.headerValue("Origin")
        val host = head.headers.headerValue("Host")
        if (origin != null && host != null && origin.substringAfter("://") != host) {
            respondJson(t, 403, errorJson("bad_origin"))
            return
        }
        t.write(
            (
                "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" +
                    "Sec-WebSocket-Accept: ${MonitorProtocol.acceptKey(key)}\r\n\r\n"
                ).toByteArray()
        )
        socket.soTimeout = 0
        val writeLock = Mutex()
        suspend fun send(bytes: ByteArray) {
            writeLock.withLock { t.write(bytes) }
        }
        coroutineScope {
            val feed = launch {
                EventBus.events.collect { payload ->
                    if (!payload.startsWith("{\"type\":\"breakpoint")) send(MonitorProtocol.text(payload))
                }
            }
            val watchdog = launch {
                while (isActive) {
                    delay(25_000)
                    if (System.currentTimeMillis() - session.lastTouch > IDLE_MS) {
                        send(MonitorProtocol.frame(0x8, byteArrayOf(0x03, 0xF0.toByte())))
                        break
                    }
                    send(MonitorProtocol.frame(0x9, ByteArray(0)))
                }
                t.close()
            }
            try {
                readFrames(reader, session) { send(it) }
            } finally {
                feed.cancel()
                watchdog.cancel()
            }
        }
    }

    private suspend fun readFrames(reader: MessageReader, session: MonitorSession, send: suspend (ByteArray) -> Unit) {
        while (true) {
            val h = reader.readExactly(2)
            val opcode = h[0].toInt() and 0x0F
            val masked = (h[1].toInt() and 0x80) != 0
            var len = (h[1].toInt() and 0x7F).toLong()
            if (len == 126L) {
                val e = reader.readExactly(2)
                len = (((e[0].toInt() and 0xFF) shl 8) or (e[1].toInt() and 0xFF)).toLong()
            } else if (len == 127L) {
                val e = reader.readExactly(8)
                var v = 0L
                for (b in e) v = (v shl 8) or (b.toLong() and 0xFF)
                len = v
            }
            if (len > 4096) return
            val mask = if (masked) reader.readExactly(4) else ByteArray(4)
            val payload = reader.readExactly(len.toInt())
            if (masked) {
                for (i in payload.indices) payload[i] = (payload[i].toInt() xor mask[i % 4].toInt()).toByte()
            }
            when (opcode) {
                0x8 -> return
                0x9 -> send(MonitorProtocol.frame(0xA, payload))
                0x1 -> if (String(payload) == "touch") session.lastTouch = System.currentTimeMillis()
            }
        }
    }

    private suspend fun respondJson(
        t: ByteTransport,
        status: Int,
        element: JsonElement,
        extra: List<Pair<String, String>> = emptyList()
    ) {
        respond(t, status, "application/json; charset=utf-8", element.toString().toByteArray(), extra)
    }

    private suspend fun respond(
        t: ByteTransport,
        status: Int,
        contentType: String,
        body: ByteArray,
        extra: List<Pair<String, String>> = emptyList(),
        isHtml: Boolean = false,
        cacheable: Boolean = false
    ) {
        val sb = StringBuilder("HTTP/1.1 $status ${statusReason(status)}\r\n")
        sb.append("Content-Type: $contentType\r\nContent-Length: ${body.size}\r\nConnection: close\r\n")
        sb.append(if (cacheable) "Cache-Control: max-age=3600\r\n" else "Cache-Control: no-store\r\n")
        sb.append("X-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\nX-Frame-Options: DENY\r\n")
        if (isHtml) {
            sb.append(
                "Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; " +
                    "script-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' ws: wss:\r\n"
            )
        }
        for ((k, v) in extra) sb.append("$k: $v\r\n")
        sb.append("\r\n")
        t.write(sb.toString().toByteArray(Charsets.ISO_8859_1))
        if (body.isNotEmpty()) t.write(body)
    }

    companion object {
        private const val MAX_CONNECTIONS = 32
        private const val MAX_SESSIONS = 5
        private const val IDLE_MS = 20 * 60 * 1000L
        private const val FAIL_WINDOW_MS = 10 * 60 * 1000L
        private const val LOCK_MS = 5 * 60 * 1000L
        private const val MAX_FAILURES = 5
        private const val MAX_GLOBAL_FAILURES = 30
    }
}
