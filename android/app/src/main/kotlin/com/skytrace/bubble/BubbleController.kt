package com.skytrace.bubble

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.skytrace.MainActivity
import com.skytrace.R
import com.skytrace.repo.Graph
import com.skytrace.util.Logger
import com.skytrace.vpn.LiveStats
import com.skytrace.vpn.VpnServiceManager
import java.util.concurrent.Callable
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit
import kotlin.math.hypot

object BubbleController {
    private var appContext: Context? = null
    private val main = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var bubble: FrameLayout? = null
    private var badge: TextView? = null
    private var panel: View? = null
    private var panelCount: TextView? = null
    private var closeTarget: View? = null
    private var floating: FloatingWindow? = null
    private var params: WindowManager.LayoutParams? = null
    private var capturing = false
    private var dismissedForSession = false
    private var baseline = 0L
    private var lastBadge = -1L
    private var probeCache: Boolean? = null

    private val tick = object : Runnable {
        override fun run() {
            if (bubble == null) return
            val ctx = appContext ?: return
            val interactive = (ctx.getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
            if (interactive) updateBadge()
            main.postDelayed(this, if (interactive) 2000L else 10000L)
        }
    }

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    fun onStateChanged(running: Boolean) {
        capturing = running
        if (running) {
            dismissedForSession = false
            baseline = LiveStats.requests.get()
        }
        main.post { refreshInternal() }
    }

    fun refresh() {
        main.post { refreshInternal() }
    }

    fun permissionIntent(context: Context): Intent =
        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))

    fun supportStatus(context: Context, fresh: Boolean): Pair<String, String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return Pair("unsupported", "api")
        val pm = context.packageManager
        if (pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            pm.hasSystemFeature(PackageManager.FEATURE_WATCH) ||
            pm.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE)
        ) {
            return Pair("unsupported", "device")
        }
        val canDraw = try {
            Settings.canDrawOverlays(context)
        } catch (e: Exception) {
            return Pair("unsupported", "settings_api")
        }
        if (!canDraw) {
            probeCache = null
            return Pair("needs_permission", "")
        }
        val ok = if (!fresh && probeCache != null) probeCache!! else probeWindow(context).also { probeCache = it }
        return if (ok) Pair("supported", "") else Pair("unsupported", "window")
    }

    @Suppress("DEPRECATION")
    private fun layout(width: Int, height: Int, flags: Int): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val lp = WindowManager.LayoutParams(width, height, type, flags, PixelFormat.TRANSLUCENT)
        lp.gravity = Gravity.TOP or Gravity.START
        return lp
    }

    private fun probeWindow(context: Context): Boolean {
        val task = Callable {
            try {
                val wm = context.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val v = View(context.applicationContext)
                val lp = layout(
                    1, 1,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                )
                wm.addView(v, lp)
                wm.removeViewImmediate(v)
                true
            } catch (e: Exception) {
                Logger.w("overlay probe failed", e)
                false
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) return task.call()
        val future = FutureTask(task)
        main.post(future)
        return try {
            future.get(2, TimeUnit.SECONDS)
        } catch (e: Exception) {
            false
        }
    }

    private fun shouldShow(ctx: Context): Boolean {
        if (!capturing || dismissedForSession) return false
        val enabled = try {
            Graph.settings.bubbleEnabled
        } catch (e: Exception) {
            false
        }
        if (!enabled) return false
        return supportStatus(ctx, fresh = false).first == "supported"
    }

    private fun refreshInternal() {
        val ctx = appContext ?: return
        try {
            if (shouldShow(ctx)) show(ctx) else hide()
        } catch (e: Exception) {
            Logger.w("bubble refresh failed", e)
            hide()
        }
    }

    private fun dp(ctx: Context, value: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, ctx.resources.displayMetrics).toInt()

    private fun isEnglish(): Boolean = try {
        Graph.settings.language == "en"
    } catch (e: Exception) {
        false
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun show(ctx: Context) {
        if (bubble != null) return
        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm
        val size = dp(ctx, 56f)
        val dm = ctx.resources.displayMetrics

        val root = FrameLayout(ctx)
        val icon = ImageView(ctx)
        icon.setImageResource(R.drawable.splash_logo)
        icon.scaleType = ImageView.ScaleType.FIT_CENTER
        val pad = dp(ctx, 10f)
        icon.setPadding(pad, pad, pad, pad)
        val circle = GradientDrawable()
        circle.shape = GradientDrawable.OVAL
        circle.setColor(Color.WHITE)
        circle.setStroke(dp(ctx, 1.5f), 0x554A90E2)
        icon.background = circle
        icon.elevation = dp(ctx, 6f).toFloat()
        root.addView(icon, FrameLayout.LayoutParams(size, size))

        val badgeView = TextView(ctx)
        badgeView.setTextColor(Color.WHITE)
        badgeView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
        badgeView.gravity = Gravity.CENTER
        badgeView.setPadding(dp(ctx, 4f), 0, dp(ctx, 4f), 0)
        val badgeBg = GradientDrawable()
        badgeBg.shape = GradientDrawable.RECTANGLE
        badgeBg.cornerRadius = dp(ctx, 9f).toFloat()
        badgeBg.setColor(0xFFE53935.toInt())
        badgeView.background = badgeBg
        badgeView.minWidth = dp(ctx, 18f)
        badgeView.visibility = View.GONE
        badgeView.elevation = dp(ctx, 8f).toFloat()
        root.addView(
            badgeView,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, dp(ctx, 18f), Gravity.TOP or Gravity.END)
        )

        val margin = dp(ctx, 8f)
        val savedX = Graph.settings.bubbleX
        val savedY = Graph.settings.bubbleY
        val startX = if (savedX >= 0) savedX else dm.widthPixels - size - margin
        val startY = if (savedY >= 0) savedY else (dm.heightPixels * 0.35f).toInt()
        val (cx, cy) = BubbleGeometry.clampPosition(startX, startY, dm.widthPixels, dm.heightPixels, size)

        val lp = layout(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        lp.x = cx
        lp.y = cy
        params = lp

        val slop = ViewConfiguration.get(ctx).scaledTouchSlop
        var downX = 0
        var downY = 0
        var touchX = 0f
        var touchY = 0f
        var moved = false
        var longPressed = false
        val longPress = Runnable {
            if (!moved) {
                longPressed = true
                dismissForSession()
            }
        }

        root.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = lp.x
                    downY = lp.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    longPressed = false
                    main.postDelayed(longPress, 700)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchX
                    val dy = event.rawY - touchY
                    if (!moved && hypot(dx, dy) > slop) {
                        moved = true
                        main.removeCallbacks(longPress)
                        hidePanel()
                        showCloseTarget(ctx)
                    }
                    if (moved) {
                        val (nx, ny) = BubbleGeometry.clampPosition(
                            downX + dx.toInt(), downY + dy.toInt(), dm.widthPixels, dm.heightPixels, size
                        )
                        lp.x = nx
                        lp.y = ny
                        try {
                            wm.updateViewLayout(root, lp)
                        } catch (e: Exception) {
                            Logger.d("bubble move skipped")
                        }
                        highlightTarget(isOverCloseTarget(size))
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    main.removeCallbacks(longPress)
                    val over = moved && isOverCloseTarget(size)
                    hideCloseTarget()
                    if (longPressed) {
                        true
                    } else if (!moved) {
                        togglePanel(ctx, size)
                        true
                    } else if (over) {
                        dismissForSession()
                        true
                    } else {
                        lp.x = BubbleGeometry.snapX(lp.x, dm.widthPixels, size, margin)
                        try {
                            wm.updateViewLayout(root, lp)
                        } catch (e: Exception) {
                            Logger.d("bubble snap skipped")
                        }
                        Graph.settings.bubbleX = lp.x
                        Graph.settings.bubbleY = lp.y
                        true
                    }
                }
                else -> false
            }
        }

        wm.addView(root, lp)
        bubble = root
        badge = badgeView
        baseline = LiveStats.requests.get()
        lastBadge = -1
        updateBadge()
        main.removeCallbacks(tick)
        main.postDelayed(tick, 2000)
    }

    private fun updateBadge() {
        val count = (LiveStats.requests.get() - baseline).coerceAtLeast(0)
        if (count == lastBadge) return
        lastBadge = count
        val view = badge ?: return
        if (count <= 0) {
            view.visibility = View.GONE
        } else {
            view.text = BubbleGeometry.badgeText(count)
            view.visibility = View.VISIBLE
        }
        panelCount?.text = "${LiveStats.requests.get()}"
    }

    private fun dismissForSession() {
        dismissedForSession = true
        hide()
    }

    private fun showCloseTarget(ctx: Context) {
        if (closeTarget != null) return
        val wm = windowManager ?: return
        val dm = ctx.resources.displayMetrics
        val size = dp(ctx, 64f)
        val view = TextView(ctx)
        view.text = "X"
        view.gravity = Gravity.CENTER
        view.setTextColor(Color.WHITE)
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
        val bg = GradientDrawable()
        bg.shape = GradientDrawable.OVAL
        bg.setColor(0xCC1A2B4A.toInt())
        view.background = bg
        val lp = layout(
            size, size,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        lp.x = (dm.widthPixels - size) / 2
        lp.y = dm.heightPixels - size - dp(ctx, 96f)
        try {
            wm.addView(view, lp)
            closeTarget = view
        } catch (e: Exception) {
            Logger.d("close target not shown")
        }
    }

    private fun isOverCloseTarget(size: Int): Boolean {
        val target = closeTarget ?: return false
        val tl = target.layoutParams as? WindowManager.LayoutParams ?: return false
        val lp = params ?: return false
        return BubbleGeometry.isOverTarget(lp.x, lp.y, size, tl.x, tl.y, tl.width)
    }

    private fun highlightTarget(active: Boolean) {
        val bg = closeTarget?.background as? GradientDrawable ?: return
        bg.setColor(if (active) 0xFFE53935.toInt() else 0xCC1A2B4A.toInt())
    }

    private fun hideCloseTarget() {
        val view = closeTarget ?: return
        try {
            windowManager?.removeViewImmediate(view)
        } catch (e: Exception) {
            Logger.d("close target already removed")
        }
        closeTarget = null
    }

    private fun toggleFloatingWindow(ctx: Context) {
        val wm = windowManager ?: return
        val current = floating
        if (current != null && current.isShowing) {
            current.hide()
            return
        }
        hidePanel()
        val created = FloatingWindow(ctx, wm) { floating = null }
        floating = created
        created.show()
    }

    private fun togglePanel(ctx: Context, bubbleSize: Int) {
        if (Graph.settings.bubbleWindow) {
            toggleFloatingWindow(ctx)
            return
        }
        if (panel != null) {
            hidePanel()
            return
        }
        val wm = windowManager ?: return
        val lpBubble = params ?: return
        val dm = ctx.resources.displayMetrics
        val en = isEnglish()
        val width = dp(ctx, 220f)

        val box = LinearLayout(ctx)
        box.orientation = LinearLayout.VERTICAL
        val pad = dp(ctx, 14f)
        box.setPadding(pad, pad, pad, pad)
        val bg = GradientDrawable()
        bg.cornerRadius = dp(ctx, 16f).toFloat()
        bg.setColor(Color.WHITE)
        bg.setStroke(dp(ctx, 1f), 0x334A90E2)
        box.background = bg
        box.elevation = dp(ctx, 10f).toFloat()

        fun label(text: String, sp: Float, color: Int, bold: Boolean): TextView {
            val t = TextView(ctx)
            t.text = text
            t.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
            t.setTextColor(color)
            if (bold) t.setTypeface(t.typeface, android.graphics.Typeface.BOLD)
            return t
        }

        val mode = if (VpnServiceManager.activeMode == "proxy") "Proxy" else "VPN"
        box.addView(label("SkyTrace", 15f, 0xFF2C5F9E.toInt(), true))
        box.addView(label(if (en) "Capture on ($mode)" else "Capture aktif ($mode)", 12.5f, 0xFF4CAF50.toInt(), true))
        val countRow = LinearLayout(ctx)
        countRow.orientation = LinearLayout.HORIZONTAL
        countRow.setPadding(0, dp(ctx, 6f), 0, dp(ctx, 10f))
        val count = label("${LiveStats.requests.get()}", 20f, 0xFF1A2B4A.toInt(), true)
        panelCount = count
        countRow.addView(count)
        val unit = label(if (en) "  requests" else "  request", 12.5f, 0xFF7A8FA6.toInt(), false)
        unit.gravity = Gravity.BOTTOM
        countRow.addView(unit)
        box.addView(countRow)

        fun button(text: String, fill: Int, textColor: Int, onClick: () -> Unit): TextView {
            val b = label(text, 13f, textColor, true)
            b.gravity = Gravity.CENTER
            val d = GradientDrawable()
            d.cornerRadius = dp(ctx, 10f).toFloat()
            d.setColor(fill)
            b.background = d
            b.setPadding(0, dp(ctx, 10f), 0, dp(ctx, 10f))
            b.setOnClickListener { onClick() }
            return b
        }

        val openBtn = button(if (en) "Open SkyTrace" else "Buka SkyTrace", 0xFF4A90E2.toInt(), Color.WHITE) {
            hidePanel()
            baseline = LiveStats.requests.get()
            updateBadge()
            val intent = Intent(ctx, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            ctx.startActivity(intent)
        }
        val stopBtn = button(if (en) "Stop capture" else "Stop capture", 0xFFFDECEA.toInt(), 0xFFE53935.toInt()) {
            hidePanel()
            VpnServiceManager.stop(ctx)
        }
        val gap = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        gap.topMargin = dp(ctx, 8f)
        box.addView(openBtn, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        box.addView(stopBtn, gap)

        val lp = layout(
            width,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
        )
        val onLeft = lpBubble.x + bubbleSize / 2 < dm.widthPixels / 2
        lp.x = if (onLeft) lpBubble.x + bubbleSize + dp(ctx, 8f) else lpBubble.x - width - dp(ctx, 8f)
        lp.y = lpBubble.y.coerceAtMost(dm.heightPixels - dp(ctx, 220f)).coerceAtLeast(0)

        box.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_OUTSIDE) {
                hidePanel()
                true
            } else {
                false
            }
        }
        try {
            wm.addView(box, lp)
            panel = box
            baseline = LiveStats.requests.get()
            updateBadge()
        } catch (e: Exception) {
            Logger.w("bubble panel failed", e)
        }
    }

    private fun hidePanel() {
        val view = panel ?: return
        try {
            windowManager?.removeViewImmediate(view)
        } catch (e: Exception) {
            Logger.d("panel already removed")
        }
        panel = null
        panelCount = null
    }

    private fun hide() {
        main.removeCallbacks(tick)
        floating?.hide()
        floating = null
        hidePanel()
        hideCloseTarget()
        val view = bubble ?: return
        try {
            windowManager?.removeViewImmediate(view)
        } catch (e: Exception) {
            Logger.d("bubble already removed")
        }
        bubble = null
        badge = null
        params = null
    }
}
