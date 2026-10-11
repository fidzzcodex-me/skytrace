package com.skytrace.proxy

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.Socket

class SocketTransport(val socket: Socket) : ByteTransport {
    private val input = socket.getInputStream()
    private val output = socket.getOutputStream()
    private val buffer = ByteArray(32768)

    override suspend fun read(): ByteArray? = withContext(Dispatchers.IO) {
        val n = input.read(buffer)
        if (n < 0) null else buffer.copyOf(n)
    }

    override suspend fun write(data: ByteArray) {
        withContext(Dispatchers.IO) {
            output.write(data)
            output.flush()
        }
    }

    override fun close() {
        try {
            socket.close()
        } catch (e: Exception) {
            return
        }
    }
}
