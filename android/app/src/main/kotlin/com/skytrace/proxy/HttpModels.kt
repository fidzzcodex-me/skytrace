package com.skytrace.proxy

import com.skytrace.util.lowerAscii
import kotlinx.serialization.Serializable
import java.io.ByteArrayOutputStream

@Serializable
data class Header(val name: String, val value: String)

fun List<Header>.headerValue(name: String): String? {
    for (h in this) if (h.name.equals(name, ignoreCase = true)) return h.value
    return null
}

fun MutableList<Header>.setHeader(name: String, value: String) {
    var replaced = false
    val it = iterator()
    while (it.hasNext()) {
        val h = it.next()
        if (h.name.equals(name, ignoreCase = true)) {
            if (!replaced) {
                replaced = true
            } else {
                it.remove()
            }
        }
    }
    if (replaced) {
        for (i in indices) if (this[i].name.equals(name, ignoreCase = true)) {
            this[i] = Header(this[i].name, value)
            return
        }
    }
    add(Header(name, value))
}

fun MutableList<Header>.removeHeader(name: String) {
    removeAll { it.name.equals(name, ignoreCase = true) }
}

class HttpRequestMsg(
    var method: String,
    var target: String,
    var version: String,
    var headers: MutableList<Header>,
    var body: ByteArray,
    var scheme: String,
    var host: String,
    var port: Int
) {
    val path: String get() = target

    fun hostHeader(): String {
        val defaultPort = if (scheme == "https") 443 else 80
        return if (port == defaultPort) host else "$host:$port"
    }

    fun url(): String = "$scheme://${hostHeader()}$target"

    fun toWire(): ByteArray {
        val out = ByteArrayOutputStream()
        out.write("$method $target $version\r\n".toByteArray(Charsets.ISO_8859_1))
        val copy = headers.toMutableList()
        copy.removeHeader("Transfer-Encoding")
        copy.removeHeader("Content-Length")
        if (body.isNotEmpty() || method.uppercase() in setOf("POST", "PUT", "PATCH")) {
            copy.add(Header("Content-Length", body.size.toString()))
        }
        for (h in copy) out.write("${h.name}: ${h.value}\r\n".toByteArray(Charsets.ISO_8859_1))
        out.write("\r\n".toByteArray())
        out.write(body)
        return out.toByteArray()
    }
}

class HttpResponseMsg(
    var version: String,
    var status: Int,
    var reason: String,
    var headers: MutableList<Header>,
    var body: ByteArray
) {
    fun headBytes(): ByteArray {
        val out = ByteArrayOutputStream()
        out.write("$version $status $reason\r\n".toByteArray(Charsets.ISO_8859_1))
        for (h in headers) out.write("${h.name}: ${h.value}\r\n".toByteArray(Charsets.ISO_8859_1))
        out.write("\r\n".toByteArray())
        return out.toByteArray()
    }

    fun toBufferedWire(): ByteArray {
        val copy = headers.toMutableList()
        copy.removeHeader("Transfer-Encoding")
        copy.removeHeader("Content-Length")
        copy.add(Header("Content-Length", body.size.toString()))
        val out = ByteArrayOutputStream()
        out.write("$version $status $reason\r\n".toByteArray(Charsets.ISO_8859_1))
        for (h in copy) out.write("${h.name}: ${h.value}\r\n".toByteArray(Charsets.ISO_8859_1))
        out.write("\r\n".toByteArray())
        out.write(body)
        return out.toByteArray()
    }

    companion object {
        fun simple(status: Int, reason: String, contentType: String, body: ByteArray): HttpResponseMsg {
            val headers = mutableListOf(
                Header("Content-Type", contentType),
                Header("Connection", "close"),
                Header("X-SkyTrace", "generated")
            )
            return HttpResponseMsg("HTTP/1.1", status, reason, headers, body)
        }
    }
}

fun statusReason(code: Int): String = when (code) {
    200 -> "OK"
    201 -> "Created"
    202 -> "Accepted"
    204 -> "No Content"
    301 -> "Moved Permanently"
    302 -> "Found"
    304 -> "Not Modified"
    400 -> "Bad Request"
    401 -> "Unauthorized"
    403 -> "Forbidden"
    404 -> "Not Found"
    408 -> "Request Timeout"
    409 -> "Conflict"
    429 -> "Too Many Requests"
    500 -> "Internal Server Error"
    502 -> "Bad Gateway"
    503 -> "Service Unavailable"
    504 -> "Gateway Timeout"
    else -> "Status"
}

fun contentTypeOf(headers: List<Header>): String = headers.headerValue("Content-Type")?.lowerAscii() ?: ""
