package com.skytrace.repo

import android.content.Context
import android.content.SharedPreferences

class SettingsStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences("skytrace_settings", Context.MODE_PRIVATE)

    var dns: String
        get() = prefs.getString("dns", "8.8.8.8") ?: "8.8.8.8"
        set(v) = prefs.edit().putString("dns", v).apply()

    var connectTimeoutMs: Int
        get() = prefs.getInt("connectTimeoutMs", 15000)
        set(v) = prefs.edit().putInt("connectTimeoutMs", v).apply()

    var readTimeoutMs: Int
        get() = prefs.getInt("readTimeoutMs", 30000)
        set(v) = prefs.edit().putInt("readTimeoutMs", v).apply()

    var maxBodyKb: Int
        get() = prefs.getInt("maxBodyKb", 2048)
        set(v) = prefs.edit().putInt("maxBodyKb", v).apply()

    var maxEntries: Int
        get() = prefs.getInt("maxEntries", 5000)
        set(v) = prefs.edit().putInt("maxEntries", v).apply()

    var blockQuic: Boolean
        get() = prefs.getBoolean("blockQuic", true)
        set(v) = prefs.edit().putBoolean("blockQuic", v).apply()

    var tlsInterception: Boolean
        get() = prefs.getBoolean("tlsInterception", true)
        set(v) = prefs.edit().putBoolean("tlsInterception", v).apply()

    var normalizeEncoding: Boolean
        get() = prefs.getBoolean("normalizeEncoding", true)
        set(v) = prefs.edit().putBoolean("normalizeEncoding", v).apply()

    var ignoreUpstreamCertErrors: Boolean
        get() = prefs.getBoolean("ignoreUpstreamCertErrors", false)
        set(v) = prefs.edit().putBoolean("ignoreUpstreamCertErrors", v).apply()

    var breakpointTimeoutSec: Int
        get() = prefs.getInt("breakpointTimeoutSec", 120)
        set(v) = prefs.edit().putInt("breakpointTimeoutSec", v).apply()

    var clearOnStart: Boolean
        get() = prefs.getBoolean("clearOnStart", false)
        set(v) = prefs.edit().putBoolean("clearOnStart", v).apply()

    var theme: String
        get() = prefs.getString("theme", "system") ?: "system"
        set(v) = prefs.edit().putString("theme", v).apply()

    var language: String
        get() = prefs.getString("language", "id") ?: "id"
        set(v) = prefs.edit().putString("language", v).apply()

    var targetApps: Set<String>
        get() = prefs.getStringSet("targetApps", emptySet())?.toSet() ?: emptySet()
        set(v) = prefs.edit().putStringSet("targetApps", v.toSet()).apply()

    var captureMode: String
        get() = prefs.getString("captureMode", "vpn") ?: "vpn"
        set(v) = prefs.edit().putString("captureMode", v).apply()

    var proxyPort: Int
        get() = prefs.getInt("proxyPort", 8888)
        set(v) = prefs.edit().putInt("proxyPort", v).apply()

    var proxyAuth: String
        get() = prefs.getString("proxyAuth", "") ?: ""
        set(v) = prefs.edit().putString("proxyAuth", v).apply()

    var proxyBindAll: Boolean
        get() = prefs.getBoolean("proxyBindAll", true)
        set(v) = prefs.edit().putBoolean("proxyBindAll", v).apply()

    var bypassHosts: String
        get() = prefs.getString("bypassHosts", "") ?: ""
        set(v) = prefs.edit().putString("bypassHosts", v).apply()

    var skippedVersion: String
        get() = prefs.getString("skippedVersion", "") ?: ""
        set(v) = prefs.edit().putString("skippedVersion", v).apply()

    var lastUpdateCheck: Long
        get() = prefs.getLong("lastUpdateCheck", 0L)
        set(v) = prefs.edit().putLong("lastUpdateCheck", v).apply()

    var onboardingDone: Boolean
        get() = prefs.getBoolean("onboardingDone", false)
        set(v) = prefs.edit().putBoolean("onboardingDone", v).apply()

    fun toMap(): Map<String, Any> = mapOf(
        "dns" to dns,
        "connectTimeoutMs" to connectTimeoutMs,
        "readTimeoutMs" to readTimeoutMs,
        "maxBodyKb" to maxBodyKb,
        "maxEntries" to maxEntries,
        "blockQuic" to blockQuic,
        "tlsInterception" to tlsInterception,
        "normalizeEncoding" to normalizeEncoding,
        "ignoreUpstreamCertErrors" to ignoreUpstreamCertErrors,
        "breakpointTimeoutSec" to breakpointTimeoutSec,
        "clearOnStart" to clearOnStart,
        "theme" to theme,
        "language" to language,
        "targetApps" to targetApps.toList(),
        "captureMode" to captureMode,
        "proxyPort" to proxyPort,
        "proxyAuth" to proxyAuth,
        "proxyBindAll" to proxyBindAll,
        "bypassHosts" to bypassHosts,
        "skippedVersion" to skippedVersion,
        "lastUpdateCheck" to lastUpdateCheck,
        "onboardingDone" to onboardingDone
    )

    fun update(values: Map<*, *>) {
        values.forEach { (k, v) ->
            when (k as? String) {
                "dns" -> (v as? String)?.takeIf { it.isNotBlank() }?.let { dns = it.trim() }
                "connectTimeoutMs" -> (v as? Number)?.let { connectTimeoutMs = it.toInt().coerceIn(1000, 120000) }
                "readTimeoutMs" -> (v as? Number)?.let { readTimeoutMs = it.toInt().coerceIn(1000, 300000) }
                "maxBodyKb" -> (v as? Number)?.let { maxBodyKb = it.toInt().coerceIn(16, 32768) }
                "maxEntries" -> (v as? Number)?.let { maxEntries = it.toInt().coerceIn(100, 100000) }
                "blockQuic" -> (v as? Boolean)?.let { blockQuic = it }
                "tlsInterception" -> (v as? Boolean)?.let { tlsInterception = it }
                "normalizeEncoding" -> (v as? Boolean)?.let { normalizeEncoding = it }
                "ignoreUpstreamCertErrors" -> (v as? Boolean)?.let { ignoreUpstreamCertErrors = it }
                "breakpointTimeoutSec" -> (v as? Number)?.let { breakpointTimeoutSec = it.toInt().coerceIn(5, 3600) }
                "clearOnStart" -> (v as? Boolean)?.let { clearOnStart = it }
                "theme" -> (v as? String)?.let { theme = it }
                "language" -> (v as? String)?.let { language = it }
                "captureMode" -> (v as? String)?.takeIf { it == "vpn" || it == "proxy" }?.let { captureMode = it }
                "proxyPort" -> (v as? Number)?.let { proxyPort = it.toInt().coerceIn(1024, 65535) }
                "proxyAuth" -> (v as? String)?.let { proxyAuth = it.trim() }
                "proxyBindAll" -> (v as? Boolean)?.let { proxyBindAll = it }
                "bypassHosts" -> (v as? String)?.let { bypassHosts = it }
                "skippedVersion" -> (v as? String)?.let { skippedVersion = it }
                "lastUpdateCheck" -> (v as? Number)?.let { lastUpdateCheck = it.toLong() }
                "targetApps" -> (v as? List<*>)?.let { list -> targetApps = list.filterIsInstance<String>().toSet() }
                "onboardingDone" -> (v as? Boolean)?.let { onboardingDone = it }
            }
        }
    }
}
