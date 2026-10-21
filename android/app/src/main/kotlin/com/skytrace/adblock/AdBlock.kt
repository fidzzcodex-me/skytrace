package com.skytrace.adblock

import android.content.Context
import com.skytrace.repo.Graph
import com.skytrace.repo.TrafficEntity
import com.skytrace.util.Logger
import com.skytrace.util.globToRegex
import com.skytrace.vpn.AppIdentity
import com.skytrace.vpn.LiveStats
import java.util.concurrent.ConcurrentHashMap

object AdBlock {
    private val ads = HashSet<String>()
    private val trackers = HashSet<String>()
    @Volatile
    private var loaded = false
    private val lastRecorded = ConcurrentHashMap<String, Long>()

    private var customRaw = ""
    private var customEntries: Pair<Set<String>, List<Regex>> = Pair(emptySet(), emptyList())
    private var allowRaw = ""
    private var allowEntries: Pair<Set<String>, List<Regex>> = Pair(emptySet(), emptyList())

    fun load(context: Context) {
        if (loaded) return
        synchronized(this) {
            if (loaded) return
            readList(context, "adblock/ads.txt", ads)
            readList(context, "adblock/trackers.txt", trackers)
            loaded = true
        }
    }

    private fun readList(context: Context, path: String, target: MutableSet<String>) {
        try {
            context.assets.open(path).bufferedReader().useLines { lines ->
                lines.map { it.trim().lowercase() }.filter { it.isNotEmpty() }.forEach { target.add(it) }
            }
        } catch (e: Exception) {
            Logger.w("adblock list missing: $path", e)
        }
    }

    fun parseEntries(raw: String): Pair<Set<String>, List<Regex>> {
        val domains = HashSet<String>()
        val patterns = ArrayList<Regex>()
        raw.split('\n', ',', ';', ' ')
            .map { it.trim().lowercase() }
            .filter { it.isNotEmpty() && !it.startsWith("#") }
            .forEach { entry ->
                if (entry.contains('*') || entry.contains('?')) patterns.add(entry.globToRegex()) else domains.add(entry.removePrefix("."))
            }
        return Pair(domains, patterns)
    }

    fun suffixMatch(set: Set<String>, host: String): Boolean {
        if (set.isEmpty()) return false
        var current = host
        while (true) {
            if (set.contains(current)) return true
            val dot = current.indexOf('.')
            if (dot < 0) return false
            current = current.substring(dot + 1)
        }
    }

    private fun looksLikeIp(host: String): Boolean = host.all { it.isDigit() || it == '.' || it == ':' }

    fun shouldBlock(rawHost: String): Boolean {
        val settings = try {
            Graph.settings
        } catch (e: Exception) {
            return false
        }
        if (!settings.adblockEnabled) return false
        val host = rawHost.trim().lowercase().trimEnd('.')
        if (host.isEmpty() || looksLikeIp(host)) return false

        val allowText = settings.adblockAllow
        if (allowText != allowRaw) {
            allowEntries = parseEntries(allowText)
            allowRaw = allowText
        }
        if (suffixMatch(allowEntries.first, host) || allowEntries.second.any { it.containsMatchIn(host) }) return false

        val customText = settings.adblockCustom
        if (customText != customRaw) {
            customEntries = parseEntries(customText)
            customRaw = customText
        }
        if (suffixMatch(customEntries.first, host) || customEntries.second.any { it.containsMatchIn(host) }) return true

        if (settings.adblockAds && suffixMatch(ads, host)) return true
        if (settings.adblockTrackers && suffixMatch(trackers, host)) return true
        return false
    }

    suspend fun record(host: String, scheme: String, port: Int, app: AppIdentity, via: String) {
        LiveStats.blocked.incrementAndGet()
        val now = System.currentTimeMillis()
        val key = "${app.packageName}|$host"
        val previous = lastRecorded[key]
        if (previous != null && now - previous < 60_000) return
        if (lastRecorded.size > 2000) lastRecorded.clear()
        lastRecorded[key] = now
        val entity = TrafficEntity(
            timestamp = now,
            method = "BLOCKED",
            scheme = scheme,
            host = host,
            port = port,
            url = "$scheme://$host",
            statusMessage = "blocked-$via",
            appPackage = app.packageName,
            appName = app.label,
            uid = app.uid,
            totalMs = 1
        )
        Graph.repository.create(entity, Graph.settings.maxEntries)
        Graph.repository.finish(entity)
    }

    fun bundledCount(): Int = ads.size + trackers.size
}
