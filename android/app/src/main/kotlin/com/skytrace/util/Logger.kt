package com.skytrace.util

import android.util.Log
import java.util.concurrent.ConcurrentLinkedDeque
import java.util.concurrent.atomic.AtomicInteger

object Logger {
    private const val TAG = "SkyTrace"
    private const val MAX_LINES = 500
    private val lines = ConcurrentLinkedDeque<String>()
    private val size = AtomicInteger(0)

    fun d(message: String) {
        Log.d(TAG, message)
        push("D", message)
    }

    fun i(message: String) {
        Log.i(TAG, message)
        push("I", message)
    }

    fun w(message: String, error: Throwable? = null) {
        Log.w(TAG, message, error)
        push("W", message + errorSuffix(error))
    }

    fun e(message: String, error: Throwable? = null) {
        Log.e(TAG, message, error)
        push("E", message + errorSuffix(error))
    }

    fun recent(): List<String> = lines.toList()

    fun clear() {
        lines.clear()
        size.set(0)
    }

    private fun errorSuffix(error: Throwable?): String =
        if (error == null) "" else " | ${error.javaClass.simpleName}: ${error.message}"

    private fun push(level: String, message: String) {
        lines.addLast("${System.currentTimeMillis()} $level $message")
        if (size.incrementAndGet() > MAX_LINES) {
            lines.pollFirst()
            size.decrementAndGet()
        }
    }
}
