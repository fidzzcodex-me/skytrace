package com.skytrace.monitor

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
import com.skytrace.repo.Graph
import com.skytrace.util.Logger
import com.skytrace.util.NetUtil
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import java.net.BindException

class MonitorService : Service() {

    private var scope: CoroutineScope? = null
    private var server: MonitorServer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopMonitor()
            stopSelf()
            return START_NOT_STICKY
        }
        startMonitor()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopMonitor()
        super.onDestroy()
    }

    private fun startMonitor() {
        if (server != null) return
        Graph.init(this)
        createChannel()
        promote(buildNotification("Starting"))
        val settings = Graph.settings
        if (settings.monitorPinHash.isEmpty()) {
            MonitorManager.setState("error", "pin_not_set")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        scope = serviceScope
        val instance = MonitorServer(this, serviceScope)
        try {
            instance.start(settings.monitorPort)
            server = instance
            MonitorManager.server = instance
            settings.monitorEnabled = true
            MonitorManager.setState("running")
            val url = NetUtil.localIpv4().firstOrNull()?.let { "http://$it:${settings.monitorPort}" } ?: "port ${settings.monitorPort}"
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification(url))
            Logger.i("monitor listening on ${settings.monitorPort}")
        } catch (e: BindException) {
            Logger.w("monitor port in use", e)
            MonitorManager.setState("error", "port_in_use")
            cleanup()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } catch (e: Exception) {
            Logger.e("monitor start failed", e)
            MonitorManager.setState("error", e.message ?: e.javaClass.simpleName)
            cleanup()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun stopMonitor() {
        if (server == null && MonitorManager.state.value != "running") return
        cleanup()
        Graph.settings.monitorEnabled = false
        MonitorManager.setState("stopped")
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun cleanup() {
        server?.stop()
        server = null
        MonitorManager.server = null
        scope?.cancel()
        scope = null
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(CHANNEL_ID, "SkyTrace capture", NotificationManager.IMPORTANCE_LOW)
        channel.setShowBadge(false)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stop = PendingIntent.getService(
            this, 3, Intent(this, MonitorService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_skytrace)
            .setContentTitle("SkyTrace Live Monitor")
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
        const val ACTION_START = "com.skytrace.action.MONITOR_START"
        const val ACTION_STOP = "com.skytrace.action.MONITOR_STOP"
        private const val CHANNEL_ID = "skytrace_capture"
        private const val NOTIFICATION_ID = 1103
    }
}
