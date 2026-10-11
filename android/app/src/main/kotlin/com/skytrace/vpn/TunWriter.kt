package com.skytrace.vpn

import com.skytrace.util.Logger
import java.io.FileOutputStream
import java.io.IOException

class TunWriter(private val output: FileOutputStream) {
    private val lock = Any()
    @Volatile
    private var closed = false

    fun write(packet: ByteArray) {
        if (closed) return
        synchronized(lock) {
            try {
                output.write(packet)
            } catch (e: IOException) {
                if (!closed) Logger.w("tun write failed", e)
            }
        }
    }

    fun close() {
        closed = true
    }
}
