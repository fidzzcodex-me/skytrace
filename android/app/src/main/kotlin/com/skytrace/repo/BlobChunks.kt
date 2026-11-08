package com.skytrace.repo

object BlobChunks {
    const val CHUNK_SIZE = 512 * 1024
    const val MAX_TOTAL = 8 * 1024 * 1024

    fun plan(total: Int, chunk: Int = CHUNK_SIZE, limit: Int = MAX_TOTAL): List<Pair<Int, Int>> {
        val capped = total.coerceAtMost(limit)
        if (capped <= 0 || chunk <= 0) return emptyList()
        val out = ArrayList<Pair<Int, Int>>()
        var start = 1
        var remaining = capped
        while (remaining > 0) {
            val len = minOf(chunk, remaining)
            out.add(Pair(start, len))
            start += len
            remaining -= len
        }
        return out
    }
}
