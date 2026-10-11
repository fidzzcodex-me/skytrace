package com.skytrace.proxy

import com.skytrace.cert.CertManager
import com.skytrace.util.u16
import com.skytrace.util.u8
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.IOException
import java.nio.ByteBuffer
import javax.net.ssl.SSLEngine
import javax.net.ssl.SSLEngineResult
import javax.net.ssl.SSLException

class TlsHandshakeResult(val transport: ByteTransport, val serverName: String?)

class TlsInterceptor(private val certs: CertManager) {

    suspend fun accept(client: ByteTransport, firstChunk: ByteArray, fallbackHost: String): TlsHandshakeResult {
        val hello = collectClientHello(client, firstChunk)
        val sni = parseSni(hello)
        val host = sni ?: fallbackHost
        val ctx = certs.contextFor(host)
        val engine = ctx.createSSLEngine()
        engine.useClientMode = false
        engine.needClientAuth = false
        engine.wantClientAuth = false
        val transport = SslEngineTransport(PrefixedTransport(hello, client), engine)
        transport.handshake()
        return TlsHandshakeResult(transport, sni)
    }

    private suspend fun collectClientHello(client: ByteTransport, first: ByteArray): ByteArray {
        var data = first
        while (true) {
            if (data.size >= 5) {
                val recordLen = data.u16(3)
                if (data.size >= 5 + recordLen) return data
                if (recordLen > 20000) throw IOException("invalid TLS record length")
            }
            val more = client.read() ?: throw IOException("client closed during ClientHello")
            data += more
            if (data.size > 40000) throw IOException("ClientHello too large")
        }
    }

    companion object {
        fun parseSni(data: ByteArray): String? {
            try {
                if (data.size < 43 || data[0].u8() != 0x16) return null
                var pos = 5
                if (data[pos].u8() != 0x01) return null
                pos += 4
                pos += 2
                pos += 32
                val sessionIdLen = data[pos].u8()
                pos += 1 + sessionIdLen
                val cipherLen = data.u16(pos)
                pos += 2 + cipherLen
                val compLen = data[pos].u8()
                pos += 1 + compLen
                if (pos + 2 > data.size) return null
                val extTotal = data.u16(pos)
                pos += 2
                val extEnd = minOf(pos + extTotal, data.size)
                while (pos + 4 <= extEnd) {
                    val type = data.u16(pos)
                    val len = data.u16(pos + 2)
                    pos += 4
                    if (type == 0 && pos + 5 <= data.size) {
                        val nameType = data[pos + 2].u8()
                        val nameLen = data.u16(pos + 3)
                        if (nameType == 0 && pos + 5 + nameLen <= data.size) {
                            return String(data, pos + 5, nameLen, Charsets.US_ASCII)
                        }
                    }
                    pos += len
                }
            } catch (e: Exception) {
                return null
            }
            return null
        }
    }
}

class SslEngineTransport(
    private val raw: ByteTransport,
    private val engine: SSLEngine
) : ByteTransport {

    private var inNet: ByteBuffer = ByteBuffer.allocate(engine.session.packetBufferSize * 2)
    private var inApp: ByteBuffer = ByteBuffer.allocate(engine.session.applicationBufferSize * 2)
    private val writeLock = Mutex()
    private var eof = false

    suspend fun handshake() {
        engine.beginHandshake()
        while (true) {
            when (engine.handshakeStatus) {
                SSLEngineResult.HandshakeStatus.NEED_UNWRAP -> if (!unwrapOnce()) throw IOException("closed during TLS handshake")
                SSLEngineResult.HandshakeStatus.NEED_WRAP -> wrapOnce(EMPTY)
                SSLEngineResult.HandshakeStatus.NEED_TASK -> runTasks()
                else -> return
            }
        }
    }

    override suspend fun read(): ByteArray? {
        while (true) {
            if (inApp.position() > 0) {
                inApp.flip()
                val out = ByteArray(inApp.remaining())
                inApp.get(out)
                inApp.clear()
                return out
            }
            if (eof) return null
            if (!unwrapOnce()) {
                eof = true
                return null
            }
            drainHandshakeWork()
        }
    }

    override suspend fun write(data: ByteArray) {
        if (data.isEmpty()) return
        val src = ByteBuffer.wrap(data)
        while (src.hasRemaining()) wrapOnce(src)
    }

    override fun close() {
        try {
            engine.closeOutbound()
        } catch (e: Exception) {
            return
        }
        try {
            raw.close()
        } catch (e: Exception) {
            return
        }
    }

    private suspend fun drainHandshakeWork() {
        while (true) {
            when (engine.handshakeStatus) {
                SSLEngineResult.HandshakeStatus.NEED_TASK -> runTasks()
                SSLEngineResult.HandshakeStatus.NEED_WRAP -> wrapOnce(EMPTY)
                else -> return
            }
        }
    }

    private fun runTasks() {
        while (true) {
            val task = engine.delegatedTask ?: break
            task.run()
        }
    }

    private suspend fun fill(): Boolean {
        val chunk = raw.read() ?: return false
        if (inNet.remaining() < chunk.size) {
            inNet.flip()
            val bigger = ByteBuffer.allocate(inNet.limit() + chunk.size + engine.session.packetBufferSize)
            bigger.put(inNet)
            inNet = bigger
        }
        inNet.put(chunk)
        return true
    }

    private suspend fun unwrapOnce(): Boolean {
        while (true) {
            inNet.flip()
            val result: SSLEngineResult
            try {
                result = engine.unwrap(inNet, inApp)
            } catch (e: SSLException) {
                inNet.compact()
                throw e
            }
            inNet.compact()
            when (result.status) {
                SSLEngineResult.Status.OK -> return true
                SSLEngineResult.Status.BUFFER_UNDERFLOW -> if (!fill()) return false
                SSLEngineResult.Status.BUFFER_OVERFLOW -> {
                    inApp.flip()
                    val bigger = ByteBuffer.allocate(inApp.limit() + engine.session.applicationBufferSize)
                    bigger.put(inApp)
                    inApp = bigger
                }
                SSLEngineResult.Status.CLOSED -> return false
                else -> return false
            }
        }
    }

    private suspend fun wrapOnce(src: ByteBuffer) {
        writeLock.withLock {
            var out = ByteBuffer.allocate(engine.session.packetBufferSize)
            while (true) {
                val result = engine.wrap(src, out)
                when (result.status) {
                    SSLEngineResult.Status.OK -> {
                        out.flip()
                        if (out.hasRemaining()) {
                            val bytes = ByteArray(out.remaining())
                            out.get(bytes)
                            raw.write(bytes)
                        }
                        return
                    }
                    SSLEngineResult.Status.BUFFER_OVERFLOW -> {
                        out = ByteBuffer.allocate(out.capacity() * 2)
                    }
                    SSLEngineResult.Status.CLOSED -> {
                        out.flip()
                        if (out.hasRemaining()) {
                            val bytes = ByteArray(out.remaining())
                            out.get(bytes)
                            raw.write(bytes)
                        }
                        throw IOException("TLS engine closed")
                    }
                    else -> throw IOException("unexpected wrap status ${result.status}")
                }
            }
        }
    }

    companion object {
        private val EMPTY: ByteBuffer = ByteBuffer.allocate(0)
    }
}
