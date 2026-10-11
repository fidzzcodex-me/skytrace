package com.skytrace.repo

import android.content.Context
import com.skytrace.cert.CertManager
import com.skytrace.proxy.ReplayClient
import com.skytrace.rule.BreakpointManager
import com.skytrace.rule.RewriteEngine
import com.skytrace.vpn.UidResolver
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

object Graph {
    private var initialized = false
    private val lock = Any()

    lateinit var settings: SettingsStore
        private set
    lateinit var repository: TrafficRepository
        private set
    lateinit var certs: CertManager
        private set
    lateinit var rewrite: RewriteEngine
        private set
    lateinit var breakpoints: BreakpointManager
        private set
    lateinit var uids: UidResolver
        private set
    lateinit var replay: ReplayClient
        private set

    val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun init(context: Context) {
        synchronized(lock) {
            if (initialized) return
            val app = context.applicationContext
            settings = SettingsStore(app)
            repository = TrafficRepository(app)
            certs = CertManager(app)
            rewrite = RewriteEngine()
            breakpoints = BreakpointManager()
            uids = UidResolver(app)
            replay = ReplayClient(repository, settings)
            breakpoints.timeoutSeconds = settings.breakpointTimeoutSec
            initialized = true
        }
        reloadRules()
    }

    fun reloadRules() {
        scope.launch {
            rewrite.load(repository.listRules())
            breakpoints.load(repository.listBreakpoints())
            breakpoints.timeoutSeconds = settings.breakpointTimeoutSec
        }
    }
}
