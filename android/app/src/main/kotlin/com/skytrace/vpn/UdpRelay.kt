package com.skytrace.vpn

import android.net.VpnService
import com.skytrace.repo.SettingsStore
import com.skytrace.util.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap

class UdpRelay(
    private val service: VpnService,
    private val tun: TunWriter,
    private val settings: SettingsStore,
    private val scope: CoroutineScope
) {
    private class Flow(val socket: DatagramSocket, val srcIp: ByteArray, val srcPort: Int, val dstIp: ByteArray, val dstPort: Int) {
        @Volatile
        var lastActive: Long = System.currentTimeMillis()
        var job: Job? = null
    }

    private val flows = ConcurrentHashMap<String, Flow>()

    fun handle(ip: IpPacket) {
        val datagram = UdpDatagram.parse(ip) ?: return
        if (datagram.dstPort == 53) {
            handleDns(ip, datagram)
            return
        }
        if (datagram.dstPort == 443 && settings.blockQuic) {
            tun.write(PacketBuilder.icmpPortUnreachable(ip.dstAddress, ip.srcAddress, ip.data, ip.length))
            return
        }
        val key = "${datagram.srcPort}>${ip.dstAddress.joinToString(".") { (it.toInt() and 0xFF).toString() }}:${datagram.dstPort}"
        val payload = datagram.payload
        val srcIp = ip.srcAddress
        val dstIp = ip.dstAddress
        scope.launch(Dispatchers.IO) {
            try {
                val flow = flows.getOrPut(key) { openFlow(srcIp, datagram.srcPort, dstIp, datagram.dstPort) }
                flow.lastActive = System.currentTimeMillis()
                flow.socket.send(DatagramPacket(payload, payload.size))
            } catch (e: Exception) {
                Logger.d("udp send failed: ${e.message}")
                flows.remove(key)?.socket?.close()
            }
        }
    }

    fun sweep(now: Long) {
        val it = flows.entries.iterator()
        while (it.hasNext()) {
            val entry = it.next()
            if (now - entry.value.lastActive > 60_000) {
                entry.value.socket.close()
                entry.value.job?.cancel()
                it.remove()
            }
        }
    }

    fun closeAll() {
        flows.values.forEach {
            it.socket.close()
            it.job?.cancel()
        }
        flows.clear()
    }

    private fun openFlow(srcIp: ByteArray, srcPort: Int, dstIp: ByteArray, dstPort: Int): Flow {
        val socket = DatagramSocket()
        service.protect(socket)
        socket.connect(InetSocketAddress(InetAddress.getByAddress(dstIp), dstPort))
        socket.soTimeout = 0
        val flow = Flow(socket, srcIp, srcPort, dstIp, dstPort)
        flow.job = scope.launch(Dispatchers.IO) {
            val buf = ByteArray(65535)
            while (isActive && !socket.isClosed) {
                try {
                    val packet = DatagramPacket(buf, buf.size)
                    socket.receive(packet)
                    flow.lastActive = System.currentTimeMillis()
                    val data = buf.copyOf(packet.length)
                    tun.write(PacketBuilder.udp(dstIp, srcIp, dstPort, srcPort, data))
                } catch (e: Exception) {
                    break
                }
            }
        }
        return flow
    }

    private fun handleDns(ip: IpPacket, datagram: UdpDatagram) {
        val query = datagram.payload
        val srcIp = ip.srcAddress
        val dstIp = ip.dstAddress
        val srcPort = datagram.srcPort
        if (DnsCache.questionType(query) == 28) {
            val reply = DnsCache.emptyResponse(query)
            tun.write(PacketBuilder.udp(dstIp, srcIp, 53, srcPort, reply))
            return
        }
        scope.launch(Dispatchers.IO) {
            var socket: DatagramSocket? = null
            try {
                socket = DatagramSocket()
                service.protect(socket)
                socket.soTimeout = 5000
                val target = InetAddress.getByName(settings.dns)
                socket.send(DatagramPacket(query, query.size, target, 53))
                val buf = ByteArray(4096)
                val packet = DatagramPacket(buf, buf.size)
                socket.receive(packet)
                val response = buf.copyOf(packet.length)
                DnsCache.learn(response)
                tun.write(PacketBuilder.udp(dstIp, srcIp, 53, srcPort, response))
            } catch (e: Exception) {
                Logger.d("dns query failed: ${e.message}")
            } finally {
                socket?.close()
            }
        }
    }
}
