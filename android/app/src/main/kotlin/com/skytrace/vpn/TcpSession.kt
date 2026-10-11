package com.skytrace.vpn

import com.skytrace.proxy.ByteTransport
import com.skytrace.util.Logger
import kotlinx.coroutines.channels.Channel
import java.io.IOException
import java.security.SecureRandom

class TcpSession(
    val srcIp: ByteArray,
    val dstIp: ByteArray,
    val srcPort: Int,
    val dstPort: Int,
    private val tun: TunWriter,
    private val onClosed: (TcpSession) -> Unit
) : ByteTransport {

    private enum class State { SYN_RCVD, ESTABLISHED, FIN_WAIT, LAST_ACK, CLOSED }

    private class Inflight(val seq: Long, val data: ByteArray, val flags: Int, var sentAt: Long, var retries: Int)

    companion object {
        const val MSS = 1360
        private const val WINDOW = 65535
        private const val MAX_BUFFERED = 512 * 1024
        private const val RTO_MS = 900L
        private const val MAX_RETRIES = 8
        private val random = SecureRandom()

        fun lessThan(a: Long, b: Long): Boolean = (a - b).toInt() < 0
        fun lessOrEqual(a: Long, b: Long): Boolean = (a - b).toInt() <= 0
    }

    private val lock = Any()
    private var state = State.SYN_RCVD
    private var rcvNxt = 0L
    private val isn = random.nextInt().toLong() and 0xFFFFFFFFL
    private var sndNxt = isn
    private var sndUna = isn
    private var peerWindow = WINDOW
    private val inflight = ArrayDeque<Inflight>()
    private val pending = ArrayDeque<ByteArray>()
    private var pendingBytes = 0
    private var inflightBytes = 0
    private var finPending = false
    private var finSent = false
    private var finAcked = false
    private var peerFinReceived = false
    private var synAckRetries = 0
    private var synAckSentAt = 0L

    val input = Channel<ByteArray>(Channel.UNLIMITED)
    private val windowSignal = Channel<Unit>(Channel.CONFLATED)

    @Volatile
    var lastActive: Long = System.currentTimeMillis()
        private set

    val key: String get() = sessionKey(srcPort, dstIp, dstPort)

    val isClosed: Boolean get() = state == State.CLOSED

    fun acceptSyn(seg: TcpSegment) {
        synchronized(lock) {
            rcvNxt = (seg.seq + 1) and 0xFFFFFFFFL
            sendSynAck()
        }
    }

    fun onSegment(seg: TcpSegment) {
        synchronized(lock) {
            if (state == State.CLOSED) return
            lastActive = System.currentTimeMillis()
            if (seg.rst) {
                abortLocked()
                return
            }
            if (seg.syn) {
                if (state == State.SYN_RCVD) sendSynAck()
                return
            }
            if (state == State.SYN_RCVD) {
                if (seg.hasAck && seg.ack == ((isn + 1) and 0xFFFFFFFFL)) {
                    sndUna = seg.ack
                    sndNxt = seg.ack
                    state = State.ESTABLISHED
                } else {
                    return
                }
            }
            if (seg.hasAck) processAck(seg.ack, seg.window)
            var dataLen = seg.payload.size
            if (dataLen > 0) {
                var payload = seg.payload
                var seq = seg.seq
                if (lessThan(seq, rcvNxt)) {
                    val skip = ((rcvNxt - seq) and 0xFFFFFFFFL).toInt()
                    if (skip >= dataLen) {
                        sendAck()
                        payload = ByteArray(0)
                    } else {
                        payload = payload.copyOfRange(skip, dataLen)
                        seq = rcvNxt
                    }
                }
                if (payload.isNotEmpty()) {
                    if (seq == rcvNxt) {
                        input.trySend(payload)
                        rcvNxt = (rcvNxt + payload.size) and 0xFFFFFFFFL
                        dataLen = payload.size
                        sendAck()
                    } else {
                        sendAck()
                    }
                }
            }
            if (seg.fin) {
                val finSeq = (seg.seq + seg.payload.size) and 0xFFFFFFFFL
                if (finSeq == rcvNxt && !peerFinReceived) {
                    peerFinReceived = true
                    rcvNxt = (rcvNxt + 1) and 0xFFFFFFFFL
                    input.close()
                    sendAck()
                } else {
                    sendAck()
                }
            }
            checkDoneLocked()
        }
    }

    override suspend fun read(): ByteArray? = input.receiveCatching().getOrNull()

    override suspend fun write(data: ByteArray) {
        if (data.isEmpty()) return
        while (true) {
            synchronized(lock) {
                if (state == State.CLOSED || finPending || finSent) throw IOException("session closed")
                if (pendingBytes + inflightBytes < MAX_BUFFERED) {
                    pending.addLast(data)
                    pendingBytes += data.size
                    flushLocked()
                    return
                }
            }
            windowSignal.receiveCatching()
        }
    }

    override fun close() {
        synchronized(lock) {
            if (state == State.CLOSED || finPending) return
            finPending = true
            flushLocked()
            checkDoneLocked()
        }
    }

    fun reset() {
        synchronized(lock) {
            if (state == State.CLOSED) return
            tun.write(
                PacketBuilder.tcp(dstIp, srcIp, dstPort, srcPort, sndNxt, rcvNxt, TcpFlags.RST or TcpFlags.ACK, 0, ByteArray(0))
            )
            abortLocked()
        }
    }

    fun tick(now: Long) {
        synchronized(lock) {
            if (state == State.CLOSED) return
            if (state == State.SYN_RCVD) {
                if (now - synAckSentAt > RTO_MS) {
                    if (++synAckRetries > 5) {
                        abortLocked()
                    } else {
                        sendSynAck()
                    }
                }
                return
            }
            val head = inflight.firstOrNull()
            if (head != null && now - head.sentAt > RTO_MS) {
                if (head.retries >= MAX_RETRIES) {
                    Logger.w("tcp retransmit limit reached for $key")
                    abortLocked()
                    return
                }
                head.retries++
                head.sentAt = now
                emit(head.seq, head.data, head.flags)
            }
            if (pending.isNotEmpty() || finPending) flushLocked()
        }
    }

    private fun sendSynAck() {
        synAckSentAt = System.currentTimeMillis()
        tun.write(
            PacketBuilder.tcp(
                dstIp, srcIp, dstPort, srcPort,
                isn, rcvNxt, TcpFlags.SYN or TcpFlags.ACK, WINDOW, ByteArray(0), MSS
            )
        )
    }

    private fun sendAck() {
        tun.write(PacketBuilder.tcp(dstIp, srcIp, dstPort, srcPort, sndNxt, rcvNxt, TcpFlags.ACK, WINDOW, ByteArray(0)))
    }

    private fun emit(seq: Long, data: ByteArray, flags: Int) {
        tun.write(PacketBuilder.tcp(dstIp, srcIp, dstPort, srcPort, seq, rcvNxt, flags, WINDOW, data))
    }

    private fun processAck(ack: Long, window: Int) {
        peerWindow = window
        if (lessThan(sndUna, ack) && lessOrEqual(ack, sndNxt)) {
            sndUna = ack
            while (inflight.isNotEmpty()) {
                val head = inflight.first()
                val consumed = head.data.size + if (head.flags and TcpFlags.FIN != 0) 1 else 0
                val end = (head.seq + consumed) and 0xFFFFFFFFL
                if (lessOrEqual(end, ack)) {
                    inflight.removeFirst()
                    inflightBytes -= head.data.size
                    if (head.flags and TcpFlags.FIN != 0) finAcked = true
                } else {
                    break
                }
            }
            windowSignal.trySend(Unit)
        }
        flushLocked()
    }

    private fun flushLocked() {
        if (state == State.CLOSED || state == State.SYN_RCVD) return
        while (pending.isNotEmpty()) {
            val allowed = peerWindow - inflightBytes
            if (allowed <= 0) break
            val budget = minOf(MSS, allowed)
            val chunk = takePending(budget)
            if (chunk.isEmpty()) break
            val flags = TcpFlags.ACK or TcpFlags.PSH
            emit(sndNxt, chunk, flags)
            inflight.addLast(Inflight(sndNxt, chunk, flags, System.currentTimeMillis(), 0))
            inflightBytes += chunk.size
            sndNxt = (sndNxt + chunk.size) and 0xFFFFFFFFL
        }
        if (finPending && !finSent && pending.isEmpty()) {
            val flags = TcpFlags.FIN or TcpFlags.ACK
            emit(sndNxt, ByteArray(0), flags)
            inflight.addLast(Inflight(sndNxt, ByteArray(0), flags, System.currentTimeMillis(), 0))
            sndNxt = (sndNxt + 1) and 0xFFFFFFFFL
            finSent = true
            state = if (peerFinReceived) State.LAST_ACK else State.FIN_WAIT
        }
    }

    private fun takePending(max: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream(max)
        var remaining = max
        while (remaining > 0 && pending.isNotEmpty()) {
            val head = pending.first()
            if (head.size <= remaining) {
                out.write(head)
                remaining -= head.size
                pending.removeFirst()
                pendingBytes -= head.size
            } else {
                out.write(head, 0, remaining)
                pending[0] = head.copyOfRange(remaining, head.size)
                pendingBytes -= remaining
                remaining = 0
            }
        }
        return out.toByteArray()
    }

    private fun checkDoneLocked() {
        if (finSent && finAcked && peerFinReceived) abortLocked()
    }

    private fun abortLocked() {
        if (state == State.CLOSED) return
        state = State.CLOSED
        input.close()
        windowSignal.close()
        pending.clear()
        inflight.clear()
        onClosed(this)
    }
}

fun sessionKey(srcPort: Int, dstIp: ByteArray, dstPort: Int): String {
    return "$srcPort>${dstIp[0].toInt() and 0xFF}.${dstIp[1].toInt() and 0xFF}.${dstIp[2].toInt() and 0xFF}.${dstIp[3].toInt() and 0xFF}:$dstPort"
}
