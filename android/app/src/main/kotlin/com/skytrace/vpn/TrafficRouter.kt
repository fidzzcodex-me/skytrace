package com.skytrace.vpn

import com.skytrace.proxy.LocalProxyEngine
import com.skytrace.util.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

class TrafficRouter(
    private val tun: TunWriter,
    private val udp: UdpRelay,
    private val engine: LocalProxyEngine,
    private val scope: CoroutineScope
) {
    private val sessions = ConcurrentHashMap<String, TcpSession>()

    val activeConnections: Int get() = sessions.size

    fun startSweeper() {
        scope.launch(Dispatchers.Default) {
            while (isActive) {
                delay(500)
                val now = System.currentTimeMillis()
                for (session in sessions.values) {
                    session.tick(now)
                    if (now - session.lastActive > IDLE_TIMEOUT_MS) {
                        session.reset()
                    }
                }
                udp.sweep(now)
            }
        }
    }

    fun handle(buffer: ByteArray, length: Int) {
        val ip = IpPacket.parse(buffer, length) ?: return
        when (ip.protocol) {
            IpProtocol.TCP -> handleTcp(ip)
            IpProtocol.UDP -> udp.handle(ip)
            else -> Unit
        }
    }

    fun shutdown() {
        sessions.values.toList().forEach { it.reset() }
        sessions.clear()
        udp.closeAll()
    }

    private fun handleTcp(ip: IpPacket) {
        val seg = TcpSegment.parse(ip) ?: return
        val key = sessionKey(seg.srcPort, ip.dstAddress, seg.dstPort)
        val existing = sessions[key]
        if (existing != null) {
            existing.onSegment(seg)
            return
        }
        if (seg.syn && !seg.hasAck) {
            val session = TcpSession(
                srcIp = ip.srcAddress,
                dstIp = ip.dstAddress,
                srcPort = seg.srcPort,
                dstPort = seg.dstPort,
                tun = tun,
                onClosed = { closed -> sessions.remove(closed.key, closed) }
            )
            sessions[key] = session
            session.acceptSyn(seg)
            engine.handle(session)
            return
        }
        if (!seg.rst) {
            val ack = if (seg.hasAck) seg.ack else 0L
            val rstAck = (seg.seq + seg.payload.size + (if (seg.syn || seg.fin) 1 else 0)) and 0xFFFFFFFFL
            tun.write(
                PacketBuilder.tcp(
                    ip.dstAddress, ip.srcAddress, seg.dstPort, seg.srcPort,
                    ack, rstAck, TcpFlags.RST or TcpFlags.ACK, 0, ByteArray(0)
                )
            )
        }
    }

    companion object {
        private const val IDLE_TIMEOUT_MS = 10 * 60 * 1000L
    }
}
