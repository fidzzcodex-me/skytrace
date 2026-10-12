package com.skytrace.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
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
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.Locale

class SkyVpnService : VpnService() {

    private var pfd: ParcelFileDescriptor? = null
    private var reader: PacketReader? = null
    private var router: TrafficRouter? = null
    private var tun: TunWriter? = null
    private var scope: CoroutineScope? = null
    private var statsJob: Job? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopVpn()
                return START_NOT_STICKY
            }
            else -> startVpn()
        }
        return START_STICKY
    }

    override fun onRevoke() {
        Logger.i("VPN permission revoked")
        stopVpn()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    private fun startVpn() {
        if (pfd != null) return
        Graph.init(this)
        VpnServiceManager.setState(VpnState.STARTING)
        createChannel()
        promoteToForeground(buildNotification("Starting"))
        val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        scope = serviceScope
        try {
            val settings = Graph.settings
            if (settings.clearOnStart) {
                serviceScope.launch { Graph.repository.clear() }
            }
            LiveStats.reset()
            Graph.certs.ensureCa()
            Graph.reloadRules()

            val builder = Builder()
                .setSession("SkyTrace")
                .setMtu(MTU)
                .addAddress(CLIENT_ADDRESS, 32)
                .addRoute("0.0.0.0", 0)
                .addDnsServer(settings.dns)
                .setBlocking(true)
            var allowed = 0
            for (pkg in settings.targetApps) {
                if (pkg == packageName) continue
                try {
                    builder.addAllowedApplication(pkg)
                    allowed++
                } catch (e: PackageManager.NameNotFoundException) {
                    Logger.w("target app not installed: $pkg")
                }
            }
            if (allowed == 0) builder.addDisallowedApplication(packageName)
            Logger.i("capture scope: ${if (allowed == 0) "all apps" else "$allowed selected apps"}")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) builder.setMetered(false)

            val descriptor = builder.establish() ?: throw IllegalStateException("VPN permission not granted")
            pfd = descriptor
            val writer = TunWriter(FileOutputStream(descriptor.fileDescriptor))
            tun = writer
            val udp = UdpRelay(this, writer, settings, serviceScope)
            val engine = LocalProxyEngine(this, serviceScope)
            val trafficRouter = TrafficRouter(writer, udp, engine, serviceScope)
            router = trafficRouter
            trafficRouter.startSweeper()
            val packetReader = PacketReader(FileInputStream(descriptor.fileDescriptor), trafficRouter, MTU)
            reader = packetReader
            packetReader.start()

            statsJob = serviceScope.launch {
                while (isActive) {
                    VpnServiceManager.activeConnections = trafficRouter.activeConnections
                    VpnServiceManager.emitStats()
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.notify(NOTIFICATION_ID, buildNotification(summaryText()))
                    delay(1000)
                }
            }
            VpnServiceManager.setState(VpnState.RUNNING)
            Logger.i("VPN established")
        } catch (e: Exception) {
            Logger.e("VPN start failed", e)
            VpnServiceManager.setState(VpnState.ERROR, e.message ?: e.javaClass.simpleName)
            cleanup()
            stopSelf()
        }
    }

    private fun stopVpn() {
        if (VpnServiceManager.state.value == VpnState.STOPPED && pfd == null) return
        VpnServiceManager.setState(VpnState.STOPPING)
        cleanup()
        VpnServiceManager.setState(VpnState.STOPPED)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun cleanup() {
        statsJob?.cancel()
        statsJob = null
        reader?.stopReading()
        reader = null
        router?.shutdown()
        router = null
        tun?.close()
        tun = null
        try {
            Graph.breakpoints.abortAll()
        } catch (e: Exception) {
            Logger.d("breakpoint cleanup skipped")
        }
        try {
            pfd?.close()
        } catch (e: Exception) {
            Logger.d("pfd close failed")
        }
        pfd = null
        scope?.cancel()
        scope = null
    }

    private fun summaryText(): String {
        val req = LiveStats.requests.get()
        return String.format(
            Locale.US,
            "%d requests | up %s | down %s",
            req,
            formatBytes(LiveStats.bytesUp.get()),
            formatBytes(LiveStats.bytesDown.get())
        )
    }

    private fun formatBytes(value: Long): String {
        if (value < 1024) return "$value B"
        val kb = value / 1024.0
        if (kb < 1024) return String.format(Locale.US, "%.1f KB", kb)
        val mb = kb / 1024.0
        if (mb < 1024) return String.format(Locale.US, "%.1f MB", mb)
        return String.format(Locale.US, "%.2f GB", mb / 1024.0)
    }

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
            this, 1, Intent(this, SkyVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_skytrace)
            .setContentTitle("SkyTrace is capturing")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .addAction(0, "Stop", stop)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun promoteToForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val ACTION_START = "com.skytrace.action.START"
        const val ACTION_STOP = "com.skytrace.action.STOP"
        private const val CHANNEL_ID = "skytrace_capture"
        private const val NOTIFICATION_ID = 1101
        private const val MTU = 1400
        private const val CLIENT_ADDRESS = "10.8.0.2"
    }
}
