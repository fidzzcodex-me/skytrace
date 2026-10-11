package com.skytrace.vpn

import android.content.Context
import android.content.Intent
import android.net.VpnService
import androidx.core.content.ContextCompat
import com.skytrace.util.EventBus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.concurrent.atomic.AtomicLong

enum class VpnState { STOPPED, STARTING, RUNNING, STOPPING, ERROR }

object LiveStats {
    val requests = AtomicLong(0)
    val bytesUp = AtomicLong(0)
    val bytesDown = AtomicLong(0)
    val connections = AtomicLong(0)

    fun reset() {
        requests.set(0)
        bytesUp.set(0)
        bytesDown.set(0)
        connections.set(0)
    }
}

object VpnServiceManager {
    private val mutableState = MutableStateFlow(VpnState.STOPPED)
    val state: StateFlow<VpnState> = mutableState.asStateFlow()

    @Volatile
    var lastError: String? = null
        private set

    @Volatile
    var startedAt: Long = 0
        private set

    @Volatile
    var activeConnections: Int = 0

    fun prepareIntent(context: Context): Intent? = VpnService.prepare(context)

    fun start(context: Context) {
        val intent = Intent(context, SkyVpnService::class.java).setAction(SkyVpnService.ACTION_START)
        ContextCompat.startForegroundService(context, intent)
    }

    fun stop(context: Context) {
        val intent = Intent(context, SkyVpnService::class.java).setAction(SkyVpnService.ACTION_STOP)
        context.startService(intent)
    }

    fun setState(newState: VpnState, error: String? = null) {
        lastError = error
        if (newState == VpnState.RUNNING) startedAt = System.currentTimeMillis()
        mutableState.value = newState
        EventBus.emit("vpn_state", statusJson())
    }

    fun isRunning(): Boolean = mutableState.value == VpnState.RUNNING

    fun statusJson() = buildJsonObject {
        put("state", mutableState.value.name.lowercase())
        put("error", lastError ?: "")
        put("startedAt", startedAt)
        put("requests", LiveStats.requests.get())
        put("up", LiveStats.bytesUp.get())
        put("down", LiveStats.bytesDown.get())
        put("connections", activeConnections)
    }

    fun emitStats() {
        EventBus.emit("stats", statusJson())
    }
}
