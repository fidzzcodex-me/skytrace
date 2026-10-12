package com.skytrace.proxy

import com.skytrace.util.indexOfSequence
import com.skytrace.util.lowerAscii
import java.io.ByteArrayOutputStream
import java.io.EOFException
import java.io.IOException

class MessageReader(private val transport: ByteTransport) {
    private var buf = ByteArray(16 * 1024)
    private var start = 0
    private var end = 0

    private fun compact() {
        if (start > 0) {
            System.arraycopy(buf, start, buf, 0, end - start)
            end -= start
            start = 0
        }
    }

    suspend fun fill(): Boolean {
        val chunk = transport.read() ?: return false
        compact()
        if (end + chunk.size > buf.size) {
            buf = buf.copyOf(maxOf(buf.size * 2, end + chunk.size))
        }
        System.arraycopy(chunk, 0, buf, end, chunk.size)
        end += chunk.size
        return true
    }

    fun buffered(): Int = end - start

    suspend fun readHead(maxSize: Int = 128 * 1024): ByteArray? {
        val marker = byteArrayOf(13, 10, 13, 10)
        while (true) {
            val idx = buf.indexOfSequence(marker, start, end)
            if (idx >= 0) {
                val head = buf.copyOfRange(start, idx + 4)
                start = idx + 4
                return head
            }
            if (end - start > maxSize) throw IOException("header too large")
            if (!fill()) {
                if (end - start == 0) return null
                throw EOFException("unexpected end of stream in headers")
            }
        }
    }

    suspend fun readExactly(n: Int): ByteArray {
        while (end - start < n) {
            if (!fill()) throw EOFException("unexpected end of stream")
        }
        val out = buf.copyOfRange(start, start + n)
        start += n
        return out
    }

    suspend fun readLine(): String {
        val marker = byteArrayOf(13, 10)
        while (true) {
            val idx = buf.indexOfSequence(marker, start, end)
            if (idx >= 0) {
                val line = String(buf, start, idx - start, Charsets.ISO_8859_1)
                start = idx + 2
                return line
            }
            if (end - start > 64 * 1024) throw IOException("line too long")
            if (!fill()) throw EOFException("unexpected end of stream")
        }
    }

    suspend fun readSome(max: Int): ByteArray? {
        if (end - start == 0) {
            if (!fill()) return null
        }
        val n = minOf(max, end - start)
        val out = buf.copyOfRange(start, start + n)
        start += n
        return out
    }

    fun takeBuffered(): ByteArray {
        val out = buf.copyOfRange(start, end)
        start = end
        return out
    }
}

class ParsedRequestHead(
    val method: String,
    var target: String,
    val version: String,
    val headers: MutableList<Header>
)

class ParsedResponseHead(
    val version: String,
    val status: Int,
    val reason: String,
    val headers: MutableList<Header>
)

object HttpParser {

    fun parseRequestHead(raw: ByteArray): ParsedRequestHead {
        val lines = splitLines(raw)
        if (lines.isEmpty()) throw IOException("empty request")
        val parts = lines[0].split(" ", limit = 3)
        if (parts.size < 3) throw IOException("malformed request line")
        return ParsedRequestHead(parts[0], parts[1], parts[2], parseHeaders(lines))
    }

    fun parseResponseHead(raw: ByteArray): ParsedResponseHead {
        val lines = splitLines(raw)
        if (lines.isEmpty()) throw IOException("empty response")
        val parts = lines[0].split(" ", limit = 3)
        if (parts.size < 2) throw IOException("malformed status line")
        val status = parts[1].toIntOrNull() ?: throw IOException("invalid status code")
        return ParsedResponseHead(parts[0], status, if (parts.size > 2) parts[2] else "", parseHeaders(lines))
    }

    private fun splitLines(raw: ByteArray): List<String> {
        val text = String(raw, Charsets.ISO_8859_1)
        return text.split("\r\n").filter { it.isNotEmpty() }
    }

    private fun parseHeaders(lines: List<String>): MutableList<Header> {
        val headers = mutableListOf<Header>()
        for (i in 1 until lines.size) {
            val line = lines[i]
            val idx = line.indexOf(':')
            if (idx <= 0) continue
            headers.add(Header(line.substring(0, idx).trim(), line.substring(idx + 1).trim()))
        }
        return headers
    }

    fun isChunked(headers: List<Header>): Boolean =
        headers.headerValue("Transfer-Encoding")?.lowerAscii()?.contains("chunked") == true

    fun contentLength(headers: List<Header>): Long? = headers.headerValue("Content-Length")?.trim()?.toLongOrNull()

    suspend fun readRequestBody(reader: MessageReader, headers: List<Header>, limit: Long): ByteArray {
        if (isChunked(headers)) return readChunkedBuffered(reader, limit)
        val length = contentLength(headers) ?: 0L
        if (length <= 0L) return ByteArray(0)
        if (length > limit) throw IOException("request body too large")
        return reader.readExactly(length.toInt())
    }

    suspend fun readChunkedBuffered(reader: MessageReader, limit: Long): ByteArray {
        val out = ByteArrayOutputStream()
        while (true) {
            val sizeLine = reader.readLine().substringBefore(';').trim()
            val size = sizeLine.toIntOrNull(16) ?: throw IOException("invalid chunk size")
            if (size == 0) {
                while (reader.readLine().isNotEmpty()) {
                }
                break
            }
            if (out.size() + size > limit) throw IOException("chunked body too large")
            out.write(reader.readExactly(size))
            reader.readExactly(2)
        }
        return out.toByteArray()
    }

    fun responseHasBody(requestMethod: String, status: Int): Boolean {
        if (requestMethod.equals("HEAD", ignoreCase = true)) return false
        if (status in 100..199 || status == 204 || status == 304) return false
        return true
    }

    suspend fun readResponseBodyBuffered(
        reader: MessageReader,
        headers: List<Header>,
        requestMethod: String,
        status: Int,
        limit: Long
    ): ByteArray {
        if (!responseHasBody(requestMethod, status)) return ByteArray(0)
        if (isChunked(headers)) return readChunkedBuffered(reader, limit)
        val length = contentLength(headers)
        if (length != null) {
            if (length > limit) throw IOException("response body too large to buffer")
            return reader.readExactly(length.toInt())
        }
        val out = ByteArrayOutputStream()
        while (true) {
            val part = reader.readSome(65536) ?: break
            out.write(part)
            if (out.size() > limit) throw IOException("response body too large to buffer")
        }
        return out.toByteArray()
    }

    class StreamResult(val totalBytes: Long, val closeDelimited: Boolean)

    suspend fun streamResponseBody(
        reader: MessageReader,
        headers: List<Header>,
        requestMethod: String,
        status: Int,
        sink: suspend (ByteArray) -> Unit,
        capture: ByteArrayOutputStream,
        captureLimit: Int
    ): StreamResult {
        if (!responseHasBody(requestMethod, status)) return StreamResult(0, false)
        var total = 0L
        fun record(data: ByteArray) {
            val room = captureLimit - capture.size()
            if (room > 0) capture.write(data, 0, minOf(room, data.size))
            total += data.size
        }
        if (isChunked(headers)) {
            while (true) {
                val sizeLine = reader.readLine()
                val size = sizeLine.substringBefore(';').trim().toIntOrNull(16) ?: throw IOException("invalid chunk size")
                sink("$sizeLine\r\n".toByteArray(Charsets.ISO_8859_1))
                if (size == 0) {
                    while (true) {
                        val trailer = reader.readLine()
                        sink("$trailer\r\n".toByteArray(Charsets.ISO_8859_1))
                        if (trailer.isEmpty()) break
                    }
                    break
                }
                var remaining = size
                while (remaining > 0) {
                    val part = reader.readSome(minOf(remaining, 32768)) ?: throw EOFException("unexpected end in chunk")
                    sink(part)
                    record(part)
                    remaining -= part.size
                }
                val crlf = reader.readExactly(2)
                sink(crlf)
            }
            return StreamResult(total, false)
        }
        val length = contentLength(headers)
        if (length != null) {
            var remaining = length
            while (remaining > 0) {
                val part = reader.readSome(minOf(remaining, 32768L).toInt()) ?: throw EOFException("unexpected end of body")
                sink(part)
                record(part)
                remaining -= part.size
            }
            return StreamResult(total, false)
        }
        while (true) {
            val part = reader.readSome(32768) ?: break
            sink(part)
            record(part)
        }
        return StreamResult(total, true)
    }
}
