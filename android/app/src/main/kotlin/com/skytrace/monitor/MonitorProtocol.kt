package com.skytrace.monitor

import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

object MonitorProtocol {
    private const val GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    fun acceptKey(clientKey: String): String {
        val sha = MessageDigest.getInstance("SHA-1").digest((clientKey.trim() + GUID).toByteArray())
        return Base64.getEncoder().encodeToString(sha)
    }

    fun frame(opcode: Int, payload: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(0x80 or opcode)
        when {
            payload.size < 126 -> out.write(payload.size)
            payload.size < 65536 -> {
                out.write(126)
                out.write(payload.size shr 8)
                out.write(payload.size and 0xFF)
            }
            else -> {
                out.write(127)
                val n = payload.size.toLong()
                for (shift in 56 downTo 0 step 8) out.write(((n shr shift) and 0xFF).toInt())
            }
        }
        out.write(payload)
        return out.toByteArray()
    }

    fun text(payload: String): ByteArray = frame(0x1, payload.toByteArray(Charsets.UTF_8))
}

object MonitorAuth {
    private val random = SecureRandom()

    fun isValidPin(pin: String): Boolean = pin.length in 4..6 && pin.all { it in '0'..'9' }

    fun randomPin(length: Int = 6): String {
        val sb = StringBuilder()
        repeat(length) { sb.append(random.nextInt(10)) }
        return sb.toString()
    }

    fun newSalt(): String {
        val bytes = ByteArray(16)
        random.nextBytes(bytes)
        return bytes.joinToString("") { String.format("%02x", it) }
    }

    fun hash(salt: String, pin: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        var data = (salt + pin).toByteArray()
        repeat(20000) { data = digest.digest(data) }
        return data.joinToString("") { String.format("%02x", it) }
    }

    fun matches(salt: String, expectedHash: String, pin: String): Boolean {
        if (salt.isEmpty() || expectedHash.isEmpty()) return false
        return MessageDigest.isEqual(hash(salt, pin).toByteArray(), expectedHash.toByteArray())
    }

    fun newToken(): String {
        val bytes = ByteArray(32)
        random.nextBytes(bytes)
        return bytes.joinToString("") { String.format("%02x", it) }
    }
}
