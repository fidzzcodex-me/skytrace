package com.skytrace.vpn

import com.skytrace.util.putU16
import com.skytrace.util.putU32
import com.skytrace.util.u16
import com.skytrace.util.u32
import com.skytrace.util.u8

object IpProtocol {
    const val ICMP = 1
    const val TCP = 6
    const val UDP = 17
}

object TcpFlags {
    const val FIN = 0x01
    const val SYN = 0x02
    const val RST = 0x04
    const val PSH = 0x08
    const val ACK = 0x10
}

class IpPacket private constructor(
    val data: ByteArray,
    val length: Int,
    val headerLength: Int,
    val protocol: Int,
    val srcAddress: ByteArray,
    val dstAddress: ByteArray
) {
    val payloadOffset: Int get() = headerLength
    val payloadLength: Int get() = length - headerLength

    companion object {
        fun parse(buffer: ByteArray, length: Int): IpPacket? {
            if (length < 20) return null
            val version = (buffer[0].u8() shr 4)
            if (version != 4) return null
            val ihl = (buffer[0].u8() and 0x0F) * 4
            if (ihl < 20 || length < ihl) return null
            val total = buffer.u16(2)
            if (total < ihl || total > length) return null
            val fragment = buffer.u16(6)
            if ((fragment and 0x3FFF) != 0) return null
            val proto = buffer[9].u8()
            val src = buffer.copyOfRange(12, 16)
            val dst = buffer.copyOfRange(16, 20)
            return IpPacket(buffer, total, ihl, proto, src, dst)
        }
    }
}

class TcpSegment private constructor(
    val srcPort: Int,
    val dstPort: Int,
    val seq: Long,
    val ack: Long,
    val flags: Int,
    val window: Int,
    val payload: ByteArray
) {
    val syn: Boolean get() = flags and TcpFlags.SYN != 0
    val fin: Boolean get() = flags and TcpFlags.FIN != 0
    val rst: Boolean get() = flags and TcpFlags.RST != 0
    val hasAck: Boolean get() = flags and TcpFlags.ACK != 0

    companion object {
        fun parse(ip: IpPacket): TcpSegment? {
            val off = ip.payloadOffset
            if (ip.payloadLength < 20) return null
            val d = ip.data
            val dataOffset = (d[off + 12].u8() shr 4) * 4
            if (dataOffset < 20 || ip.payloadLength < dataOffset) return null
            val payloadStart = off + dataOffset
            val payloadLen = ip.length - payloadStart
            val payload = if (payloadLen > 0) d.copyOfRange(payloadStart, payloadStart + payloadLen) else ByteArray(0)
            return TcpSegment(
                srcPort = d.u16(off),
                dstPort = d.u16(off + 2),
                seq = d.u32(off + 4),
                ack = d.u32(off + 8),
                flags = d[off + 13].u8(),
                window = d.u16(off + 14),
                payload = payload
            )
        }
    }
}

class UdpDatagram private constructor(
    val srcPort: Int,
    val dstPort: Int,
    val payload: ByteArray
) {
    companion object {
        fun parse(ip: IpPacket): UdpDatagram? {
            if (ip.payloadLength < 8) return null
            val off = ip.payloadOffset
            val d = ip.data
            val len = d.u16(off + 4)
            val available = ip.length - off
            val usable = if (len in 8..available) len else available
            val payload = d.copyOfRange(off + 8, off + usable)
            return UdpDatagram(d.u16(off), d.u16(off + 2), payload)
        }
    }
}

object PacketBuilder {
    private val identification = java.util.concurrent.atomic.AtomicInteger(0)

    private fun nextId(): Int = identification.incrementAndGet() and 0xFFFF

    fun tcp(
        srcIp: ByteArray,
        dstIp: ByteArray,
        srcPort: Int,
        dstPort: Int,
        seq: Long,
        ack: Long,
        flags: Int,
        window: Int,
        payload: ByteArray,
        mss: Int = 0
    ): ByteArray {
        val optionLength = if (mss > 0) 4 else 0
        val tcpHeader = 20 + optionLength
        val total = 20 + tcpHeader + payload.size
        val p = ByteArray(total)
        writeIpHeader(p, total, IpProtocol.TCP, srcIp, dstIp)
        val t = 20
        p.putU16(t, srcPort)
        p.putU16(t + 2, dstPort)
        p.putU32(t + 4, seq and 0xFFFFFFFFL)
        p.putU32(t + 8, ack and 0xFFFFFFFFL)
        p[t + 12] = ((tcpHeader / 4) shl 4).toByte()
        p[t + 13] = flags.toByte()
        p.putU16(t + 14, window.coerceIn(0, 0xFFFF))
        if (mss > 0) {
            p[t + 20] = 2
            p[t + 21] = 4
            p.putU16(t + 22, mss)
        }
        System.arraycopy(payload, 0, p, t + tcpHeader, payload.size)
        val sum = transportChecksum(p, t, total - t, srcIp, dstIp, IpProtocol.TCP)
        p.putU16(t + 16, sum)
        return p
    }

    fun udp(
        srcIp: ByteArray,
        dstIp: ByteArray,
        srcPort: Int,
        dstPort: Int,
        payload: ByteArray
    ): ByteArray {
        val udpLen = 8 + payload.size
        val total = 20 + udpLen
        val p = ByteArray(total)
        writeIpHeader(p, total, IpProtocol.UDP, srcIp, dstIp)
        val t = 20
        p.putU16(t, srcPort)
        p.putU16(t + 2, dstPort)
        p.putU16(t + 4, udpLen)
        System.arraycopy(payload, 0, p, t + 8, payload.size)
        var sum = transportChecksum(p, t, udpLen, srcIp, dstIp, IpProtocol.UDP)
        if (sum == 0) sum = 0xFFFF
        p.putU16(t + 6, sum)
        return p
    }


    fun icmpPortUnreachable(srcIp: ByteArray, dstIp: ByteArray, original: ByteArray, originalLength: Int): ByteArray {
        val quoted = minOf(originalLength, 28)
        val icmpLen = 8 + quoted
        val total = 20 + icmpLen
        val p = ByteArray(total)
        writeIpHeader(p, total, IpProtocol.ICMP, srcIp, dstIp)
        p[20] = 3
        p[21] = 3
        System.arraycopy(original, 0, p, 28, quoted)
        p.putU16(22, checksum(p, 20, icmpLen, 0))
        return p
    }

    private fun writeIpHeader(p: ByteArray, total: Int, protocol: Int, src: ByteArray, dst: ByteArray) {
        p[0] = 0x45
        p[1] = 0
        p.putU16(2, total)
        p.putU16(4, nextId())
        p.putU16(6, 0x4000)
        p[8] = 64
        p[9] = protocol.toByte()
        p.putU16(10, 0)
        System.arraycopy(src, 0, p, 12, 4)
        System.arraycopy(dst, 0, p, 16, 4)
        p.putU16(10, checksum(p, 0, 20, 0))
    }

    private fun transportChecksum(
        p: ByteArray,
        offset: Int,
        length: Int,
        src: ByteArray,
        dst: ByteArray,
        protocol: Int
    ): Int {
        var sum = 0L
        sum += ((src[0].u8() shl 8) or src[1].u8()).toLong()
        sum += ((src[2].u8() shl 8) or src[3].u8()).toLong()
        sum += ((dst[0].u8() shl 8) or dst[1].u8()).toLong()
        sum += ((dst[2].u8() shl 8) or dst[3].u8()).toLong()
        sum += protocol.toLong()
        sum += length.toLong()
        return checksum(p, offset, length, sum)
    }

    private fun checksum(p: ByteArray, offset: Int, length: Int, initial: Long): Int {
        var sum = initial
        var i = offset
        val end = offset + length
        while (i + 1 < end) {
            sum += ((p[i].u8() shl 8) or p[i + 1].u8()).toLong()
            i += 2
        }
        if (i < end) sum += (p[i].u8() shl 8).toLong()
        while ((sum shr 16) != 0L) sum = (sum and 0xFFFF) + (sum shr 16)
        return (sum.inv() and 0xFFFF).toInt()
    }
}
