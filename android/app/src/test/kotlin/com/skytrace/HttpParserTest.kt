package com.skytrace

import com.skytrace.proxy.ByteTransport
import com.skytrace.proxy.HttpParser
import com.skytrace.proxy.MessageReader
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeTransport(chunks: List<ByteArray>) : ByteTransport {
    private val queue = ArrayDeque(chunks)

    override suspend fun read(): ByteArray? = if (queue.isEmpty()) null else queue.removeFirst()

    override suspend fun write(data: ByteArray) = Unit

    override fun close() = Unit
}

class HttpParserTest {
    @Test
    fun parsesRequestHead() {
        val raw = "POST /api/v1/login?x=1 HTTP/1.1\r\nHost: api.example.com\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n"
        val head = HttpParser.parseRequestHead(raw.toByteArray())
        assertEquals("POST", head.method)
        assertEquals("/api/v1/login?x=1", head.target)
        assertEquals("HTTP/1.1", head.version)
        assertEquals(3, head.headers.size)
        assertEquals("api.example.com", head.headers[0].value)
    }

    @Test
    fun parsesResponseHeadWithoutReason() {
        val head = HttpParser.parseResponseHead("HTTP/1.1 204\r\nServer: test\r\n\r\n".toByteArray())
        assertEquals(204, head.status)
        assertEquals("", head.reason)
    }

    @Test
    fun readsHeadSplitAcrossChunks() = runBlocking {
        val reader = MessageReader(FakeTransport(listOf("GET / HTTP/1.1\r\nHo".toByteArray(), "st: a\r\n\r\nBODY".toByteArray())))
        val head = reader.readHead()
        assertTrue(String(head!!).endsWith("\r\n\r\n"))
        assertEquals("BODY", String(reader.readExactly(4)))
    }

    @Test
    fun returnsNullOnCleanEof() = runBlocking {
        val reader = MessageReader(FakeTransport(emptyList()))
        assertNull(reader.readHead())
    }

    @Test
    fun decodesChunkedBody() = runBlocking {
        val wire = "4\r\nWiki\r\n5\r\npedia\r\n0\r\n\r\n"
        val reader = MessageReader(FakeTransport(listOf(wire.toByteArray())))
        val body = HttpParser.readChunkedBuffered(reader, 1024)
        assertEquals("Wikipedia", String(body))
    }

    @Test
    fun readsContentLengthBody() = runBlocking {
        val reader = MessageReader(FakeTransport(listOf("hello world".toByteArray())))
        val head = HttpParser.parseResponseHead("HTTP/1.1 200 OK\r\nContent-Length: 11\r\n\r\n".toByteArray())
        val body = HttpParser.readResponseBodyBuffered(reader, head.headers, "GET", 200, 1024)
        assertEquals("hello world", String(body))
    }

    @Test
    fun headResponseHasNoBody() {
        assertEquals(false, HttpParser.responseHasBody("HEAD", 200))
        assertEquals(false, HttpParser.responseHasBody("GET", 304))
        assertEquals(true, HttpParser.responseHasBody("GET", 200))
    }
}
