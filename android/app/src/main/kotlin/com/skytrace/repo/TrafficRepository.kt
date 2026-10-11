package com.skytrace.repo

import android.content.Context
import androidx.room.Room
import androidx.sqlite.db.SimpleSQLiteQuery
import com.skytrace.proxy.Header
import com.skytrace.rule.Breakpoint
import com.skytrace.rule.Rule
import com.skytrace.rule.RewriteEngine
import com.skytrace.util.EventBus
import com.skytrace.util.Logger
import com.skytrace.util.looksLikeText
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.io.File
import java.text.SimpleDateFormat
import java.util.Base64
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.atomic.AtomicInteger

class TrafficFilter(
    val app: String? = null,
    val method: String? = null,
    val status: String? = null,
    val domain: String? = null,
    val contentType: String? = null,
    val search: String? = null,
    val searchBodies: Boolean = false,
    val onlyModified: Boolean = false
) {
    companion object {
        fun fromMap(map: Map<*, *>?): TrafficFilter {
            if (map == null) return TrafficFilter()
            fun s(key: String): String? = (map[key] as? String)?.takeIf { it.isNotBlank() }
            return TrafficFilter(
                app = s("app"),
                method = s("method"),
                status = s("status"),
                domain = s("domain"),
                contentType = s("contentType"),
                search = s("search"),
                searchBodies = map["searchBodies"] as? Boolean ?: false,
                onlyModified = map["onlyModified"] as? Boolean ?: false
            )
        }
    }
}

class TrafficRepository(context: Context) {
    private val db: SkyDatabase = Room.databaseBuilder(context.applicationContext, SkyDatabase::class.java, "skytrace.db")
        .fallbackToDestructiveMigration()
        .build()
    private val dao = db.trafficDao()
    private val ruleDao = db.ruleDao()
    private val breakpointDao = db.breakpointDao()
    private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }
    private val insertCounter = AtomicInteger(0)

    suspend fun create(entity: TrafficEntity, maxEntries: Int): Long {
        val id = dao.insert(entity)
        entity.id = id
        if (insertCounter.incrementAndGet() % 100 == 0) {
            try {
                dao.trim(maxEntries)
            } catch (e: Exception) {
                Logger.w("trim failed", e)
            }
        }
        EventBus.emit("traffic_new", summaryJson(entity))
        return id
    }

    suspend fun finish(entity: TrafficEntity) {
        try {
            dao.update(entity)
        } catch (e: Exception) {
            Logger.e("update traffic failed", e)
        }
        EventBus.emit("traffic_update", summaryJson(entity))
    }

    suspend fun get(id: Long): TrafficEntity? = dao.byId(id)

    suspend fun clear() = dao.deleteAll()

    suspend fun delete(ids: List<Long>) = dao.deleteIds(ids)

    suspend fun count(): Int = dao.count()

    suspend fun list(filter: TrafficFilter, limit: Int, offset: Int): List<TrafficSummary> {
        val (where, args) = buildWhere(filter)
        val sql = "SELECT id, timestamp, method, scheme, host, path, statusCode, responseSize, requestSize, " +
            "responseContentType AS contentType, appPackage, appName, totalMs, modified, isWebSocket, tunnel, error " +
            "FROM traffic $where ORDER BY id DESC LIMIT ? OFFSET ?"
        val all = args.toMutableList<Any?>()
        all.add(limit)
        all.add(offset)
        return dao.summaries(SimpleSQLiteQuery(sql, all.toTypedArray()))
    }

    suspend fun entities(filter: TrafficFilter, ids: List<Long>?): List<TrafficEntity> {
        if (ids != null && ids.isNotEmpty()) {
            val marks = ids.joinToString(",") { "?" }
            return dao.entities(SimpleSQLiteQuery("SELECT * FROM traffic WHERE id IN ($marks) ORDER BY id ASC", ids.map { it as Any? }.toTypedArray()))
        }
        val (where, args) = buildWhere(filter)
        return dao.entities(SimpleSQLiteQuery("SELECT * FROM traffic $where ORDER BY id ASC LIMIT 20000", args.toTypedArray()))
    }

    private fun buildWhere(f: TrafficFilter): Pair<String, List<Any?>> {
        val clauses = mutableListOf<String>()
        val args = mutableListOf<Any?>()
        f.app?.let { clauses.add("appPackage = ?"); args.add(it) }
        f.method?.let { clauses.add("method = ?"); args.add(it.uppercase()) }
        f.status?.let {
            when (it) {
                "1xx" -> clauses.add("statusCode BETWEEN 100 AND 199")
                "2xx" -> clauses.add("statusCode BETWEEN 200 AND 299")
                "3xx" -> clauses.add("statusCode BETWEEN 300 AND 399")
                "4xx" -> clauses.add("statusCode BETWEEN 400 AND 499")
                "5xx" -> clauses.add("statusCode >= 500")
                "error" -> clauses.add("(statusCode = 0 OR error IS NOT NULL)")
                else -> it.toIntOrNull()?.let { code -> clauses.add("statusCode = ?"); args.add(code) }
            }
        }
        f.domain?.let { clauses.add("host LIKE ?"); args.add("%${escapeLike(it)}%") }
        f.contentType?.let { clauses.add("(responseContentType LIKE ? OR requestContentType LIKE ?)"); args.add("%${escapeLike(it)}%"); args.add("%${escapeLike(it)}%") }
        if (f.onlyModified) clauses.add("modified = 1")
        f.search?.let {
            val like = "%${escapeLike(it)}%"
            val parts = mutableListOf("url LIKE ?", "requestHeaders LIKE ?", "responseHeaders LIKE ?")
            args.add(like); args.add(like); args.add(like)
            if (f.searchBodies) {
                parts.add("CAST(requestBody AS TEXT) LIKE ?")
                parts.add("CAST(responseBody AS TEXT) LIKE ?")
                args.add(like); args.add(like)
            }
            clauses.add("(" + parts.joinToString(" OR ") + ")")
        }
        val where = if (clauses.isEmpty()) "" else "WHERE " + clauses.joinToString(" AND ")
        return Pair(where, args)
    }

    private fun escapeLike(s: String): String = s.replace("%", "").replace("_", "")

    suspend fun facets(): JsonObject {
        val apps = dao.appFacets()
        val hosts = dao.hostFacets()
        return buildJsonObject {
            put("apps", buildJsonArray {
                apps.forEach { add(buildJsonObject { put("appPackage", it.appPackage); put("appName", it.appName); put("requests", it.requests) }) }
            })
            put("hosts", buildJsonArray {
                hosts.forEach { add(buildJsonObject { put("host", it.host); put("requests", it.requests) }) }
            })
        }
    }

    suspend fun stats(): JsonObject {
        val totals = dao.totals()
        val apps = dao.perApp()
        val domains = dao.topDomains()
        val tb = dao.timeBuckets()
        val sb = dao.statusBuckets()
        val series = dao.series(System.currentTimeMillis() - 60 * 60 * 1000L)
        return buildJsonObject {
            put("requests", totals.requests)
            put("up", totals.up)
            put("down", totals.down)
            put("avgMs", totals.avgMs)
            put("perApp", buildJsonArray {
                apps.forEach {
                    add(buildJsonObject {
                        put("appPackage", it.appPackage); put("appName", it.appName); put("requests", it.requests)
                        put("up", it.up); put("down", it.down); put("avgMs", it.avgMs)
                    })
                }
            })
            put("topDomains", buildJsonArray {
                domains.forEach {
                    add(buildJsonObject { put("host", it.host); put("requests", it.requests); put("down", it.down); put("avgMs", it.avgMs) })
                }
            })
            put("timeBuckets", buildJsonArray { listOf(tb.b1, tb.b2, tb.b3, tb.b4, tb.b5).forEach { add(JsonPrimitive(it)) } })
            put("statusBuckets", buildJsonArray { listOf(sb.s1, sb.s2, sb.s3, sb.s4, sb.s5, sb.s0).forEach { add(JsonPrimitive(it)) } })
            put("series", buildJsonArray {
                series.forEach { add(buildJsonObject { put("minute", it.minute); put("count", it.count) }) }
            })
        }
    }

    fun summaryJson(e: TrafficEntity): JsonElement = buildJsonObject {
        put("id", e.id)
        put("timestamp", e.timestamp)
        put("method", e.method)
        put("scheme", e.scheme)
        put("host", e.host)
        put("path", e.path)
        put("statusCode", e.statusCode)
        put("responseSize", e.responseSize)
        put("requestSize", e.requestSize)
        put("contentType", e.responseContentType)
        put("appPackage", e.appPackage)
        put("appName", e.appName)
        put("totalMs", e.totalMs)
        put("modified", e.modified)
        put("isWebSocket", e.isWebSocket)
        put("tunnel", e.tunnel)
        put("error", e.error?.let { JsonPrimitive(it) } ?: kotlinx.serialization.json.JsonNull)
    }

    fun headersOf(raw: String): List<Header> = try {
        json.decodeFromString(ListSerializer(Header.serializer()), raw)
    } catch (e: Exception) {
        emptyList()
    }

    fun encodeHeaders(headers: List<Header>): String = json.encodeToString(ListSerializer(Header.serializer()), headers)

    fun detailJson(e: TrafficEntity): JsonObject {
        val reqHeaders = headersOf(e.requestHeaders)
        val resHeaders = headersOf(e.responseHeaders)
        return buildJsonObject {
            put("id", e.id)
            put("timestamp", e.timestamp)
            put("method", e.method)
            put("scheme", e.scheme)
            put("host", e.host)
            put("port", e.port)
            put("path", e.path)
            put("url", e.url)
            put("httpVersion", e.httpVersion)
            put("statusCode", e.statusCode)
            put("statusMessage", e.statusMessage)
            put("appPackage", e.appPackage)
            put("appName", e.appName)
            put("remoteIp", e.remoteIp)
            put("error", e.error?.let { JsonPrimitive(it) } ?: kotlinx.serialization.json.JsonNull)
            put("isWebSocket", e.isWebSocket)
            put("tunnel", e.tunnel)
            put("modified", e.modified)
            put("replayOf", e.replayOf)
            put("requestHeaders", headersJson(reqHeaders))
            put("responseHeaders", headersJson(resHeaders))
            put("request", bodyView(e.requestBody, reqHeaders, e.requestContentType, e.requestSize, e.requestTruncated))
            put("response", bodyView(e.responseBody, resHeaders, e.responseContentType, e.responseSize, e.responseTruncated))
            put("timings", buildJsonObject {
                put("connect", e.connectMs)
                put("tls", e.tlsMs)
                put("send", e.sendMs)
                put("wait", e.waitMs)
                put("receive", e.receiveMs)
                put("total", e.totalMs)
            })
            put("raw", rawText(e, reqHeaders, resHeaders))
        }
    }

    private fun headersJson(list: List<Header>): JsonArray = buildJsonArray {
        list.forEach { add(buildJsonObject { put("name", it.name); put("value", it.value) }) }
    }

    private fun bodyView(body: ByteArray?, headers: List<Header>, contentType: String, size: Long, truncated: Boolean): JsonObject {
        val encoding = headers.firstOrNull { it.name.equals("Content-Encoding", true) }?.value?.lowercase() ?: ""
        var bytes = body ?: ByteArray(0)
        var undecodable = false
        if (bytes.isNotEmpty() && encoding.isNotEmpty() && encoding != "identity") {
            val decoded = RewriteEngine.decodeBody(bytes, encoding)
            if (decoded == null) undecodable = true else bytes = decoded
        }
        val text = !undecodable && (looksLikeText(contentType) || (contentType.isEmpty() && isPrintable(bytes)) || isPrintable(bytes))
        return buildJsonObject {
            put("size", size)
            put("storedSize", bytes.size)
            put("truncated", truncated)
            put("contentType", contentType)
            put("encoding", encoding)
            put("isBinary", !text && bytes.isNotEmpty())
            put("text", if (text) String(bytes, Charsets.UTF_8) else "")
            put("base64", if (!text && bytes.isNotEmpty()) Base64.getEncoder().encodeToString(bytes.copyOf(minOf(bytes.size, 262144))) else "")
        }
    }

    private fun isPrintable(bytes: ByteArray): Boolean {
        if (bytes.isEmpty()) return true
        val n = minOf(bytes.size, 512)
        var bad = 0
        for (i in 0 until n) {
            val b = bytes[i].toInt() and 0xFF
            if (b < 9 || (b in 14..31)) bad++
        }
        return bad * 20 < n
    }

    private fun rawText(e: TrafficEntity, req: List<Header>, res: List<Header>): String {
        val sb = StringBuilder()
        sb.append("${e.method} ${e.path} ${e.httpVersion.ifEmpty { "HTTP/1.1" }}\r\n")
        req.forEach { sb.append("${it.name}: ${it.value}\r\n") }
        sb.append("\r\n")
        e.requestBody?.let { b -> if (looksLikeText(e.requestContentType) || isPrintable(b)) sb.append(String(b, Charsets.UTF_8)) }
        sb.append("\r\n\r\n")
        sb.append("${e.httpVersion.ifEmpty { "HTTP/1.1" }} ${e.statusCode} ${e.statusMessage}\r\n")
        res.forEach { sb.append("${it.name}: ${it.value}\r\n") }
        sb.append("\r\n")
        e.responseBody?.let { b -> if (looksLikeText(e.responseContentType) || isPrintable(b)) sb.append(String(b, Charsets.UTF_8)) }
        return sb.toString()
    }

    suspend fun listRules(): List<Rule> = ruleDao.all().mapNotNull {
        try {
            json.decodeFromString(Rule.serializer(), it.json).copy(id = it.id, enabled = it.enabled)
        } catch (e: Exception) {
            null
        }
    }

    suspend fun saveRule(rule: Rule): Long {
        val entity = RuleEntity(rule.id, json.encodeToString(Rule.serializer(), rule), rule.enabled)
        return ruleDao.upsert(entity)
    }

    suspend fun deleteRule(id: Long) = ruleDao.delete(id)

    suspend fun toggleRule(id: Long, enabled: Boolean) {
        val e = ruleDao.byId(id) ?: return
        val rule = json.decodeFromString(Rule.serializer(), e.json).copy(enabled = enabled)
        ruleDao.upsert(RuleEntity(id, json.encodeToString(Rule.serializer(), rule), enabled))
    }

    suspend fun listBreakpoints(): List<Breakpoint> = breakpointDao.all().mapNotNull {
        try {
            json.decodeFromString(Breakpoint.serializer(), it.json).copy(id = it.id, enabled = it.enabled)
        } catch (e: Exception) {
            null
        }
    }

    suspend fun saveBreakpoint(bp: Breakpoint): Long {
        val entity = BreakpointEntity(bp.id, json.encodeToString(Breakpoint.serializer(), bp), bp.enabled)
        return breakpointDao.upsert(entity)
    }

    suspend fun deleteBreakpoint(id: Long) = breakpointDao.delete(id)

    suspend fun toggleBreakpoint(id: Long, enabled: Boolean) {
        val e = breakpointDao.byId(id) ?: return
        val bp = json.decodeFromString(Breakpoint.serializer(), e.json).copy(enabled = enabled)
        breakpointDao.upsert(BreakpointEntity(id, json.encodeToString(Breakpoint.serializer(), bp), enabled))
    }

    fun ruleToJson(rule: Rule): JsonElement = json.parseToJsonElement(json.encodeToString(Rule.serializer(), rule))

    fun breakpointToJson(bp: Breakpoint): JsonElement = json.parseToJsonElement(json.encodeToString(Breakpoint.serializer(), bp))

    fun parseRule(text: String): Rule = json.decodeFromString(Rule.serializer(), text)

    fun parseBreakpoint(text: String): Breakpoint = json.decodeFromString(Breakpoint.serializer(), text)

    fun exportHar(list: List<TrafficEntity>): String {
        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        val har = buildJsonObject {
            put("log", buildJsonObject {
                put("version", "1.2")
                put("creator", buildJsonObject { put("name", "SkyTrace"); put("version", "1.0.0") })
                put("entries", buildJsonArray {
                    list.filter { !it.tunnel }.forEach { e ->
                        val reqH = headersOf(e.requestHeaders)
                        val resH = headersOf(e.responseHeaders)
                        add(buildJsonObject {
                            put("startedDateTime", iso.format(Date(e.timestamp)))
                            put("time", e.totalMs)
                            put("request", buildJsonObject {
                                put("method", e.method)
                                put("url", e.url)
                                put("httpVersion", e.httpVersion.ifEmpty { "HTTP/1.1" })
                                put("cookies", buildJsonArray { })
                                put("headers", harHeaders(reqH))
                                put("queryString", buildJsonArray {
                                    e.path.substringAfter('?', "").split('&').filter { it.isNotEmpty() }.forEach { kv ->
                                        add(buildJsonObject { put("name", kv.substringBefore('=')); put("value", kv.substringAfter('=', "")) })
                                    }
                                })
                                put("headersSize", -1)
                                put("bodySize", e.requestSize)
                                val body = e.requestBody
                                if (body != null && body.isNotEmpty()) {
                                    put("postData", buildJsonObject {
                                        put("mimeType", e.requestContentType)
                                        put("text", String(body, Charsets.UTF_8))
                                    })
                                }
                            })
                            put("response", buildJsonObject {
                                put("status", e.statusCode)
                                put("statusText", e.statusMessage)
                                put("httpVersion", e.httpVersion.ifEmpty { "HTTP/1.1" })
                                put("cookies", buildJsonArray { })
                                put("headers", harHeaders(resH))
                                put("content", buildJsonObject {
                                    put("size", e.responseSize)
                                    put("mimeType", e.responseContentType)
                                    val rb = e.responseBody ?: ByteArray(0)
                                    val enc = resH.firstOrNull { it.name.equals("Content-Encoding", true) }?.value?.lowercase() ?: ""
                                    val decoded = if (rb.isEmpty()) rb else RewriteEngine.decodeBody(rb, enc)
                                    if (decoded != null && (looksLikeText(e.responseContentType) || isPrintable(decoded))) {
                                        put("text", String(decoded, Charsets.UTF_8))
                                    } else if (rb.isNotEmpty()) {
                                        put("text", Base64.getEncoder().encodeToString(rb))
                                        put("encoding", "base64")
                                    }
                                })
                                put("redirectURL", resH.firstOrNull { it.name.equals("Location", true) }?.value ?: "")
                                put("headersSize", -1)
                                put("bodySize", e.responseSize)
                            })
                            put("cache", buildJsonObject { })
                            put("timings", buildJsonObject {
                                put("blocked", -1)
                                put("dns", -1)
                                put("connect", e.connectMs)
                                put("ssl", e.tlsMs)
                                put("send", e.sendMs)
                                put("wait", e.waitMs)
                                put("receive", e.receiveMs)
                            })
                        })
                    }
                })
            })
        }
        return har.toString()
    }

    private fun harHeaders(list: List<Header>): JsonArray = buildJsonArray {
        list.forEach { add(buildJsonObject { put("name", it.name); put("value", it.value) }) }
    }

    fun exportCurl(list: List<TrafficEntity>): String {
        val sb = StringBuilder()
        list.filter { !it.tunnel }.forEach { e -> sb.append(curlFor(e)).append("\n\n") }
        return sb.toString().trimEnd() + "\n"
    }

    fun curlFor(e: TrafficEntity): String {
        val sb = StringBuilder("curl -X ${e.method} ${shellQuote(e.url)}")
        headersOf(e.requestHeaders).forEach {
            if (it.name.equals("Content-Length", true) || it.name.equals("Host", true)) return@forEach
            sb.append(" \\\n  -H ").append(shellQuote("${it.name}: ${it.value}"))
        }
        val body = e.requestBody
        if (body != null && body.isNotEmpty()) {
            if (looksLikeText(e.requestContentType) || isPrintable(body)) {
                sb.append(" \\\n  --data-raw ").append(shellQuote(String(body, Charsets.UTF_8)))
            } else {
                sb.append(" \\\n  --data-binary ").append(shellQuote("@body.bin"))
            }
        }
        sb.append(" \\\n  --compressed")
        return sb.toString()
    }

    private fun shellQuote(s: String): String = "'" + s.replace("'", "'\\''") + "'"

    fun exportRaw(list: List<TrafficEntity>): String {
        val sb = StringBuilder()
        list.forEach { e ->
            sb.append("### ${e.id} ${e.method} ${e.url}\n")
            sb.append(rawText(e, headersOf(e.requestHeaders), headersOf(e.responseHeaders)))
            sb.append("\n\n")
        }
        return sb.toString()
    }

    fun writeExport(context: Context, name: String, content: String): File {
        val dir = File(context.cacheDir, "exports").apply { mkdirs() }
        val file = File(dir, name)
        file.writeText(content)
        return file
    }
}
