package com.skytrace.util

import java.net.InetAddress
import java.util.Locale

fun Byte.u8(): Int = toInt() and 0xFF

fun ByteArray.u16(offset: Int): Int = (this[offset].u8() shl 8) or this[offset + 1].u8()

fun ByteArray.u32(offset: Int): Long =
    (this[offset].u8().toLong() shl 24) or
        (this[offset + 1].u8().toLong() shl 16) or
        (this[offset + 2].u8().toLong() shl 8) or
        this[offset + 3].u8().toLong()

fun ByteArray.putU16(offset: Int, value: Int) {
    this[offset] = (value shr 8).toByte()
    this[offset + 1] = value.toByte()
}

fun ByteArray.putU32(offset: Int, value: Long) {
    this[offset] = (value shr 24).toByte()
    this[offset + 1] = (value shr 16).toByte()
    this[offset + 2] = (value shr 8).toByte()
    this[offset + 3] = value.toByte()
}

fun ByteArray.toIpString(): String = InetAddress.getByAddress(this).hostAddress ?: ""

fun ByteArray.indexOfSequence(pattern: ByteArray, start: Int = 0, end: Int = size): Int {
    if (pattern.isEmpty()) return start
    val last = end - pattern.size
    var i = start
    while (i <= last) {
        var matched = true
        var j = 0
        while (j < pattern.size) {
            if (this[i + j] != pattern[j]) {
                matched = false
                break
            }
            j++
        }
        if (matched) return i
        i++
    }
    return -1
}

fun ByteArray.startsWithAscii(prefix: String): Boolean {
    if (size < prefix.length) return false
    for (i in prefix.indices) {
        if (this[i].toInt() != prefix[i].code) return false
    }
    return true
}

fun String.globToRegex(): Regex {
    val sb = StringBuilder("^")
    for (c in this) {
        when (c) {
            '*' -> sb.append(".*")
            '?' -> sb.append('.')
            '.', '(', ')', '+', '|', '^', '$', '@', '%', '{', '}', '[', ']', '\\' -> sb.append('\\').append(c)
            else -> sb.append(c)
        }
    }
    sb.append('$')
    return Regex(sb.toString(), RegexOption.IGNORE_CASE)
}

fun String.lowerAscii(): String = lowercase(Locale.ROOT)

fun looksLikeText(contentType: String): Boolean {
    val ct = contentType.lowerAscii()
    return ct.startsWith("text/") ||
        ct.contains("json") ||
        ct.contains("xml") ||
        ct.contains("javascript") ||
        ct.contains("x-www-form-urlencoded") ||
        ct.contains("html") ||
        ct.contains("graphql") ||
        ct.contains("yaml") ||
        ct.contains("csv")
}

fun isHttpMethodPrefix(data: ByteArray): Boolean {
    val methods = arrayOf("GET ", "POST ", "PUT ", "DELETE ", "PATCH ", "HEAD ", "OPTIONS ", "TRACE ", "CONNECT ")
    for (m in methods) if (data.startsWithAscii(m)) return true
    return false
}

fun isProbablyText(contentType: String, body: ByteArray): Boolean {
    if (looksLikeText(contentType)) return true
    if (body.isEmpty()) return true
    val n = minOf(body.size, 512)
    var bad = 0
    for (i in 0 until n) {
        val b = body[i].toInt() and 0xFF
        if (b < 9 || b in 14..31) bad++
    }
    return bad * 20 < n
}
