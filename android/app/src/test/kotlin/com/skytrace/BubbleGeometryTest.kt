package com.skytrace

import com.skytrace.bubble.BubbleGeometry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BubbleGeometryTest {
    @Test
    fun clampKeepsBubbleOnScreen() {
        assertEquals(Pair(0, 0), BubbleGeometry.clampPosition(-50, -10, 1080, 2400, 168))
        assertEquals(Pair(1080 - 168, 2400 - 168), BubbleGeometry.clampPosition(5000, 9000, 1080, 2400, 168))
        assertEquals(Pair(300, 400), BubbleGeometry.clampPosition(300, 400, 1080, 2400, 168))
    }

    @Test
    fun snapPicksNearestEdge() {
        assertEquals(24, BubbleGeometry.snapX(100, 1080, 168, 24))
        assertEquals(1080 - 168 - 24, BubbleGeometry.snapX(700, 1080, 168, 24))
    }

    @Test
    fun overTargetDetectsOverlap() {
        assertTrue(BubbleGeometry.isOverTarget(500, 2000, 168, 508, 2020, 192))
        assertFalse(BubbleGeometry.isOverTarget(100, 300, 168, 508, 2020, 192))
    }

    @Test
    fun badgeCapsAtNinetyNinePlus() {
        assertEquals("7", BubbleGeometry.badgeText(7))
        assertEquals("99", BubbleGeometry.badgeText(99))
        assertEquals("99+", BubbleGeometry.badgeText(100))
    }
}
