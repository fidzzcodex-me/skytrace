package com.skytrace.proxy

import com.skytrace.util.u16
import com.skytrace.util.u8
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WsFrameParser(private val direction: String, private val log: WebSocketLog) {
    private var buffer = ByteArray(0)
    private var skipping = 0L
    private var opcode = 0
    private var rsv1 = false
    private var masked = false
    private var maskKey = ByteArray(4)
    private var payloadLen = 0L
    private var collected = java.io.ByteArrayOutputStream()
    private var inPayload = false
    private var captured = 0L

    fun feed(data: ByteArray) {
        buffer += data
        loop@ while (true) {
            if (!inPayload) {
                if (buffer.size < 2) return
                val b0 = buffer[0].u8()
                val b1 = buffer[1].u8()
                opcode = b0 and 0x0F
                rsv1 = (b0 and 0x40) != 0
                masked = (b1 and 0x80) != 0
                var len = (b1 and 0x7F).toLong()
                var pos = 2
                if (len == 126L) {
                    if (buffer.size < pos + 2) return
                    len = buffer.u16(pos).toLong()
                    pos += 2
                } else if (len == 127L) {
                    if (buffer.size < pos + 8) return
                    var v = 0L
                    for (i in 0 until 8) v = (v shl 8) or buffer[pos + i].u8().toLong()
                    len = v
                    pos += 8
                }
                if (masked) {
                    if (buffer.size < pos + 4) return
                    maskKey = buffer.copyOfRange(pos, pos + 4)
                    pos += 4
                }
                buffer = buffer.copyOfRange(pos, buffer.size)
                payloadLen = len
                skipping = len
                collected = java.io.ByteArrayOutputStream()
                captured = 0
                inPayload = true
            }
            if (inPayload) {
                val take = minOf(skipping, buffer.size.toLong()).toInt()
                if (take > 0) {
                    val room = (MAX_CAPTURE - captured).toInt()
                    if (room > 0) {
                        val n = minOf(room, take)
                        for (i in 0 until n) {
                            val raw = buffer[i].toInt()
                            val v = if (masked) raw xor maskKey[((captured + i) % 4).toInt()].toInt() else raw
                            collected.write(v and 0xFF)
                        }
                        captured += n
                    }
                    buffer = buffer.copyOfRange(take, buffer.size)
                    skipping -= take
                }
                if (skipping == 0L) {
                    inPayload = false
                    emit()
                    continue@loop
                }
                return
            }
        }
    }

    private fun emit() {
        val label = when (opcode) {
            0x1 -> "text"
            0x2 -> "binary"
            0x8 -> "close"
            0x9 -> "ping"
            0xA -> "pong"
            0x0 -> "continuation"
            else -> "op$opcode"
        }
        val body = when {
            rsv1 -> "[compressed ${payloadLen} bytes]"
            opcode == 0x1 || opcode == 0x0 -> String(collected.toByteArray(), Charsets.UTF_8)
            opcode == 0x2 -> "[binary ${payloadLen} bytes]"
            else -> ""
        }
        log.add(direction, label, payloadLen, body)
    }

    companion object {
        private const val MAX_CAPTURE = 4096L
    }
}

class WebSocketLog(private val maxBytes: Int) {
    private val sb = StringBuilder()
    private val fmt = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)
    var frames = 0
        private set

    @Synchronized
    fun add(direction: String, label: String, size: Long, body: String) {
        frames++
        if (sb.length > maxBytes) return
        val arrow = if (direction == "client") ">>" else "<<"
        sb.append(fmt.format(Date())).append(' ').append(arrow).append(' ').append(label).append(" (").append(size).append(")")
        if (body.isNotEmpty()) sb.append(": ").append(body.replace("\n", "\\n"))
        sb.append('\n')
    }

    @Synchronized
    fun text(): String = sb.toString()
}

object WebSocketHandler {
    suspend fun relay(
        client: ByteTransport,
        upstream: ByteTransport,
        log: WebSocketLog,
        serverLeftover: ByteArray,
        clientLeftover: ByteArray
    ) {
        val toServer = WsFrameParser("client", log)
        val toClient = WsFrameParser("server", log)
        if (serverLeftover.isNotEmpty()) toClient.feed(serverLeftover)
        if (clientLeftover.isNotEmpty()) toServer.feed(clientLeftover)
        Relay.run(
            client,
            upstream,
            onAtoB = { toServer.feed(it) },
            onBtoA = { toClient.feed(it) }
        )
    }
}
