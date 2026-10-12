package com.skytrace.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.skytrace.MainActivity
import com.skytrace.R
import com.skytrace.proxy.LocalProxyEngine
import com.skytrace.repo.Graph
import com.skytrace.util.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

class ProxyService : Service() {

    private var scope: CoroutineScope? = null
    private var server: ServerSocket? = null
    private var acceptJob: Job? = null
    private var statsJob: Job? = null
    private val active = AtomicInteger(0)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopProxy()
            stopSelf()
            return START_NOT_STICKY
        }
        startProxy()
        return START_STICKY
    }

    override fun onDestroy() {
        stopProxy()
        super.onDestroy()
    }

    private fun startProxy() {
        if (server != null) return
        Graph.init(this)
        VpnServiceManager.setState(VpnState.STARTING)
        createChannel()
        promote(buildNotification("Starting"))
        val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        scope = serviceScope
        try {
            val settings = Graph.settings
            if (settings.clearOnStart) serviceScope.launch { Graph.repository.clear() }
            LiveStats.reset()
            Graph.certs.ensureCa()
            Graph.reloadRules()

            val bindAddress = if (settings.proxyBindAll) InetAddress.getByName("0.0.0.0") else InetAddress.getLoopbackAddress()
            val socket = ServerSocket()
            socket.reuseAddress = true
            socket.bind(InetSocketAddress(bindAddress, settings.proxyPort))
            server = socket

            val engine = LocalProxyEngine({ }, serviceScope)
            acceptJob = serviceScope.launch {
                while (isActive && !socket.isClosed) {
                    try {
                        val client = socket.accept()
                        client.tcpNoDelay = true
                        client.soTimeout = settings.readTimeoutMs
                        launch {
                            active.incrementAndGet()
                            try {
                                engine.serveProxyConnection(client)
                            } finally {
                                active.decrementAndGet()
                            }
                        }
                    } catch (e: Exception) {
                        if (isActive && !socket.isClosed) Logger.w("proxy accept failed", e)
                    }
                }
            }
            statsJob = serviceScope.launch {
                while (isActive) {
                    VpnServiceManager.activeConnections = active.get()
                    VpnServiceManager.emitStats()
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.notify(NOTIFICATION_ID, buildNotification(summaryText(settings.proxyPort)))
                    delay(1000)
                }
            }
            VpnServiceManager.setState(VpnState.RUNNING)
            Logger.i("proxy listening on port ${settings.proxyPort}")
        } catch (e: Exception) {
            Logger.e("proxy start failed", e)
            VpnServiceManager.setState(VpnState.ERROR, e.message ?: e.javaClass.simpleName)
            cleanup()
            stopSelf()
        }
    }

    private fun stopProxy() {
        if (VpnServiceManager.state.value == VpnState.STOPPED && server == null) return
        VpnServiceManager.setState(VpnState.STOPPING)
        cleanup()
        VpnServiceManager.setState(VpnState.STOPPED)
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun cleanup() {
        statsJob?.cancel()
        statsJob = null
        acceptJob?.cancel()
        acceptJob = null
        try {
            server?.close()
        } catch (e: Exception) {
            Logger.d("server close failed")
        }
        server = null
        try {
            Graph.breakpoints.abortAll()
        } catch (e: Exception) {
            Logger.d("breakpoint cleanup skipped")
        }
        scope?.cancel()
        scope = null
    }

    private fun summaryText(port: Int): String = String.format(
        Locale.US,
        "proxy :%d | %d requests | %d active",
        port,
        LiveStats.requests.get(),
        active.get()
    )

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(CHANNEL_ID, "SkyTrace capture", NotificationManager.IMPORTANCE_LOW)
        channel.description = "Shows live statistics while SkyTrace captures traffic"
        channel.setShowBadge(false)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stop = PendingIntent.getService(
            this, 2, Intent(this, ProxyService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_skytrace)
            .setContentTitle("SkyTrace remote proxy")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .addAction(0, "Stop", stop)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun promote(notification: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val ACTION_START = "com.skytrace.action.PROXY_START"
        const val ACTION_STOP = "com.skytrace.action.PROXY_STOP"
        private const val CHANNEL_ID = "skytrace_capture"
        private const val NOTIFICATION_ID = 1102
    }
}
