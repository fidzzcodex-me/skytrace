package com.skytrace.monitor

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.skytrace.repo.Graph
import com.skytrace.util.NetUtil
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

object MonitorManager {
    private val mutableState = MutableStateFlow("stopped")
    val state: StateFlow<String> = mutableState.asStateFlow()

    @Volatile
    var error: String = ""
        private set

    @Volatile
    var server: MonitorServer? = null

    fun setState(newState: String, newError: String = "") {
        error = newError
        mutableState.value = newState
    }

    fun isRunning(): Boolean = mutableState.value == "running"

    fun start(context: Context) {
        val intent = Intent(context, MonitorService::class.java).setAction(MonitorService.ACTION_START)
        ContextCompat.startForegroundService(context, intent)
    }

    fun stop(context: Context) {
        if (mutableState.value == "stopped" && server == null) return
        val intent = Intent(context, MonitorService::class.java).setAction(MonitorService.ACTION_STOP)
        context.startService(intent)
    }

    fun onCaptureStopped(context: Context) {
        if (isRunning() && Graph.settings.monitorStopWithCapture) stop(context)
    }

    fun statusMap(): Map<String, Any> {
        val settings = Graph.settings
        val port = settings.monitorPort
        val running = isRunning()
        return mapOf(
            "state" to mutableState.value,
            "running" to running,
            "port" to port,
            "error" to error,
            "pinSet" to settings.monitorPinHash.isNotEmpty(),
            "sessions" to (server?.sessionCount ?: 0),
            "urls" to if (running) NetUtil.localIpv4().map { "http://$it:$port" } else emptyList<String>()
        )
    }
}
