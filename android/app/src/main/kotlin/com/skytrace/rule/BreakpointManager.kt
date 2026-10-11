package com.skytrace.rule

import com.skytrace.proxy.Header
import com.skytrace.util.EventBus
import com.skytrace.util.Logger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.Base64
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

@Serializable
data class PendingBreakpoint(
    val id: String,
    val trafficId: Long,
    val phase: String,
    val method: String,
    val url: String,
    val startLine: String,
    val status: Int,
    val headers: List<Header>,
    val bodyText: String,
    val bodyBase64: String,
    val isBinary: Boolean,
    val createdAt: Long
)

@Serializable
data class BreakpointEdit(
    val method: String? = null,
    val path: String? = null,
    val status: Int? = null,
    val headers: List<Header>? = null,
    val bodyText: String? = null
)

sealed class BreakpointDecision {
    class Resume(val edit: BreakpointEdit?) : BreakpointDecision()
    object Abort : BreakpointDecision()
}

class BreakpointManager {
    @Volatile
    private var breakpoints: List<Breakpoint> = emptyList()
    private val waiting = ConcurrentHashMap<String, CompletableDeferred<BreakpointDecision>>()
    private val pending = ConcurrentHashMap<String, PendingBreakpoint>()
    private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }
    private val engine = RewriteEngine()

    @Volatile
    var timeoutSeconds: Int = 120

    fun load(list: List<Breakpoint>) {
        breakpoints = list.filter { it.enabled }
    }

    fun matches(phase: String, method: String, url: String): Boolean {
        return breakpoints.any {
            (if (phase == "request") it.onRequest else it.onResponse) &&
                (it.method == "*" || it.method.equals(method, true)) &&
                engine.urlMatches(it.urlPattern, it.isRegex, url)
        }
    }

    fun pendingList(): List<PendingBreakpoint> = pending.values.sortedBy { it.createdAt }

    fun resume(id: String, edit: BreakpointEdit?): Boolean {
        val d = waiting.remove(id) ?: return false
        pending.remove(id)
        d.complete(BreakpointDecision.Resume(edit))
        emitResolved(id)
        return true
    }

    fun abort(id: String): Boolean {
        val d = waiting.remove(id) ?: return false
        pending.remove(id)
        d.complete(BreakpointDecision.Abort)
        emitResolved(id)
        return true
    }

    fun abortAll() {
        waiting.keys.toList().forEach { abort(it) }
    }

    suspend fun intercept(
        phase: String,
        trafficId: Long,
        method: String,
        url: String,
        startLine: String,
        status: Int,
        headers: List<Header>,
        body: ByteArray,
        isText: Boolean
    ): BreakpointDecision {
        val id = UUID.randomUUID().toString()
        val item = PendingBreakpoint(
            id = id,
            trafficId = trafficId,
            phase = phase,
            method = method,
            url = url,
            startLine = startLine,
            status = status,
            headers = headers,
            bodyText = if (isText) String(body, Charsets.UTF_8) else "",
            bodyBase64 = if (isText) "" else Base64.getEncoder().encodeToString(body.copyOf(minOf(body.size, 262144))),
            isBinary = !isText,
            createdAt = System.currentTimeMillis()
        )
        val deferred = CompletableDeferred<BreakpointDecision>()
        waiting[id] = deferred
        pending[id] = item
        EventBus.emit("breakpoint_hit", Json.parseToJsonElement(json.encodeToString(item)))
        val decision = withTimeoutOrNull(timeoutSeconds * 1000L) { deferred.await() }
        if (decision == null) {
            Logger.w("breakpoint $id timed out, continuing")
            waiting.remove(id)
            pending.remove(id)
            emitResolved(id)
            return BreakpointDecision.Resume(null)
        }
        return decision
    }

    private fun emitResolved(id: String) {
        EventBus.emit("breakpoint_resolved", Json.parseToJsonElement("{\"id\":\"$id\"}"))
    }
}
