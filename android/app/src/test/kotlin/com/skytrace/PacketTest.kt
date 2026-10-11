package com.skytrace

import com.skytrace.vpn.IpPacket
import com.skytrace.vpn.IpProtocol
import com.skytrace.vpn.PacketBuilder
import com.skytrace.vpn.TcpFlags
import com.skytrace.vpn.TcpSegment
import com.skytrace.vpn.UdpDatagram
import com.skytrace.util.u8
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PacketTest {
    private val src = byteArrayOf(10, 8, 0, 2)
    private val dst = byteArrayOf(93, 184.toByte(), 216.toByte(), 34)

    private fun onesComplementSum(data: ByteArray, offset: Int, length: Int, initial: Long): Long {
        var sum = initial
        var i = offset
        val end = offset + length
        while (i + 1 < end) {
            sum += ((data[i].u8() shl 8) or data[i + 1].u8()).toLong()
            i += 2
        }
        if (i < end) sum += (data[i].u8() shl 8).toLong()
        while ((sum shr 16) != 0L) sum = (sum and 0xFFFF) + (sum shr 16)
        return sum
    }

    @Test
    fun tcpPacketRoundTrip() {
        val payload = "hello skytrace".toByteArray()
        val raw = PacketBuilder.tcp(src, dst, 40000, 443, 1000L, 2000L, TcpFlags.PSH or TcpFlags.ACK, 65535, payload)
        val ip = IpPacket.parse(raw, raw.size)
        assertNotNull(ip)
        assertEquals(IpProtocol.TCP, ip!!.protocol)
        assertArrayEquals(src, ip.srcAddress)
        assertArrayEquals(dst, ip.dstAddress)
        val seg = TcpSegment.parse(ip)
        assertNotNull(seg)
        assertEquals(40000, seg!!.srcPort)
        assertEquals(443, seg.dstPort)
        assertEquals(1000L, seg.seq)
        assertEquals(2000L, seg.ack)
        assertTrue(seg.hasAck)
        assertArrayEquals(payload, seg.payload)
    }

    @Test
    fun ipHeaderChecksumIsValid() {
        val raw = PacketBuilder.tcp(src, dst, 1234, 80, 1L, 1L, TcpFlags.ACK, 1000, ByteArray(0))
        assertEquals(0xFFFFL, onesComplementSum(raw, 0, 20, 0))
    }

    @Test
    fun tcpChecksumIsValid() {
        val payload = ByteArray(33) { it.toByte() }
        val raw = PacketBuilder.tcp(src, dst, 1234, 80, 5L, 6L, TcpFlags.ACK or TcpFlags.PSH, 1000, payload)
        val tcpLen = raw.size - 20
        var pseudo = 0L
        pseudo += ((src[0].u8() shl 8) or src[1].u8()).toLong()
        pseudo += ((src[2].u8() shl 8) or src[3].u8()).toLong()
        pseudo += ((dst[0].u8() shl 8) or dst[1].u8()).toLong()
        pseudo += ((dst[2].u8() shl 8) or dst[3].u8()).toLong()
        pseudo += IpProtocol.TCP.toLong()
        pseudo += tcpLen.toLong()
        assertEquals(0xFFFFL, onesComplementSum(raw, 20, tcpLen, pseudo))
    }

    @Test
    fun synAckCarriesMssOption() {
        val raw = PacketBuilder.tcp(src, dst, 443, 40000, 7L, 8L, TcpFlags.SYN or TcpFlags.ACK, 65535, ByteArray(0), 1360)
        val ip = IpPacket.parse(raw, raw.size)!!
        val seg = TcpSegment.parse(ip)!!
        assertTrue(seg.syn)
        assertEquals(0, seg.payload.size)
        assertEquals(24 + 20, raw.size)
    }

    @Test
    fun udpRoundTrip() {
        val payload = byteArrayOf(1, 2, 3, 4, 5)
        val raw = PacketBuilder.udp(src, dst, 5353, 53, payload)
        val ip = IpPacket.parse(raw, raw.size)!!
        assertEquals(IpProtocol.UDP, ip.protocol)
        val datagram = UdpDatagram.parse(ip)!!
        assertEquals(5353, datagram.srcPort)
        assertEquals(53, datagram.dstPort)
        assertArrayEquals(payload, datagram.payload)
    }

    @Test
    fun rejectsIpv6AndTruncatedPackets() {
        val v6 = ByteArray(40)
        v6[0] = 0x60
        assertNull(IpPacket.parse(v6, v6.size))
        assertNull(IpPacket.parse(ByteArray(10), 10))
    }
}
