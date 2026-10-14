package com.skytrace

import com.skytrace.monitor.MonitorAuth
import com.skytrace.monitor.MonitorProtocol
import com.skytrace.util.NetUtil
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.InetAddress

class MonitorTest {
    @Test
    fun websocketAcceptKeyMatchesRfcExample() {
        assertEquals("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", MonitorProtocol.acceptKey("dGhlIHNhbXBsZSBub25jZQ=="))
    }

    @Test
    fun smallTextFrameHasTwoByteHeader() {
        val frame = MonitorProtocol.text("hi")
        assertArrayEquals(byteArrayOf(0x81.toByte(), 2, 'h'.code.toByte(), 'i'.code.toByte()), frame)
    }

    @Test
    fun mediumFrameUsesExtendedLength() {
        val payload = ByteArray(300) { 1 }
        val frame = MonitorProtocol.frame(0x1, payload)
        assertEquals(126, frame[1].toInt())
        assertEquals(1, frame[2].toInt())
        assertEquals(44, frame[3].toInt())
        assertEquals(4 + 300, frame.size)
    }

    @Test
    fun largeFrameUsesEightByteLength() {
        val payload = ByteArray(70000)
        val frame = MonitorProtocol.frame(0x1, payload)
        assertEquals(127, frame[1].toInt())
        assertEquals(10 + 70000, frame.size)
    }

    @Test
    fun pinValidationAcceptsOnlyFourToSixDigits() {
        assertTrue(MonitorAuth.isValidPin("1234"))
        assertTrue(MonitorAuth.isValidPin("123456"))
        assertFalse(MonitorAuth.isValidPin("123"))
        assertFalse(MonitorAuth.isValidPin("1234567"))
        assertFalse(MonitorAuth.isValidPin("12ab"))
    }

    @Test
    fun randomPinIsSixDigits() {
        repeat(20) {
            val pin = MonitorAuth.randomPin()
            assertEquals(6, pin.length)
            assertTrue(MonitorAuth.isValidPin(pin))
        }
    }

    @Test
    fun hashedPinVerifiesAndRejectsWrongPin() {
        val salt = MonitorAuth.newSalt()
        val hash = MonitorAuth.hash(salt, "482913")
        assertTrue(MonitorAuth.matches(salt, hash, "482913"))
        assertFalse(MonitorAuth.matches(salt, hash, "482914"))
        assertFalse(MonitorAuth.matches("", hash, "482913"))
        assertNotEquals("482913", hash)
    }

    @Test
    fun differentSaltsGiveDifferentHashes() {
        assertNotEquals(MonitorAuth.hash("a", "1234"), MonitorAuth.hash("b", "1234"))
    }

    @Test
    fun tokensAreLongAndUnique() {
        val a = MonitorAuth.newToken()
        val b = MonitorAuth.newToken()
        assertEquals(64, a.length)
        assertNotEquals(a, b)
    }

    @Test
    fun lanDetectionAllowsPrivateRangesOnly() {
        assertTrue(NetUtil.isLan(InetAddress.getByName("192.168.1.20")))
        assertTrue(NetUtil.isLan(InetAddress.getByName("10.0.0.5")))
        assertTrue(NetUtil.isLan(InetAddress.getByName("172.16.4.9")))
        assertTrue(NetUtil.isLan(InetAddress.getByName("100.64.3.1")))
        assertTrue(NetUtil.isLan(InetAddress.getByName("127.0.0.1")))
        assertFalse(NetUtil.isLan(InetAddress.getByName("8.8.8.8")))
        assertFalse(NetUtil.isLan(InetAddress.getByName("203.0.113.7")))
    }
}
