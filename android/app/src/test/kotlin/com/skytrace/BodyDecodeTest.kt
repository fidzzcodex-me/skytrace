package com.skytrace

import com.skytrace.rule.RewriteEngine
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.util.zip.Deflater
import java.util.zip.DeflaterOutputStream
import java.util.zip.GZIPOutputStream

class BodyDecodeTest {
    private val text = "{\"token\":\"abc\",\"items\":[1,2,3,4,5,6,7,8,9]}".repeat(60)

    private fun gzip(data: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        GZIPOutputStream(out).use { it.write(data) }
        return out.toByteArray()
    }

    @Test
    fun gzipBodyIsDecoded() {
        val decoded = RewriteEngine.decodeLenient(gzip(text.toByteArray()), "gzip")
        assertArrayEquals(text.toByteArray(), decoded)
    }

    @Test
    fun truncatedGzipStillYieldsThePrefix() {
        val full = gzip(text.toByteArray())
        val cut = full.copyOf(full.size * 6 / 10)
        val decoded = RewriteEngine.decodeLenient(cut, "gzip")
        assertTrue(decoded != null && decoded.isNotEmpty())
        assertTrue(String(decoded!!).startsWith("{\"token\""))
    }

    @Test
    fun zlibAndRawDeflateBothWork() {
        val zlib = ByteArrayOutputStream()
        DeflaterOutputStream(zlib).use { it.write(text.toByteArray()) }
        assertArrayEquals(text.toByteArray(), RewriteEngine.decodeLenient(zlib.toByteArray(), "deflate"))

        val raw = ByteArrayOutputStream()
        DeflaterOutputStream(raw, Deflater(Deflater.DEFAULT_COMPRESSION, true)).use { it.write(text.toByteArray()) }
        assertArrayEquals(text.toByteArray(), RewriteEngine.decodeLenient(raw.toByteArray(), "deflate"))
    }

    @Test
    fun unknownOrBrokenEncodingsReturnNull() {
        assertNull(RewriteEngine.decodeLenient(byteArrayOf(1, 2, 3, 4), "br"))
        assertNull(RewriteEngine.decodeLenient(byteArrayOf(1, 2, 3, 4), "gzip"))
    }

    @Test
    fun identityAndEmptyPassThrough() {
        assertEquals(3, RewriteEngine.decodeLenient(byteArrayOf(1, 2, 3), "")!!.size)
        assertEquals(0, RewriteEngine.decodeLenient(ByteArray(0), "gzip")!!.size)
    }
}
