package com.skytrace.bubble

import android.animation.ValueAnimator
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
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.skytrace.MainActivity
import com.skytrace.R
import com.skytrace.repo.Graph
import com.skytrace.util.Logger
import com.skytrace.vpn.LiveStats
import com.skytrace.vpn.VpnServiceManager
import java.util.concurrent.Callable
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.hypot

object BubbleController {
    private const val RETRACT_MS = 3500L

    private var appContext: Context? = null
    private val main = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var bubble: FrameLayout? = null
    private var logoView: ImageView? = null
    private var arrowView: TextView? = null
    private var badge: TextView? = null
    private var circle: GradientDrawable? = null
    private var panel: View? = null
    private var panelCount: TextView? = null
    private var closeTarget: View? = null
    private var floating: FloatingWindow? = null
    private var params: WindowManager.LayoutParams? = null
    private var animator: ValueAnimator? = null
    private var docked = true
    private var side = 1
    private var baseline = 0L
    private var lastBadge = -1L
    private var probeCache: Boolean? = null

    private val retract = Runnable { dock() }

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
        if (running) baseline = LiveStats.requests.get()
    }

    fun refresh() {
        main.post { refreshInternal() }
    }

    fun relayout() {
        main.post {
            hide()
            refreshInternal()
        }
    }

    fun ensureService(context: Context) {
        val enabled = try {
            Graph.settings.bubbleEnabled
        } catch (e: Exception) {
            false
        }
        val intent = Intent(context, BubbleService::class.java)
        try {
            if (enabled) {
                intent.action = BubbleService.ACTION_START
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.stopService(intent)
            }
        } catch (e: Exception) {
            Logger.w("bubble service sync failed", e)
        }
        refresh()
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

    private fun dockedX(ctx: Context, size: Int): Int {
        val peek = dp(ctx, 20f)
        val screenW = ctx.resources.displayMetrics.widthPixels
        return if (side == 0) -(size - peek) else screenW - peek
    }

    private fun openX(ctx: Context, size: Int): Int {
        val margin = dp(ctx, 8f)
        val screenW = ctx.resources.displayMetrics.widthPixels
        return if (side == 0) margin else screenW - size - margin
    }

    private fun applyDockedStyle(active: Boolean) {
        circle?.setColor(if (active) 0xFF4A90E2.toInt() else Color.WHITE)
        logoView?.animate()?.alpha(if (active) 0f else 1f)?.setDuration(180)?.start()
        arrowView?.animate()?.alpha(if (active) 1f else 0f)?.setDuration(180)?.start()
        val arrow = arrowView
        if (arrow != null) {
            arrow.text = if (side == 0) "\u203A" else "\u2039"
            val lp = arrow.layoutParams as FrameLayout.LayoutParams
            lp.gravity = (if (side == 0) Gravity.END else Gravity.START) or Gravity.CENTER_VERTICAL
            arrow.layoutParams = lp
        }
        val badgeView = badge
        if (badgeView != null) {
            val lp = badgeView.layoutParams as FrameLayout.LayoutParams
            lp.gravity = Gravity.TOP or (if (side == 0) Gravity.END else Gravity.START)
            badgeView.layoutParams = lp
        }
    }

    private fun animateX(root: View, lp: WindowManager.LayoutParams, to: Int, onEnd: (() -> Unit)? = null) {
        animator?.cancel()
        val anim = ValueAnimator.ofInt(lp.x, to)
        anim.duration = 220
        anim.interpolator = DecelerateInterpolator()
        anim.addUpdateListener {
            lp.x = it.animatedValue as Int
            try {
                windowManager?.updateViewLayout(root, lp)
            } catch (e: Exception) {
                anim.cancel()
            }
        }
        anim.addListener(object : android.animation.AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: android.animation.Animator) {
                onEnd?.invoke()
            }
        })
        animator = anim
        anim.start()
    }

    private fun expand(ctx: Context) {
        val root = bubble ?: return
        val lp = params ?: return
        if (!docked) {
            scheduleRetract()
            return
        }
        docked = false
        applyDockedStyle(false)
        animateX(root, lp, openX(ctx, dp(ctx, 56f)))
        scheduleRetract()
    }

    private fun dock() {
        val ctx = appContext ?: return
        val root = bubble ?: return
        val lp = params ?: return
        if (docked || panel != null || floating?.isShowing == true || closeTarget != null) return
        docked = true
        applyDockedStyle(true)
        animateX(root, lp, dockedX(ctx, dp(ctx, 56f)))
    }

    private fun scheduleRetract() {
        main.removeCallbacks(retract)
        main.postDelayed(retract, RETRACT_MS)
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun show(ctx: Context) {
        if (bubble != null) return
        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm
        val size = dp(ctx, 56f)
        val dm = ctx.resources.displayMetrics
        side = if (Graph.settings.bubbleSide == 0) 0 else 1
        docked = true

        val root = FrameLayout(ctx)
        val bg = GradientDrawable()
        bg.shape = GradientDrawable.OVAL
        bg.setColor(0xFF4A90E2.toInt())
        bg.setStroke(dp(ctx, 1.5f), 0x554A90E2)
        circle = bg

        val icon = ImageView(ctx)
        icon.setImageResource(R.drawable.splash_logo)
        icon.scaleType = ImageView.ScaleType.FIT_CENTER
        val pad = dp(ctx, 10f)
        icon.setPadding(pad, pad, pad, pad)
        icon.alpha = 0f
        val base = FrameLayout(ctx)
        base.background = bg
        base.elevation = dp(ctx, 6f).toFloat()
        base.addView(icon, FrameLayout.LayoutParams(size, size))
        val arrow = TextView(ctx)
        arrow.setTextColor(Color.WHITE)
        arrow.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
        arrow.gravity = Gravity.CENTER
        base.addView(
            arrow,
            FrameLayout.LayoutParams(dp(ctx, 20f), size, Gravity.CENTER_VERTICAL or (if (side == 0) Gravity.END else Gravity.START))
        )
        root.addView(base, FrameLayout.LayoutParams(size, size))
        logoView = icon
        arrowView = arrow

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
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, dp(ctx, 18f), Gravity.TOP or (if (side == 0) Gravity.END else Gravity.START))
        )
        badge = badgeView

        val savedY = Graph.settings.bubbleY
        val startY = if (savedY >= 0) savedY else (dm.heightPixels * 0.35f).toInt()
        val (_, cy) = BubbleGeometry.clampPosition(0, startY, dm.widthPixels, dm.heightPixels, size)

        val lp = layout(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        lp.x = dockedX(ctx, size)
        lp.y = cy
        params = lp
        applyDockedStyle(true)

        val slop = ViewConfiguration.get(ctx).scaledTouchSlop
        val slide = dp(ctx, 14f)
        var downX = 0
        var downY = 0
        var touchX = 0f
        var touchY = 0f
        var moved = false
        var startedDocked = false

        root.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    main.removeCallbacks(retract)
                    animator?.cancel()
                    downX = lp.x
                    downY = lp.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    startedDocked = docked
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchX
                    val dy = event.rawY - touchY
                    if (startedDocked) {
                        val inward = if (side == 0) dx else -dx
                        if (inward >= slide && docked) {
                            moved = true
                            expand(ctx)
                        }
                    } else {
                        if (!moved && hypot(dx, dy) > slop) {
                            moved = true
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
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val over = !startedDocked && moved && isOverCloseTarget(size)
                    hideCloseTarget()
                    if (startedDocked) {
                        if (!moved) expand(ctx)
                    } else if (!moved) {
                        togglePanel(ctx, size)
                        if (panel == null && floating?.isShowing != true) scheduleRetract()
                    } else if (over) {
                        disableBubble(ctx)
                    } else {
                        side = if (lp.x + size / 2 < dm.widthPixels / 2) 0 else 1
                        Graph.settings.bubbleSide = side
                        Graph.settings.bubbleY = lp.y
                        applyDockedStyle(false)
                        animateX(root, lp, openX(ctx, size))
                        scheduleRetract()
                    }
                    true
                }
                else -> false
            }
        }

        wm.addView(root, lp)
        bubble = root
        baseline = LiveStats.requests.get()
        lastBadge = -1
        updateBadge()
        main.removeCallbacks(tick)
        main.postDelayed(tick, 2000)
    }

    private fun disableBubble(ctx: Context) {
        Graph.settings.bubbleEnabled = false
        hide()
        ensureService(ctx)
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
        val created = FloatingWindow(ctx, wm) {
            floating = null
            if (bubble != null) scheduleRetract()
        }
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
        val running = VpnServiceManager.isRunning()

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
        if (running) {
            box.addView(label(if (en) "Capture on ($mode)" else "Capture aktif ($mode)", 12.5f, 0xFF3D8B40.toInt(), true))
        } else {
            box.addView(label(if (en) "Capture off" else "Capture mati", 12.5f, 0xFF5A6E87.toInt(), true))
        }
        val countRow = LinearLayout(ctx)
        countRow.orientation = LinearLayout.HORIZONTAL
        countRow.setPadding(0, dp(ctx, 6f), 0, dp(ctx, 10f))
        val count = label("${LiveStats.requests.get()}", 20f, 0xFF1A2B4A.toInt(), true)
        panelCount = count
        countRow.addView(count)
        val unit = label(if (en) "  requests" else "  request", 12.5f, 0xFF5A6E87.toInt(), false)
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
        box.addView(openBtn, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        if (running) {
            val stopBtn = button("Stop capture", 0xFFFDECEA.toInt(), 0xFFC62828.toInt()) {
                hidePanel()
                VpnServiceManager.stop(ctx)
            }
            val gap = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            gap.topMargin = dp(ctx, 8f)
            box.addView(stopBtn, gap)
        }

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
        if (bubble != null) scheduleRetract()
    }

    private fun hide() {
        main.removeCallbacks(tick)
        main.removeCallbacks(retract)
        animator?.cancel()
        animator = null
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
        logoView = null
        arrowView = null
        circle = null
        params = null
    }
}
