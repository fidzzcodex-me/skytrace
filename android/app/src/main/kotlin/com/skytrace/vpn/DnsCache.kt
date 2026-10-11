package com.skytrace.vpn

import com.skytrace.util.u16
import com.skytrace.util.u8
import java.util.concurrent.ConcurrentHashMap

object DnsCache {
    private val names = ConcurrentHashMap<String, String>()

    fun hostFor(ip: ByteArray): String? = names[key(ip)]

    fun learn(response: ByteArray) {
        try {
            if (response.size < 12) return
            val qd = response.u16(4)
            val an = response.u16(6)
            var pos = 12
            var qname = ""
            for (i in 0 until qd) {
                val (name, next) = readName(response, pos)
                if (i == 0) qname = name
                pos = next + 4
            }
            for (i in 0 until an) {
                val (_, afterName) = readName(response, pos)
                if (afterName + 10 > response.size) return
                val type = response.u16(afterName)
                val rdLen = response.u16(afterName + 8)
                val rdStart = afterName + 10
                if (type == 1 && rdLen == 4 && rdStart + 4 <= response.size) {
                    val ip = response.copyOfRange(rdStart, rdStart + 4)
                    if (qname.isNotEmpty()) names[key(ip)] = qname
                }
                pos = rdStart + rdLen
            }
        } catch (e: Exception) {
            return
        }
    }

    fun questionType(query: ByteArray): Int {
        return try {
            if (query.size < 12 || query.u16(4) < 1) return -1
            val (_, next) = readName(query, 12)
            if (next + 2 > query.size) -1 else query.u16(next)
        } catch (e: Exception) {
            -1
        }
    }

    fun emptyResponse(query: ByteArray): ByteArray {
        val out = query.copyOf()
        out[2] = (0x81).toByte()
        out[3] = (0x80).toByte()
        out[6] = 0
        out[7] = 0
        out[8] = 0
        out[9] = 0
        out[10] = 0
        out[11] = 0
        return out
    }

    private fun readName(data: ByteArray, start: Int): Pair<String, Int> {
        val sb = StringBuilder()
        var pos = start
        var jumped = false
        var end = start
        var guard = 0
        while (guard++ < 64) {
            val len = data[pos].u8()
            if (len == 0) {
                if (!jumped) end = pos + 1
                break
            }
            if (len and 0xC0 == 0xC0) {
                val ptr = ((len and 0x3F) shl 8) or data[pos + 1].u8()
                if (!jumped) end = pos + 2
                jumped = true
                pos = ptr
                continue
            }
            if (sb.isNotEmpty()) sb.append('.')
            sb.append(String(data, pos + 1, len, Charsets.US_ASCII))
            pos += 1 + len
        }
        return Pair(sb.toString(), end)
    }

    private fun key(ip: ByteArray): String = "${ip[0].u8()}.${ip[1].u8()}.${ip[2].u8()}.${ip[3].u8()}"
}
