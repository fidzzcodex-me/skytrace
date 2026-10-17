package com.skytrace.bubble

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.skytrace.MainActivity
import com.skytrace.R
import com.skytrace.VpnPlugin
import com.skytrace.repo.Graph
import com.skytrace.util.Logger
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

class FloatingWindow(
    private val context: Context,
    private val windowManager: WindowManager,
    private val onClosed: () -> Unit
) {
    private var root: FrameLayout? = null
    private var engine: FlutterEngine? = null
    private var flutterView: FlutterView? = null
    private var params: WindowManager.LayoutParams? = null

    val isShowing: Boolean get() = root != null

    private fun dp(value: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, context.resources.displayMetrics).toInt()

    private class GripView(context: Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        init {
            paint.color = 0x887A8FA6.toInt()
            paint.strokeWidth = 3f
            paint.strokeCap = Paint.Cap.ROUND
        }

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            canvas.drawLine(w - 8f, h - 20f, w - 20f, h - 8f, paint)
            canvas.drawLine(w - 8f, h - 12f, w - 12f, h - 8f, paint)
        }
    }

    private class WindowRoot(context: Context, private val onBack: () -> Unit) : FrameLayout(context) {
        override fun dispatchKeyEvent(event: KeyEvent): Boolean {
            if (event.keyCode == KeyEvent.KEYCODE_BACK) {
                if (event.action == KeyEvent.ACTION_UP) onBack()
                return true
            }
            return super.dispatchKeyEvent(event)
        }
    }

    @Suppress("DEPRECATION")
    private fun layoutParams(w: Int, h: Int): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val lp = WindowManager.LayoutParams(
            w, h, type,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
            WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN
        return lp
    }

    @SuppressLint("ClickableViewAccessibility")
    fun show() {
        if (root != null) return
        val dm = context.resources.displayMetrics
        val minW = dp(280f)
        val minH = dp(320f)
        val settings = Graph.settings
        val w = BubbleGeometry.clampSize(if (settings.windowW > 0) settings.windowW else (dm.widthPixels * 0.92f).toInt(), minW, dm.widthPixels)
        val h = BubbleGeometry.clampSize(if (settings.windowH > 0) settings.windowH else (dm.heightPixels * 0.62f).toInt(), minH, dm.heightPixels)
        val startX = if (settings.windowX >= 0) settings.windowX else (dm.widthPixels - w) / 2
        val startY = if (settings.windowY >= 0) settings.windowY else dp(48f)
        val (x, y) = BubbleGeometry.clampRect(startX, startY, w, h, dm.widthPixels, dm.heightPixels)

        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context.applicationContext)
        loader.ensureInitializationComplete(context.applicationContext, null)
        val flutterEngine = FlutterEngine(context.applicationContext)
        flutterEngine.plugins.add(VpnPlugin())
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "overlayMain")
        )
        val view = FlutterView(context, FlutterTextureView(context))
        view.attachToFlutterEngine(flutterEngine)
        flutterEngine.lifecycleChannel.appIsResumed()
        engine = flutterEngine
        flutterView = view

        val container = WindowRoot(context) { flutterEngine.navigationChannel.popRoute() }
        val bg = GradientDrawable()
        bg.cornerRadius = dp(14f).toFloat()
        bg.setColor(Color.WHITE)
        container.background = bg
        container.clipToOutline = true
        container.outlineProvider = ViewOutlineProvider.BACKGROUND
        container.elevation = dp(12f).toFloat()

        val column = LinearLayout(context)
        column.orientation = LinearLayout.VERTICAL

        val header = LinearLayout(context)
        header.orientation = LinearLayout.HORIZONTAL
        header.gravity = Gravity.CENTER_VERTICAL
        header.setBackgroundColor(0xFF2C5F9E.toInt())
        header.setPadding(dp(10f), 0, 0, 0)

        val logo = ImageView(context)
        logo.setImageResource(R.drawable.splash_logo)
        logo.scaleType = ImageView.ScaleType.FIT_CENTER
        header.addView(logo, LinearLayout.LayoutParams(dp(22f), dp(22f)))

        val title = TextView(context)
        title.text = "SkyTrace"
        title.setTextColor(Color.WHITE)
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
        title.setTypeface(title.typeface, android.graphics.Typeface.BOLD)
        title.setPadding(dp(8f), 0, 0, 0)
        header.addView(title, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

        fun headerButton(label: String, onClick: () -> Unit): TextView {
            val b = TextView(context)
            b.text = label
            b.gravity = Gravity.CENTER
            b.setTextColor(Color.WHITE)
            b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            b.setOnClickListener { onClick() }
            return b
        }

        val minimize = headerButton("\u2212") { hide() }
        val openApp = View(context)
        val box = GradientDrawable()
        box.setColor(Color.TRANSPARENT)
        box.setStroke(dp(2f), Color.WHITE)
        box.cornerRadius = dp(2f).toFloat()
        openApp.background = box
        val openWrap = FrameLayout(context)
        openWrap.addView(openApp, FrameLayout.LayoutParams(dp(14f), dp(14f), Gravity.CENTER))
        openWrap.setOnClickListener {
            hide()
            val intent = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            context.startActivity(intent)
        }
        val close = headerButton("\u00D7") { hide() }
        val buttonSize = LinearLayout.LayoutParams(dp(42f), LinearLayout.LayoutParams.MATCH_PARENT)
        header.addView(minimize, buttonSize)
        header.addView(openWrap, LinearLayout.LayoutParams(dp(42f), LinearLayout.LayoutParams.MATCH_PARENT))
        header.addView(close, LinearLayout.LayoutParams(dp(42f), LinearLayout.LayoutParams.MATCH_PARENT))

        column.addView(header, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(38f)))
        column.addView(view, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        container.addView(column, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        val grip = GripView(context)
        container.addView(grip, FrameLayout.LayoutParams(dp(36f), dp(36f), Gravity.BOTTOM or Gravity.END))

        val lp = layoutParams(w, h)
        lp.x = x
        lp.y = y
        params = lp

        var downX = 0
        var downY = 0
        var touchX = 0f
        var touchY = 0f
        header.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = lp.x
                    downY = lp.y
                    touchX = event.rawX
                    touchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val screen = context.resources.displayMetrics
                    val (nx, ny) = BubbleGeometry.clampRect(
                        downX + (event.rawX - touchX).toInt(), downY + (event.rawY - touchY).toInt(),
                        lp.width, lp.height, screen.widthPixels, screen.heightPixels
                    )
                    lp.x = nx
                    lp.y = ny
                    update(container, lp)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    Graph.settings.windowX = lp.x
                    Graph.settings.windowY = lp.y
                    true
                }
                else -> false
            }
        }

        var startW = 0
        var startH = 0
        grip.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startW = lp.width
                    startH = lp.height
                    touchX = event.rawX
                    touchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val screen = context.resources.displayMetrics
                    lp.width = BubbleGeometry.clampSize(startW + (event.rawX - touchX).toInt(), minW, screen.widthPixels - lp.x)
                    lp.height = BubbleGeometry.clampSize(startH + (event.rawY - touchY).toInt(), minH, screen.heightPixels - lp.y)
                    update(container, lp)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    Graph.settings.windowW = lp.width
                    Graph.settings.windowH = lp.height
                    true
                }
                else -> false
            }
        }

        try {
            windowManager.addView(container, lp)
            root = container
        } catch (e: Exception) {
            Logger.w("floating window failed", e)
            destroyEngine()
            onClosed()
        }
    }

    private fun update(view: View, lp: WindowManager.LayoutParams) {
        try {
            windowManager.updateViewLayout(view, lp)
        } catch (e: Exception) {
            Logger.d("window update skipped")
        }
    }

    private fun destroyEngine() {
        try {
            flutterView?.detachFromFlutterEngine()
        } catch (e: Exception) {
            Logger.d("flutter view detach failed")
        }
        try {
            engine?.lifecycleChannel?.appIsPaused()
            engine?.destroy()
        } catch (e: Exception) {
            Logger.d("flutter engine destroy failed")
        }
        flutterView = null
        engine = null
    }

    fun hide() {
        val view = root
        if (view != null) {
            try {
                windowManager.removeViewImmediate(view)
            } catch (e: Exception) {
                Logger.d("floating window already removed")
            }
        }
        root = null
        params = null
        destroyEngine()
        onClosed()
    }
}
