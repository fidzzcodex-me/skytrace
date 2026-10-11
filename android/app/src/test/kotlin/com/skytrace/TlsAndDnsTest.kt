package com.skytrace

import com.skytrace.proxy.TlsInterceptor
import com.skytrace.vpn.DnsCache
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import java.io.ByteArrayOutputStream

class TlsAndDnsTest {
    private fun clientHello(host: String): ByteArray {
        val name = host.toByteArray()
        val sni = ByteArrayOutputStream()
        sni.write(byteArrayOf(0, (name.size + 3).toByte(), 0, 0, name.size.toByte()))
        sni.write(name)
        val serverNameBody = sni.toByteArray()
        val ext = ByteArrayOutputStream()
        ext.write(byteArrayOf(0, 0, 0, serverNameBody.size.toByte()))
        ext.write(serverNameBody)
        val extBytes = ext.toByteArray()

        val body = ByteArrayOutputStream()
        body.write(byteArrayOf(3, 3))
        body.write(ByteArray(32))
        body.write(0)
        body.write(byteArrayOf(0, 2, 0x13, 0x01))
        body.write(byteArrayOf(1, 0))
        body.write(byteArrayOf(0, extBytes.size.toByte()))
        body.write(extBytes)
        val bodyBytes = body.toByteArray()

        val handshake = ByteArrayOutputStream()
        handshake.write(1)
        handshake.write(byteArrayOf(0, (bodyBytes.size shr 8).toByte(), bodyBytes.size.toByte()))
        handshake.write(bodyBytes)
        val hs = handshake.toByteArray()

        val record = ByteArrayOutputStream()
        record.write(byteArrayOf(0x16, 3, 1, (hs.size shr 8).toByte(), hs.size.toByte()))
        record.write(hs)
        return record.toByteArray()
    }

    @org.junit.Test
    fun extractsSniFromClientHello() {
        assertEquals("api.example.com", TlsInterceptor.parseSni(clientHello("api.example.com")))
    }

    @org.junit.Test
    fun returnsNullForNonTls() {
        assertNull(TlsInterceptor.parseSni("GET / HTTP/1.1\r\n\r\n".toByteArray()))
        assertNull(TlsInterceptor.parseSni(ByteArray(10)))
    }

    @org.junit.Test
    fun detectsAaaaQueryAndBuildsEmptyReply() {
        val query = byteArrayOf(
            0x12, 0x34, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0,
            3, 'w'.code.toByte(), 'w'.code.toByte(), 'w'.code.toByte(),
            7, 'e'.code.toByte(), 'x'.code.toByte(), 'a'.code.toByte(), 'm'.code.toByte(), 'p'.code.toByte(), 'l'.code.toByte(), 'e'.code.toByte(),
            3, 'c'.code.toByte(), 'o'.code.toByte(), 'm'.code.toByte(), 0,
            0, 28, 0, 1
        )
        assertEquals(28, DnsCache.questionType(query))
        val reply = DnsCache.emptyResponse(query)
        assertEquals(0x81, reply[2].toInt() and 0xFF)
        assertEquals(0, reply[7].toInt())
        assertEquals(query.size, reply.size)
    }
}
