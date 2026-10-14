package com.skytrace.proxy

import com.skytrace.repo.SettingsStore
import com.skytrace.repo.TrafficEntity
import com.skytrace.repo.TrafficRepository
import com.skytrace.util.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.net.URI
import java.util.concurrent.TimeUnit

class ReplayOverride(
    val method: String?,
    val url: String?,
    val headers: List<Header>?,
    val bodyText: String?
)

class ReplayClient(
    private val repository: TrafficRepository,
    private val settings: SettingsStore
) {
    suspend fun replay(id: Long, override: ReplayOverride?): Long {
        val original = repository.get(id) ?: throw IllegalArgumentException("traffic $id not found")
        val method = (override?.method ?: original.method).uppercase()
        val url = override?.url ?: original.url
        val headers = override?.headers ?: repository.headersOf(original.requestHeaders)
        val bodyBytes: ByteArray = override?.bodyText?.toByteArray(Charsets.UTF_8) ?: original.requestBody ?: ByteArray(0)
        val client = OkHttpClient.Builder()
            .connectTimeout(settings.connectTimeoutMs.toLong(), TimeUnit.MILLISECONDS)
            .readTimeout(settings.readTimeoutMs.toLong(), TimeUnit.MILLISECONDS)
            .followRedirects(false)
            .followSslRedirects(false)
            .retryOnConnectionFailure(false)
            .build()
        val builder = Request.Builder().url(url)
        val skip = setOf("host", "content-length", "connection", "accept-encoding", "transfer-encoding", "proxy-connection", "keep-alive", "upgrade")
        val sentHeaders = mutableListOf<Header>()
        headers.forEach {
            if (it.name.lowercase() in skip) return@forEach
            builder.addHeader(it.name, it.value)
            sentHeaders.add(it)
        }
        val contentType = headers.headerValue("Content-Type")
        val needsBody = method in setOf("POST", "PUT", "PATCH", "DELETE")
        val body = if (bodyBytes.isNotEmpty() || method in setOf("POST", "PUT", "PATCH")) {
            bodyBytes.toRequestBody(contentType?.toMediaTypeOrNull())
        } else if (needsBody && method == "DELETE") {
            null
        } else {
            null
        }
        builder.method(method, body)

        val uri = URI(url)
        val scheme = uri.scheme ?: "http"
        val port = if (uri.port > 0) uri.port else if (scheme == "https") 443 else 80
        val path = (uri.rawPath ?: "/").ifEmpty { "/" } + (if (uri.rawQuery != null) "?${uri.rawQuery}" else "")
        val maxBody = settings.maxBodyKb * 1024
        val entity = TrafficEntity(
            timestamp = System.currentTimeMillis(),
            method = method,
            scheme = scheme,
            host = uri.host ?: "",
            port = port,
            path = path,
            url = url,
            httpVersion = "HTTP/1.1",
            requestHeaders = repository.encodeHeaders(sentHeaders),
            requestBody = bodyBytes.copyOf(minOf(bodyBytes.size, maxBody)),
            requestSize = bodyBytes.size.toLong(),
            requestContentType = contentType ?: "",
            requestTruncated = bodyBytes.size > maxBody,
            appPackage = "com.skytrace.app",
            appName = "SkyTrace Replay",
            replayOf = id
        )
        val newId = repository.create(entity, settings.maxEntries, force = true)
        val started = System.nanoTime()
        try {
            val response = withContext(Dispatchers.IO) { client.newCall(builder.build()).execute() }
            response.use { r ->
                val bytes = withContext(Dispatchers.IO) { r.body?.bytes() ?: ByteArray(0) }
                entity.statusCode = r.code
                entity.statusMessage = r.message
                entity.httpVersion = r.protocol.toString().uppercase()
                val resHeaders = r.headers.map { Header(it.first, it.second) }
                entity.responseHeaders = repository.encodeHeaders(resHeaders)
                entity.responseBody = bytes.copyOf(minOf(bytes.size, maxBody))
                entity.responseSize = bytes.size.toLong()
                entity.responseTruncated = bytes.size > maxBody
                entity.responseContentType = contentTypeOf(resHeaders)
            }
        } catch (e: Exception) {
            Logger.w("replay failed", e)
            entity.error = e.message ?: e.javaClass.simpleName
        }
        entity.totalMs = (System.nanoTime() - started) / 1_000_000
        repository.finish(entity)
        return newId
    }
}
