package com.skytrace.bubble

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.skytrace.repo.Graph
import com.skytrace.util.Logger

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        try {
            Graph.init(context)
            if (Graph.settings.bubbleEnabled) BubbleController.ensureService(context)
        } catch (e: Exception) {
            Logger.w("boot restore failed", e)
        }
    }
}
