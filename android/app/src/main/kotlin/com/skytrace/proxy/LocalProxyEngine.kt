package com.skytrace.proxy

import com.skytrace.repo.Graph
import com.skytrace.repo.TrafficEntity
import com.skytrace.rule.BreakpointDecision
import com.skytrace.rule.BreakpointEdit
import com.skytrace.util.Logger
import com.skytrace.util.isHttpMethodPrefix
import com.skytrace.util.globToRegex
import com.skytrace.util.isProbablyText
import com.skytrace.util.toIpString
import com.skytrace.util.u8
import com.skytrace.vpn.AppIdentity
import com.skytrace.vpn.DnsCache
import com.skytrace.vpn.LiveStats
import com.skytrace.vpn.TcpSession
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.security.SecureRandom
import java.util.Base64
import java.security.cert.X509Certificate
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLPeerUnverifiedException
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class LocalProxyEngine(
    private val protectSocket: (Socket) -> Unit,
    private val scope: CoroutineScope
) {
    private class Upstream(
        val key: String,
        val socket: Socket,
        val transport: ByteTransport,
        val reader: MessageReader,
        val connectMs: Long,
        val tlsMs: Long,
        val remoteIp: String
    ) {
        fun close() = transport.close()
    }

    private class Conn(
        val dstIp: ByteArray?,
        val dstPort: Int,
        val client: ByteTransport,
        val reader: MessageReader,
        val scheme: String,
        val hostLabel: String,
        val app: AppIdentity
    ) {
        var upstream: Upstream? = null
    }

    private val tls = TlsInterceptor(Graph.certs)
    private val bypass = ConcurrentHashMap.newKeySet<String>()

    private val trustAllFactory: SSLSocketFactory by lazy {
        val tm = object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<X509Certificate>?, authType: String?) = Unit
            override fun checkServerTrusted(chain: Array<X509Certificate>?, authType: String?) = Unit
            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
        }
        val ctx = SSLContext.getInstance("TLS")
        ctx.init(null, arrayOf<TrustManager>(tm), SecureRandom())
        ctx.socketFactory
    }

    fun handle(session: TcpSession) {
        scope.launch(Dispatchers.IO) {
            LiveStats.connections.incrementAndGet()
            try {
                serve(session)
                session.close()
            } catch (e: CancellationException) {
                session.reset()
                throw e
            } catch (e: Exception) {
                Logger.d("session ended with error: ${e.javaClass.simpleName}: ${e.message}")
                session.reset()
            }
        }
    }

    fun clearBypass() = bypass.clear()

    private suspend fun serve(session: TcpSession) {
        val first = session.read() ?: return
        val dstIp = session.dstIp.toIpString()
        val app = Graph.uids.resolveTcp(session.srcIp, session.srcPort, session.dstIp, session.dstPort)
        val dnsHost = DnsCache.hostFor(session.dstIp)
        val label = dnsHost ?: dstIp
        val looksTls = first.size >= 3 && first[0].u8() == 0x16 && first[1].u8() == 0x03

        if (looksTls) {
            val sni = TlsInterceptor.parseSni(first)
            val hostKey = sni ?: label
            if (!Graph.settings.tlsInterception || bypass.contains(hostKey) || userBypass(hostKey)) {
                tunnel(PrefixedTransport(first, session), session.dstIp, session.dstPort, hostKey, "tls", app, bypassReason(hostKey))
                return
            }
            val result = try {
                tls.accept(session, first, label)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                bypass.add(hostKey)
                recordTlsFailure(hostKey, session.dstPort, session.dstIp, app, e)
                session.reset()
                return
            }
            val conn = Conn(session.dstIp, session.dstPort, result.transport, MessageReader(result.transport), "https", result.serverName ?: label, app)
            serveHttp(conn)
            return
        }

        if (isHttpMethodPrefix(first)) {
            val transport = PrefixedTransport(first, session)
            serveHttp(Conn(session.dstIp, session.dstPort, transport, MessageReader(transport), "http", label, app))
            return
        }
        tunnel(PrefixedTransport(first, session), session.dstIp, session.dstPort, label, "tcp", app)
    }

    private var bypassRaw: String = ""
    private var bypassRegexes: List<Regex> = emptyList()

    private fun userBypass(host: String): Boolean {
        val raw = Graph.settings.bypassHosts
        if (raw != bypassRaw) {
            bypassRegexes = raw.split('\n', ',', ' ', ';')
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .map { it.globToRegex() }
            bypassRaw = raw
        }
        return bypassRegexes.any { it.containsMatchIn(host) }
    }

    private fun bypassReason(hostKey: String): String = when {
        !Graph.settings.tlsInterception -> "tls-off"
        userBypass(hostKey) -> "bypass-user"
        else -> "bypass-auto"
    }

    private fun proxyAuthorized(headers: List<Header>): Boolean {
        val auth = Graph.settings.proxyAuth
        if (auth.isBlank()) return true
        val expected = "Basic " + Base64.getEncoder().encodeToString(auth.toByteArray())
        return headers.headerValue("Proxy-Authorization") == expected
    }

    suspend fun serveProxyConnection(socket: Socket) {
        LiveStats.connections.incrementAndGet()
        val transport = SocketTransport(socket)
        val clientIp = socket.inetAddress?.hostAddress ?: "unknown"
        val app = AppIdentity(-1, "proxy:$clientIp", "Proxy $clientIp")
        try {
            val reader = MessageReader(transport)
            val raw = reader.readHead() ?: return
            val head = try {
                HttpParser.parseRequestHead(raw)
            } catch (e: IOException) {
                writeSimple(transport, 400, "Bad Request", "SkyTrace proxy could not parse the request: ${e.message}")
                return
            }
            if (!proxyAuthorized(head.headers)) {
                transport.write(
                    ("HTTP/1.1 407 Proxy Authentication Required\r\n" +
                        "Proxy-Authenticate: Basic realm=\"SkyTrace\"\r\n" +
                        "Content-Length: 0\r\nConnection: close\r\n\r\n").toByteArray()
                )
                return
            }
            if (head.method.equals("CONNECT", ignoreCase = true)) {
                val (host, port) = parseHostPort(head.target, "", 443)
                if (host.isEmpty()) {
                    writeSimple(transport, 400, "Bad Request", "SkyTrace proxy: missing CONNECT target")
                    return
                }
                transport.write("HTTP/1.1 200 Connection Established\r\n\r\n".toByteArray())
                val leftover = reader.takeBuffered()
                val first = if (leftover.isNotEmpty()) leftover else (transport.read() ?: return)
                serveTunneledStream(transport, first, host, port, app)
            } else {
                val rebuilt = PrefixedTransport(raw + reader.takeBuffered(), transport)
                serveHttp(Conn(null, 80, rebuilt, MessageReader(rebuilt), "http", "", app))
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Logger.d("proxy connection ended: ${e.javaClass.simpleName}: ${e.message}")
        } finally {
            transport.close()
        }
    }

    private suspend fun serveTunneledStream(transport: ByteTransport, first: ByteArray, host: String, port: Int, app: AppIdentity) {
        val looksTls = first.size >= 3 && first[0].u8() == 0x16 && first[1].u8() == 0x03
        if (looksTls) {
            val sni = TlsInterceptor.parseSni(first)
            val hostKey = sni ?: host
            if (!Graph.settings.tlsInterception || bypass.contains(hostKey) || userBypass(hostKey)) {
                tunnel(PrefixedTransport(first, transport), null, port, hostKey, "tls", app, bypassReason(hostKey))
                return
            }
            val result = try {
                tls.accept(transport, first, host)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                bypass.add(hostKey)
                recordTlsFailure(hostKey, port, null, app, e)
                return
            }
            serveHttp(Conn(null, port, result.transport, MessageReader(result.transport), "https", result.serverName ?: host, app))
            return
        }
        if (isHttpMethodPrefix(first)) {
            val t = PrefixedTransport(first, transport)
            serveHttp(Conn(null, port, t, MessageReader(t), "http", host, app))
            return
        }
        tunnel(PrefixedTransport(first, transport), null, port, host, "tcp", app)
    }

    private suspend fun recordTlsFailure(host: String, port: Int, dstIp: ByteArray?, app: AppIdentity, error: Exception) {
        val e = TrafficEntity(
            timestamp = System.currentTimeMillis(),
            method = "TLS",
            scheme = "https",
            host = host,
            port = port,
            url = "https://$host:$port",
            appPackage = app.packageName,
            appName = app.label,
            uid = app.uid,
            remoteIp = dstIp?.toIpString() ?: "",
            error = "TLS handshake failed (${error.message ?: error.javaClass.simpleName}). Client likely rejects the SkyTrace CA or pins certificates. Host is tunneled without interception on the next connection."
        )
        val id = Graph.repository.create(e, Graph.settings.maxEntries)
        e.id = id
        Graph.repository.finish(e)
    }

    private suspend fun tunnel(
        client: ByteTransport,
        dstIp: ByteArray?,
        dstPort: Int,
        host: String,
        scheme: String,
        app: AppIdentity,
        reason: String = ""
    ) {
        val started = System.nanoTime()
        val entity = TrafficEntity(
            timestamp = System.currentTimeMillis(),
            method = "TUNNEL",
            scheme = scheme,
            host = host,
            port = dstPort,
            url = "$scheme://$host:$dstPort",
            appPackage = app.packageName,
            appName = app.label,
            uid = app.uid,
            remoteIp = dstIp?.toIpString() ?: "",
            statusMessage = reason,
            tunnel = true
        )
        entity.id = Graph.repository.create(entity, Graph.settings.maxEntries)
        val up = AtomicLong(0)
        val down = AtomicLong(0)
        try {
            val socket = openSocket(dstIp, if (dstIp == null) host else null, dstPort)
            val upstream = SocketTransport(socket)
            Relay.run(
                client,
                upstream,
                onAtoB = { up.addAndGet(it.size.toLong()); LiveStats.bytesUp.addAndGet(it.size.toLong()) },
                onBtoA = { down.addAndGet(it.size.toLong()); LiveStats.bytesDown.addAndGet(it.size.toLong()) }
            )
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            entity.error = e.message ?: e.javaClass.simpleName
        } finally {
            entity.requestSize = up.get()
            entity.responseSize = down.get()
            entity.totalMs = (System.nanoTime() - started) / 1_000_000
            Graph.repository.finish(entity)
        }
    }

    private suspend fun serveHttp(c: Conn) {
        try {
            while (true) {
                val raw = c.reader.readHead() ?: break
                val head = try {
                    HttpParser.parseRequestHead(raw)
                } catch (e: IOException) {
                    writeSimple(c.client, 400, "Bad Request", "SkyTrace could not parse the request: ${e.message}")
                    break
                }
                val keepAlive = handleOne(c, head)
                if (!keepAlive) break
            }
        } finally {
            c.upstream?.close()
        }
    }

    private fun parseHostPort(header: String?, fallbackHost: String, fallbackPort: Int): Pair<String, Int> {
        if (header.isNullOrBlank()) return Pair(fallbackHost, fallbackPort)
        val h = header.trim()
        if (h.startsWith("[")) {
            val close = h.indexOf(']')
            if (close > 0) {
                val host = h.substring(1, close)
                val port = h.substring(close + 1).removePrefix(":").toIntOrNull() ?: fallbackPort
                return Pair(host, port)
            }
        }
        val idx = h.lastIndexOf(':')
        if (idx > 0) {
            val port = h.substring(idx + 1).toIntOrNull()
            if (port != null) return Pair(h.substring(0, idx), port)
        }
        return Pair(h, fallbackPort)
    }

    private suspend fun handleOne(c: Conn, head: ParsedRequestHead): Boolean {
        val settings = Graph.settings
        val maxStore = settings.maxBodyKb * 1024
        val started = System.nanoTime()
        if (head.target.startsWith("http://") || head.target.startsWith("https://")) {
            try {
                val absolute = java.net.URI(head.target)
                val defaultPort = if (absolute.scheme == "https") 443 else 80
                val hostPart = if (absolute.port > 0 && absolute.port != defaultPort) "${absolute.host}:${absolute.port}" else absolute.host
                head.headers.setHeader("Host", hostPart)
                val rawPath = absolute.rawPath.let { if (it.isNullOrEmpty()) "/" else it }
                val query = absolute.rawQuery?.let { "?$it" } ?: ""
                head.target = rawPath + query
            } catch (e: Exception) {
                Logger.d("could not normalize absolute request target")
            }
        }
        val (hostName, port) = parseHostPort(head.headers.headerValue("Host"), c.hostLabel, c.dstPort)

        val expect = head.headers.headerValue("Expect")
        if (expect != null && expect.contains("100-continue", true) &&
            (HttpParser.isChunked(head.headers) || (HttpParser.contentLength(head.headers) ?: 0L) > 0L)
        ) {
            c.client.write("HTTP/1.1 100 Continue\r\n\r\n".toByteArray())
            head.headers.removeHeader("Expect")
        }

        val body = try {
            HttpParser.readRequestBody(c.reader, head.headers, MAX_REQUEST_BODY)
        } catch (e: IOException) {
            writeSimple(c.client, 413, "Payload Too Large", "SkyTrace: ${e.message}")
            return false
        }

        val req = HttpRequestMsg(head.method, head.target, head.version, head.headers, body, c.scheme, hostName, port)
        val entity = TrafficEntity(
            timestamp = System.currentTimeMillis(),
            method = req.method,
            scheme = req.scheme,
            host = req.host,
            port = req.port,
            path = req.target,
            url = req.url(),
            httpVersion = req.version,
            requestHeaders = Graph.repository.encodeHeaders(req.headers),
            requestBody = body.copyOf(minOf(body.size, maxStore)),
            requestSize = body.size.toLong(),
            requestContentType = contentTypeOf(req.headers),
            requestTruncated = body.size > maxStore,
            appPackage = c.app.packageName,
            appName = c.app.label,
            uid = c.app.uid,
            remoteIp = c.dstIp?.toIpString() ?: ""
        )
        entity.id = Graph.repository.create(entity, settings.maxEntries)
        LiveStats.requests.incrementAndGet()
        LiveStats.bytesUp.addAndGet(body.size.toLong())

        var responseStarted = false
        try {
            val outcome = Graph.rewrite.applyRequest(req, c.app.packageName)
            if (outcome.modified) entity.modified = true
            if (outcome.delayMs > 0) delay(outcome.delayMs)

            val mock = outcome.mock
            if (mock != null) {
                c.client.write(mock.toBufferedWire())
                fillResponse(entity, mock.version, mock.status, mock.reason, mock.headers, mock.body, mock.body.size.toLong(), maxStore)
                fillRequest(entity, req, maxStore)
                entity.totalMs = (System.nanoTime() - started) / 1_000_000
                Graph.repository.finish(entity)
                return req.headers.headerValue("Connection")?.equals("close", true) != true
            }

            val reqCt = contentTypeOf(req.headers)
            if (Graph.breakpoints.matches("request", req.method, req.url())) {
                val decision = Graph.breakpoints.intercept(
                    "request", entity.id, req.method, req.url(),
                    "${req.method} ${req.target} ${req.version}", 0, req.headers, req.body,
                    isProbablyText(reqCt, req.body)
                )
                when (decision) {
                    is BreakpointDecision.Abort -> {
                        entity.error = "Aborted at request breakpoint"
                        fillRequest(entity, req, maxStore)
                        entity.totalMs = (System.nanoTime() - started) / 1_000_000
                        Graph.repository.finish(entity)
                        writeSimple(c.client, 499, "Aborted", "Request aborted by SkyTrace breakpoint")
                        return false
                    }
                    is BreakpointDecision.Resume -> decision.edit?.let {
                        applyRequestEdit(req, it)
                        entity.modified = true
                    }
                }
            }

            if (Graph.settings.normalizeEncoding) {
                val ae = req.headers.headerValue("Accept-Encoding")?.lowercase() ?: ""
                if (ae.contains("br") || ae.contains("zstd")) req.headers.setHeader("Accept-Encoding", "gzip, deflate")
            }
            req.headers.removeHeader("Proxy-Connection")
            fillRequest(entity, req, maxStore)

            val redirected = req.host != hostName || req.port != port
            val isWebSocket = req.headers.headerValue("Upgrade")?.equals("websocket", true) == true
            val sendStart = System.nanoTime()
            var upstream = obtainUpstream(c, req, redirected)
            val wire = req.toWire()
            var firstHead: ByteArray?
            try {
                upstream.transport.write(wire)
                firstHead = readResponseHead(upstream)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                c.upstream?.close()
                c.upstream = null
                upstream = obtainUpstream(c, req, redirected)
                upstream.transport.write(wire)
                firstHead = readResponseHead(upstream)
            }
            val sentAt = System.nanoTime()
            entity.connectMs = upstream.connectMs
            entity.tlsMs = upstream.tlsMs
            entity.sendMs = (sentAt - sendStart) / 1_000_000
            if (firstHead == null) throw IOException("upstream closed the connection without a response")
            val firstByteAt = System.nanoTime()
            entity.waitMs = (firstByteAt - sentAt) / 1_000_000
            val rh = HttpParser.parseResponseHead(firstHead)
            val resp = HttpResponseMsg(rh.version, rh.status, rh.reason, rh.headers, ByteArray(0))

            if (isWebSocket && resp.status == 101) {
                c.client.write(resp.headBytes())
                responseStarted = true
                entity.isWebSocket = true
                entity.statusCode = 101
                entity.statusMessage = resp.reason
                entity.responseHeaders = Graph.repository.encodeHeaders(resp.headers)
                val log = WebSocketLog(maxStore)
                val serverLeft = upstream.reader.takeBuffered()
                val clientLeft = c.reader.takeBuffered()
                if (serverLeft.isNotEmpty()) c.client.write(serverLeft)
                if (clientLeft.isNotEmpty()) upstream.transport.write(clientLeft)
                WebSocketHandler.relay(c.client, upstream.transport, log, serverLeft, clientLeft)
                val text = log.text().toByteArray()
                entity.responseBody = text
                entity.responseSize = text.size.toLong()
                entity.responseContentType = "text/x-skytrace-websocket"
                entity.totalMs = (System.nanoTime() - started) / 1_000_000
                Graph.repository.finish(entity)
                c.upstream = null
                return false
            }

            val respRewrite = Graph.rewrite.applyResponseHeaders(req, resp, c.app.packageName)
            if (respRewrite.first) entity.modified = true
            val needBuffer = Graph.rewrite.needsResponseBuffer(req, c.app.packageName) ||
                Graph.breakpoints.matches("response", req.method, req.url())
            var closeAfter = false

            if (!needBuffer) {
                if (respRewrite.second > 0) delay(respRewrite.second)
                c.client.write(resp.headBytes())
                responseStarted = true
                val capture = ByteArrayOutputStream()
                val result = HttpParser.streamResponseBody(
                    upstream.reader, resp.headers, req.method, resp.status,
                    sink = { c.client.write(it) },
                    capture = capture,
                    captureLimit = maxStore
                )
                closeAfter = result.closeDelimited
                val captured = capture.toByteArray()
                fillResponse(entity, resp.version, resp.status, resp.reason, resp.headers, captured, result.totalBytes, maxStore)
                entity.receiveMs = (System.nanoTime() - firstByteAt) / 1_000_000
                LiveStats.bytesDown.addAndGet(result.totalBytes)
            } else {
                val bytes = HttpParser.readResponseBodyBuffered(upstream.reader, resp.headers, req.method, resp.status, MAX_BUFFERED_RESPONSE)
                resp.body = bytes
                if (Graph.rewrite.applyResponseBody(req, resp, c.app.packageName)) entity.modified = true
                if (Graph.breakpoints.matches("response", req.method, req.url())) {
                    val ct = contentTypeOf(resp.headers)
                    val decision = Graph.breakpoints.intercept(
                        "response", entity.id, req.method, req.url(),
                        "${resp.version} ${resp.status} ${resp.reason}", resp.status, resp.headers, resp.body,
                        isProbablyText(ct, resp.body)
                    )
                    when (decision) {
                        is BreakpointDecision.Abort -> {
                            entity.error = "Aborted at response breakpoint"
                            fillResponse(entity, resp.version, resp.status, resp.reason, resp.headers, resp.body, resp.body.size.toLong(), maxStore)
                            entity.totalMs = (System.nanoTime() - started) / 1_000_000
                            Graph.repository.finish(entity)
                            c.upstream?.close()
                            c.upstream = null
                            return false
                        }
                        is BreakpointDecision.Resume -> decision.edit?.let {
                            applyResponseEdit(resp, it)
                            entity.modified = true
                        }
                    }
                }
                if (respRewrite.second > 0) delay(respRewrite.second)
                c.client.write(resp.toBufferedWire())
                responseStarted = true
                fillResponse(entity, resp.version, resp.status, resp.reason, resp.headers, resp.body, resp.body.size.toLong(), maxStore)
                entity.receiveMs = (System.nanoTime() - firstByteAt) / 1_000_000
                LiveStats.bytesDown.addAndGet(resp.body.size.toLong())
            }

            entity.totalMs = (System.nanoTime() - started) / 1_000_000
            Graph.repository.finish(entity)

            val serverClose = closeAfter ||
                resp.headers.headerValue("Connection")?.equals("close", true) == true ||
                (resp.version.equals("HTTP/1.0", true) && resp.headers.headerValue("Connection")?.equals("keep-alive", true) != true)
            val clientClose = req.headers.headerValue("Connection")?.equals("close", true) == true
            if (serverClose) {
                c.upstream?.close()
                c.upstream = null
            }
            return !(serverClose || clientClose)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Logger.w("exchange failed for ${req.url()}", e)
            entity.error = e.message ?: e.javaClass.simpleName
            entity.totalMs = (System.nanoTime() - started) / 1_000_000
            Graph.repository.finish(entity)
            c.upstream?.close()
            c.upstream = null
            if (!responseStarted) {
                writeSimple(c.client, 502, "Bad Gateway", "SkyTrace could not reach ${req.host}:${req.port}: ${entity.error}")
            }
            return false
        }
    }

    private suspend fun readResponseHead(up: Upstream): ByteArray? {
        while (true) {
            val head = up.reader.readHead() ?: return null
            val parsed = HttpParser.parseResponseHead(head)
            if (parsed.status in 100..199 && parsed.status != 101) continue
            return head
        }
    }

    private fun fillRequest(e: TrafficEntity, req: HttpRequestMsg, maxStore: Int) {
        e.method = req.method
        e.scheme = req.scheme
        e.host = req.host
        e.port = req.port
        e.path = req.target
        e.url = req.url()
        e.requestHeaders = Graph.repository.encodeHeaders(req.headers)
        e.requestBody = req.body.copyOf(minOf(req.body.size, maxStore))
        e.requestSize = req.body.size.toLong()
        e.requestContentType = contentTypeOf(req.headers)
        e.requestTruncated = req.body.size > maxStore
    }

    private fun fillResponse(
        e: TrafficEntity,
        version: String,
        status: Int,
        reason: String,
        headers: List<Header>,
        stored: ByteArray,
        totalSize: Long,
        maxStore: Int
    ) {
        e.httpVersion = version
        e.statusCode = status
        e.statusMessage = reason
        e.responseHeaders = Graph.repository.encodeHeaders(headers)
        e.responseBody = if (stored.size > maxStore) stored.copyOf(maxStore) else stored
        e.responseSize = totalSize
        e.responseContentType = contentTypeOf(headers)
        e.responseTruncated = totalSize > e.responseBody!!.size
    }

    private fun applyRequestEdit(req: HttpRequestMsg, edit: BreakpointEdit) {
        edit.method?.takeIf { it.isNotBlank() }?.let { req.method = it.uppercase() }
        edit.path?.takeIf { it.isNotBlank() }?.let { req.target = it }
        edit.headers?.let { req.headers = it.toMutableList() }
        edit.bodyText?.let { req.body = it.toByteArray(Charsets.UTF_8) }
    }

    private fun applyResponseEdit(resp: HttpResponseMsg, edit: BreakpointEdit) {
        edit.status?.let {
            resp.status = it
            resp.reason = statusReason(it)
        }
        edit.headers?.let { resp.headers = it.toMutableList() }
        edit.bodyText?.let {
            resp.body = it.toByteArray(Charsets.UTF_8)
            resp.headers.removeHeader("Content-Encoding")
        }
    }

    private suspend fun obtainUpstream(c: Conn, req: HttpRequestMsg, redirected: Boolean): Upstream {
        val key = "${req.scheme}://${req.host}:${req.port}"
        val existing = c.upstream
        if (existing != null && existing.key == key) return existing
        existing?.close()
        val ip = if (redirected) null else c.dstIp
        val created = connectUpstream(req.scheme, req.host, req.port, ip)
        c.upstream = created
        return created
    }

    private suspend fun connectUpstream(scheme: String, host: String, port: Int, ip: ByteArray?): Upstream =
        withContext(Dispatchers.IO) {
            val t0 = System.nanoTime()
            val raw = openSocketBlocking(ip, host, port)
            val t1 = System.nanoTime()
            var socket: Socket = raw
            var tlsMs = 0L
            if (scheme == "https") {
                val ignore = Graph.settings.ignoreUpstreamCertErrors
                val factory = if (ignore) trustAllFactory else SSLSocketFactory.getDefault() as SSLSocketFactory
                val ssl = factory.createSocket(raw, host, port, true) as SSLSocket
                if (!Regex("^[0-9.]+$").matches(host) && !host.contains(':')) {
                    val params = ssl.sslParameters
                    params.serverNames = listOf(SNIHostName(host))
                    ssl.sslParameters = params
                }
                try {
                    ssl.startHandshake()
                    if (!ignore && !HttpsURLConnection.getDefaultHostnameVerifier().verify(host, ssl.session)) {
                        throw SSLPeerUnverifiedException("hostname $host does not match the server certificate")
                    }
                } catch (e: Exception) {
                    try {
                        ssl.close()
                    } catch (ignored: Exception) {
                        Logger.d("close after failed handshake")
                    }
                    throw e
                }
                socket = ssl
                tlsMs = (System.nanoTime() - t1) / 1_000_000
            }
            val transport = SocketTransport(socket)
            Upstream(
                key = "$scheme://$host:$port",
                socket = socket,
                transport = transport,
                reader = MessageReader(transport),
                connectMs = (t1 - t0) / 1_000_000,
                tlsMs = tlsMs,
                remoteIp = socket.inetAddress?.hostAddress ?: ""
            )
        }

    private suspend fun openSocket(ip: ByteArray?, host: String?, port: Int): Socket =
        withContext(Dispatchers.IO) { openSocketBlocking(ip, host, port) }

    private fun openSocketBlocking(ip: ByteArray?, host: String?, port: Int): Socket {
        val socket = Socket()
        try {
            protectSocket(socket)
            socket.tcpNoDelay = true
            socket.soTimeout = Graph.settings.readTimeoutMs
            val address = when {
                ip != null -> InetAddress.getByAddress(host, ip)
                host != null -> InetAddress.getByName(host)
                else -> throw IOException("no destination")
            }
            socket.connect(InetSocketAddress(address, port), Graph.settings.connectTimeoutMs)
            return socket
        } catch (e: Exception) {
            try {
                socket.close()
            } catch (ignored: Exception) {
                Logger.d("close after failed connect")
            }
            throw e
        }
    }

    private suspend fun writeSimple(client: ByteTransport, status: Int, reason: String, message: String) {
        try {
            val resp = HttpResponseMsg.simple(status, reason, "text/plain; charset=utf-8", message.toByteArray())
            client.write(resp.toBufferedWire())
        } catch (e: Exception) {
            Logger.d("could not write error response")
        }
    }

    companion object {
        private const val MAX_REQUEST_BODY = 64L * 1024 * 1024
        private const val MAX_BUFFERED_RESPONSE = 64L * 1024 * 1024
    }
}
