package com.skytrace.util

import java.net.Inet4Address
import java.net.InetAddress
import java.net.NetworkInterface

object NetUtil {
    fun localIpv4(): List<String> {
        val out = mutableListOf<String>()
        val interfaces = NetworkInterface.getNetworkInterfaces() ?: return out
        while (interfaces.hasMoreElements()) {
            val ni = interfaces.nextElement()
            if (!ni.isUp || ni.isLoopback) continue
            val addrs = ni.inetAddresses
            while (addrs.hasMoreElements()) {
                val a = addrs.nextElement()
                if (a is Inet4Address && !a.isLoopbackAddress) a.hostAddress?.let { out.add(it) }
            }
        }
        return out
    }

    fun isLan(address: InetAddress?): Boolean {
        if (address == null) return false
        if (address.isLoopbackAddress || address.isSiteLocalAddress || address.isLinkLocalAddress) return true
        if (address is Inet4Address) {
            val b = address.address
            val first = b[0].toInt() and 0xFF
            val second = b[1].toInt() and 0xFF
            if (first == 100 && (second and 0xC0) == 64) return true
        }
        val bytes = address.address
        return bytes.size == 16 && (bytes[0].toInt() and 0xFE) == 0xFC
    }
}
