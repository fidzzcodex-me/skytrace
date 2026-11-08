package com.skytrace

import com.skytrace.repo.BlobChunks
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BlobChunksTest {
    @Test
    fun smallBlobIsOneChunkStartingAtOne() {
        assertEquals(listOf(Pair(1, 100)), BlobChunks.plan(100))
    }

    @Test
    fun largeBlobIsSplitWithoutGapsOrOverlap() {
        val total = 2 * 1024 * 1024 + 123
        val plan = BlobChunks.plan(total)
        assertEquals(5, plan.size)
        assertEquals(total, plan.sumOf { it.second })
        var expectedStart = 1
        for ((start, len) in plan) {
            assertEquals(expectedStart, start)
            assertTrue(len <= BlobChunks.CHUNK_SIZE)
            expectedStart += len
        }
    }

    @Test
    fun totalIsCappedAndEmptyIsEmpty() {
        val plan = BlobChunks.plan(100 * 1024 * 1024)
        assertEquals(BlobChunks.MAX_TOTAL, plan.sumOf { it.second })
        assertTrue(BlobChunks.plan(0).isEmpty())
        assertTrue(BlobChunks.plan(-5).isEmpty())
    }
}
