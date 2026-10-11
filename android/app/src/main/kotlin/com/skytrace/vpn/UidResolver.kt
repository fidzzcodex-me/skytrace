package com.skytrace.vpn

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process
import android.system.OsConstants
import com.skytrace.util.Logger
import java.io.File
import java.net.InetAddress
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap

data class AppIdentity(val uid: Int, val packageName: String, val label: String)

class UidResolver(context: Context) {
    private val appContext = context.applicationContext
    private val connectivity = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val pm: PackageManager = appContext.packageManager
    private val identityCache = ConcurrentHashMap<Int, AppIdentity>()

    fun resolveTcp(srcIp: ByteArray, srcPort: Int, dstIp: ByteArray, dstPort: Int): AppIdentity {
        val uid = lookupUid(OsConstants.IPPROTO_TCP, "tcp", srcIp, srcPort, dstIp, dstPort)
        return identity(uid)
    }

    fun resolveUdp(srcIp: ByteArray, srcPort: Int, dstIp: ByteArray, dstPort: Int): AppIdentity {
        val uid = lookupUid(OsConstants.IPPROTO_UDP, "udp", srcIp, srcPort, dstIp, dstPort)
        return identity(uid)
    }

    fun identity(uid: Int): AppIdentity {
        if (uid < 0) return AppIdentity(-1, "unknown", "Unknown")
        return identityCache.getOrPut(uid) { loadIdentity(uid) }
    }

    private fun loadIdentity(uid: Int): AppIdentity {
        val packages = try {
            pm.getPackagesForUid(uid)
        } catch (e: Exception) {
            null
        }
        if (packages.isNullOrEmpty()) {
            val name = if (uid == Process.SYSTEM_UID) "android" else "uid:$uid"
            return AppIdentity(uid, name, name)
        }
        val pkg = packages[0]
        val label = try {
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: Exception) {
            pkg
        }
        return AppIdentity(uid, pkg, label)
    }

    private fun lookupUid(
        protocol: Int,
        procName: String,
        srcIp: ByteArray,
        srcPort: Int,
        dstIp: ByteArray,
        dstPort: Int
    ): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val local = InetSocketAddress(InetAddress.getByAddress(srcIp), srcPort)
                val remote = InetSocketAddress(InetAddress.getByAddress(dstIp), dstPort)
                val uid = connectivity.getConnectionOwnerUid(protocol, local, remote)
                if (uid != Process.INVALID_UID) return uid
            } catch (e: Exception) {
                Logger.d("getConnectionOwnerUid failed: ${e.message}")
            }
        }
        return lookupProc(procName, srcIp, srcPort)
    }

    private fun lookupProc(name: String, srcIp: ByteArray, srcPort: Int): Int {
        try {
            val file = File("/proc/net/$name")
            if (!file.canRead()) return -1
            val hexIp = String.format(
                "%02X%02X%02X%02X",
                srcIp[3].toInt() and 0xFF,
                srcIp[2].toInt() and 0xFF,
                srcIp[1].toInt() and 0xFF,
                srcIp[0].toInt() and 0xFF
            )
            val hexPort = String.format("%04X", srcPort)
            val target = "$hexIp:$hexPort"
            file.useLines { lines ->
                for (line in lines.drop(1)) {
                    val parts = line.trim().split(Regex("\\s+"))
                    if (parts.size > 7 && parts[1].equals(target, ignoreCase = true)) {
                        return parts[7].toIntOrNull() ?: -1
                    }
                }
            }
        } catch (e: Exception) {
            Logger.d("proc lookup failed: ${e.message}")
        }
        return -1
    }
}
