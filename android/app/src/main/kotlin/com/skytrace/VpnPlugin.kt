package com.skytrace

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.graphics.drawable.toBitmap
import com.skytrace.proxy.Header
import com.skytrace.proxy.ReplayOverride
import com.skytrace.repo.Graph
import com.skytrace.repo.TrafficFilter
import com.skytrace.repo.TrafficSummary
import com.skytrace.rule.BreakpointEdit
import com.skytrace.rule.PendingBreakpoint
import com.skytrace.util.EventBus
import com.skytrace.util.Logger
import com.skytrace.vpn.VpnServiceManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.io.ByteArrayOutputStream

class VpnPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.ActivityResultListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var eventSink: EventChannel.EventSink? = null
    private var eventJob: Job? = null
    private var pendingVpnResult: MethodChannel.Result? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val iconCache = HashMap<String, ByteArray?>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        Graph.init(appContext)
        methodChannel = MethodChannel(binding.binaryMessenger, "skytrace/api")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "skytrace/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventJob?.cancel()
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        eventJob?.cancel()
        eventJob = scope.launch {
            EventBus.events.collect { payload -> eventSink?.success(payload) }
        }
        events?.success(
            Json.encodeToString(
                kotlinx.serialization.json.JsonObject.serializer(),
                kotlinx.serialization.json.buildJsonObject {
                    put("type", kotlinx.serialization.json.JsonPrimitive("vpn_state"))
                    put("data", VpnServiceManager.statusJson())
                }
            )
        )
    }

    override fun onCancel(arguments: Any?) {
        eventJob?.cancel()
        eventSink = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_VPN) {
            pendingVpnResult?.success(resultCode == Activity.RESULT_OK)
            pendingVpnResult = null
            return true
        }
        return false
    }

    private fun io(result: MethodChannel.Result, block: suspend () -> Any?) {
        scope.launch {
            try {
                val value = withContext(Dispatchers.IO) { block() }
                result.success(value)
            } catch (e: Exception) {
                Logger.e("channel call failed", e)
                result.error("skytrace_error", e.message ?: e.javaClass.simpleName, null)
            }
        }
    }

    private fun longArg(call: MethodCall, key: String): Long = (call.argument<Number>(key))?.toLong() ?: 0L

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "vpnPrepare" -> prepareVpn(result)
            "vpnStart" -> {
                VpnServiceManager.start(appContext)
                result.success(true)
            }
            "vpnStop" -> {
                VpnServiceManager.stop(appContext)
                result.success(true)
            }
            "vpnStatus" -> result.success(VpnServiceManager.statusJson().toString())
            "requestNotifications" -> requestNotifications(result)
            "trafficList" -> io(result) {
                val filter = TrafficFilter.fromMap(call.argument<Map<String, Any?>>("filter"))
                val limit = call.argument<Int>("limit") ?: 50
                val offset = call.argument<Int>("offset") ?: 0
                val list = Graph.repository.list(filter, limit, offset)
                json.encodeToString(ListSerializer(TrafficSummary.serializer()), list)
            }
            "trafficDetail" -> io(result) {
                Graph.repository.get(longArg(call, "id"))?.let { Graph.repository.detailJson(it).toString() }
            }
            "trafficClear" -> io(result) {
                Graph.repository.clear()
                true
            }
            "trafficDelete" -> io(result) {
                val ids = (call.argument<List<Number>>("ids") ?: emptyList()).map { it.toLong() }
                Graph.repository.delete(ids)
                true
            }
            "trafficCount" -> io(result) { Graph.repository.count() }
            "facets" -> io(result) { Graph.repository.facets().toString() }
            "stats" -> io(result) { Graph.repository.stats().toString() }
            "replay" -> io(result) {
                val id = longArg(call, "id")
                val override = call.argument<Map<String, Any?>>("override")?.let { m ->
                    @Suppress("UNCHECKED_CAST")
                    val headers = (m["headers"] as? List<Map<String, Any?>>)?.map {
                        Header(it["name"] as String, it["value"] as String)
                    }
                    ReplayOverride(m["method"] as? String, m["url"] as? String, headers, m["bodyText"] as? String)
                }
                Graph.replay.replay(id, override)
            }
            "curlFor" -> io(result) {
                Graph.repository.get(longArg(call, "id"))?.let { Graph.repository.curlFor(it) }
            }
            "export" -> io(result) {
                val format = call.argument<String>("format") ?: "har"
                val ids = call.argument<List<Number>>("ids")?.map { it.toLong() }
                val filter = TrafficFilter.fromMap(call.argument<Map<String, Any?>>("filter"))
                val list = Graph.repository.entities(filter, ids)
                val stamp = System.currentTimeMillis()
                val file = when (format) {
                    "har" -> Graph.repository.writeExport(appContext, "skytrace-$stamp.har", Graph.repository.exportHar(list))
                    "curl" -> Graph.repository.writeExport(appContext, "skytrace-$stamp.sh", Graph.repository.exportCurl(list))
                    else -> Graph.repository.writeExport(appContext, "skytrace-$stamp.txt", Graph.repository.exportRaw(list))
                }
                file.absolutePath
            }
            "shareFile" -> {
                shareFile(call.argument<String>("path") ?: "", call.argument<String>("mime") ?: "application/octet-stream")
                result.success(true)
            }
            "certStatus" -> io(result) { Graph.certs.status() }
            "certEnsure" -> io(result) {
                Graph.certs.ensureCa()
                Graph.certs.status()
            }
            "certRegenerate" -> io(result) {
                Graph.certs.regenerateCa()
                Graph.certs.status()
            }
            "certPem" -> io(result) { Graph.certs.caPem() }
            "certExport" -> io(result) { Graph.certs.exportToDownloads() }
            "certShare" -> io(result) {
                val file = Graph.certs.exportToCache()
                withContext(Dispatchers.Main) { shareFile(file.absolutePath, "application/x-x509-ca-cert") }
                true
            }
            "certInstall" -> io(result) {
                Graph.certs.ensureCa()
                val location = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Graph.certs.exportToDownloads() else ""
                withContext(Dispatchers.Main) { launchInstall() }
                location
            }
            "ruleList" -> io(result) {
                JsonArray(Graph.repository.listRules().map { Graph.repository.ruleToJson(it) }).toString()
            }
            "ruleSave" -> io(result) {
                val rule = Graph.repository.parseRule(call.argument<String>("json") ?: "{}")
                val id = Graph.repository.saveRule(rule)
                Graph.reloadRules()
                id
            }
            "ruleDelete" -> io(result) {
                Graph.repository.deleteRule(longArg(call, "id"))
                Graph.reloadRules()
                true
            }
            "ruleToggle" -> io(result) {
                Graph.repository.toggleRule(longArg(call, "id"), call.argument<Boolean>("enabled") ?: true)
                Graph.reloadRules()
                true
            }
            "bpList" -> io(result) {
                JsonArray(Graph.repository.listBreakpoints().map { Graph.repository.breakpointToJson(it) }).toString()
            }
            "bpSave" -> io(result) {
                val bp = Graph.repository.parseBreakpoint(call.argument<String>("json") ?: "{}")
                val id = Graph.repository.saveBreakpoint(bp)
                Graph.reloadRules()
                id
            }
            "bpDelete" -> io(result) {
                Graph.repository.deleteBreakpoint(longArg(call, "id"))
                Graph.reloadRules()
                true
            }
            "bpToggle" -> io(result) {
                Graph.repository.toggleBreakpoint(longArg(call, "id"), call.argument<Boolean>("enabled") ?: true)
                Graph.reloadRules()
                true
            }
            "bpPending" -> io(result) {
                json.encodeToString(ListSerializer(PendingBreakpoint.serializer()), Graph.breakpoints.pendingList())
            }
            "bpResume" -> io(result) {
                val id = call.argument<String>("id") ?: ""
                val editText = call.argument<String>("edit")
                val edit = if (editText.isNullOrBlank()) null else json.decodeFromString(BreakpointEdit.serializer(), editText)
                Graph.breakpoints.resume(id, edit)
            }
            "bpAbort" -> io(result) { Graph.breakpoints.abort(call.argument<String>("id") ?: "") }
            "settingsGet" -> io(result) { Graph.settings.toMap() }
            "settingsSet" -> io(result) {
                Graph.settings.update(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                Graph.breakpoints.timeoutSeconds = Graph.settings.breakpointTimeoutSec
                Graph.settings.toMap()
            }
            "installedApps" -> io(result) {
                val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                val pm = appContext.packageManager
                val apps = pm.getInstalledApplications(0)
                    .filter { it.packageName != appContext.packageName }
                    .filter { includeSystem || pm.getLaunchIntentForPackage(it.packageName) != null }
                    .map { info ->
                        val label = try {
                            pm.getApplicationLabel(info).toString()
                        } catch (e: Exception) {
                            info.packageName
                        }
                        Triple(label, info.packageName, (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
                    }
                    .sortedBy { it.first.lowercase() }
                JsonArray(
                    apps.map {
                        buildJsonObject {
                            put("label", it.first)
                            put("package", it.second)
                            put("system", it.third)
                        }
                    }
                ).toString()
            }
            "appIcon" -> io(result) { loadIcon(call.argument<String>("package") ?: "") }
            "logs" -> io(result) { Logger.recent() }
            else -> result.notImplemented()
        }
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(appContext)
        if (intent == null) {
            result.success(true)
            return
        }
        val host = activity
        if (host == null) {
            result.error("no_activity", "No foreground activity", null)
            return
        }
        pendingVpnResult?.success(false)
        pendingVpnResult = result
        host.startActivityForResult(intent, REQUEST_VPN)
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(appContext, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            if (!granted) {
                val host = activity
                if (host != null) {
                    ActivityCompat.requestPermissions(host, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
                }
            }
            result.success(granted)
        } else {
            result.success(true)
        }
    }

    private fun launchInstall() {
        val intent = Graph.certs.installIntent()
        val host = activity
        if (host != null) {
            host.startActivity(intent)
        } else {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            appContext.startActivity(intent)
        }
    }

    private fun shareFile(path: String, mime: String) {
        val file = java.io.File(path)
        if (!file.exists()) return
        val uri = FileProvider.getUriForFile(appContext, "${appContext.packageName}.fileprovider", file)
        val send = Intent(Intent.ACTION_SEND)
            .setType(mime)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val chooser = Intent.createChooser(send, "SkyTrace")
        val host = activity
        if (host != null) {
            host.startActivity(chooser)
        } else {
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            appContext.startActivity(chooser)
        }
    }

    private fun loadIcon(pkg: String): ByteArray? {
        synchronized(iconCache) {
            if (iconCache.containsKey(pkg)) return iconCache[pkg]
        }
        val bytes = try {
            val drawable = appContext.packageManager.getApplicationIcon(pkg)
            val bitmap = drawable.toBitmap(96, 96, Bitmap.Config.ARGB_8888)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        } catch (e: Exception) {
            null
        }
        synchronized(iconCache) { iconCache[pkg] = bytes }
        return bytes
    }

    companion object {
        private const val REQUEST_VPN = 7700
        private const val REQUEST_NOTIFICATIONS = 7701
    }
}
