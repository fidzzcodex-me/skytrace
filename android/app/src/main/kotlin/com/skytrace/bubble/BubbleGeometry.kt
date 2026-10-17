package com.skytrace.bubble

object BubbleGeometry {
    fun clamp(value: Int, min: Int, max: Int): Int = if (max < min) min else value.coerceIn(min, max)

    fun clampPosition(x: Int, y: Int, screenW: Int, screenH: Int, size: Int, margin: Int = 0): Pair<Int, Int> {
        return Pair(
            clamp(x, margin, screenW - size - margin),
            clamp(y, margin, screenH - size - margin)
        )
    }

    fun clampRect(x: Int, y: Int, w: Int, h: Int, screenW: Int, screenH: Int): Pair<Int, Int> {
        return Pair(clamp(x, 0, screenW - w), clamp(y, 0, screenH - h))
    }

    fun clampSize(value: Int, min: Int, max: Int): Int = if (max < min) max.coerceAtLeast(0) else value.coerceIn(min, max)

    fun snapX(x: Int, screenW: Int, size: Int, margin: Int): Int {
        val center = x + size / 2
        return if (center < screenW / 2) margin else screenW - size - margin
    }

    fun isOverTarget(bubbleX: Int, bubbleY: Int, size: Int, targetX: Int, targetY: Int, targetSize: Int): Boolean {
        val bx = bubbleX + size / 2
        val by = bubbleY + size / 2
        val tx = targetX + targetSize / 2
        val ty = targetY + targetSize / 2
        val dx = (bx - tx).toLong()
        val dy = (by - ty).toLong()
        val reach = ((targetSize + size) / 2).toLong()
        return dx * dx + dy * dy <= reach * reach
    }

    fun badgeText(count: Long): String = if (count > 99) "99+" else count.toString()
}
