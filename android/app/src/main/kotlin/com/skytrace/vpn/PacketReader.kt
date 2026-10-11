package com.skytrace.vpn

import com.skytrace.util.Logger
import java.io.FileInputStream
import java.io.IOException

class PacketReader(
    private val input: FileInputStream,
    private val router: TrafficRouter,
    mtu: Int
) : Thread("skytrace-packet-reader") {

    private val buffer = ByteArray(maxOf(mtu, 1500) + 64)

    @Volatile
    private var running = true

    override fun run() {
        Logger.i("packet reader started")
        while (running) {
            try {
                val n = input.read(buffer)
                if (n < 0) break
                if (n > 0) router.handle(buffer, n)
            } catch (e: IOException) {
                if (running) Logger.w("packet reader stopped", e)
                break
            } catch (e: Exception) {
                Logger.e("packet handling error", e)
            }
        }
        Logger.i("packet reader finished")
    }

    fun stopReading() {
        running = false
        interrupt()
    }
}
