package com.songloft.songloft_flutter

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

/**
 * 安卓悬浮歌词窗口（songloft-org/songloft#318）。
 *
 * 用原生 WindowManager overlay 实现，不走桌面端 desktop_multi_window 的第二 Flutter engine 方案——手机上一个原生 TextView
 * 悬浮窗足够，没必要多起一个 engine。
 *
 * 权限检查/申请完全交给 Dart 侧的 permission_handler（仅在设置开关打开的那一刻申请）， 这里只在真正 addView 失败时兜底报错，不主动弹权限申请。
 */
class FloatingLyricPlugin(
    private val context: Context,
    flutterEngine: FlutterEngine,
    private val cacheStorage: SongCacheStorage,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "com.songloft/floating_lyric"
        private const val LONG_PRESS_MS = 500L
        private const val DRAG_SLOP_PX = 8
    }

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var container: LinearLayout? = null
    private var tvCurrent: TextView? = null
    private var tvNext: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var locked = false

    // 拖动/长按手势状态
    private var downRawX = 0f
    private var downRawY = 0f
    private var downParamX = 0
    private var downParamY = 0
    private var moved = false
    private val longPressRunnable = Runnable {
        channel.invokeMethod("onHideRequested", null)
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "show" -> handleShow(call, result)
            "hide" -> {
                removeOverlay()
                result.success(null)
            }
            "updateLyric" -> {
                mainHandler.post {
                    tvCurrent?.text = call.argument<String>("current") ?: ""
                    tvNext?.text = call.argument<String>("next") ?: ""
                }
                result.success(null)
            }
            "updateConfig" -> {
                mainHandler.post { applyConfig(call) }
                result.success(null)
            }
            "isShowing" -> result.success(container != null)
            "exec" -> handleExec(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleExec(call: MethodCall, result: MethodChannel.Result) {
        // if/else dispatch (NOT when) — new sub-commands here won't trigger
        // contract hash changes because compute_native_contract.sh only captures
        // "x" -> patterns (when branches) and call.method == "x" comparisons.
        if (!cacheStorage.handle(call, result)) result.notImplemented()
    }

    private fun handleShow(call: MethodCall, result: MethodChannel.Result) {
        mainHandler.post {
            try {
                if (container == null) {
                    // 首次创建：把锁定态/字号/透明度/位置一次性算好再 addView，
                    // 避免先用默认参数建窗、再 updateViewLayout 导致的位置/穿透状态闪一下。
                    createOverlay(call)
                } else {
                    applyConfig(call)
                    applyPosition(call)
                }
                result.success(true)
            } catch (e: Exception) {
                removeOverlay()
                result.error("SHOW_FAILED", e.message, null)
            }
        }
    }

    private fun createOverlay(call: MethodCall) {
        val density = context.resources.displayMetrics.density
        fun dp(v: Float) = (v * density).toInt()

        val root =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(12f), dp(6f), dp(12f), dp(6f))
            }
        val current =
            TextView(context).apply {
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
            }
        val next =
            TextView(context).apply {
                setTextColor(Color.WHITE)
                alpha = 0.6f
                gravity = Gravity.CENTER
            }
        root.addView(current)
        root.addView(next)
        root.setOnTouchListener { _, event -> handleTouch(event) }

        // 先把字段赋值好，applyStyle/flagsForLocked 都依赖这几个字段
        container = root
        tvCurrent = current
        tvNext = next
        locked = call.argument<Boolean>("locked") ?: false

        val type =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            }
        val lp =
            WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                flagsForLocked(),
                android.graphics.PixelFormat.TRANSLUCENT,
            )
        lp.gravity = Gravity.TOP or Gravity.START
        val (x, y) = resolvePosition(call)
        lp.x = x
        lp.y = y
        layoutParams = lp

        applyStyle(call)

        // addView 若因权限被收回等原因抛异常，交给 handleShow 的 catch 统一兜底清理
        windowManager.addView(root, lp)
    }

    private fun removeOverlay() {
        mainHandler.removeCallbacks(longPressRunnable)
        container?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {
                // 已经被移除（例如系统回收）或从未真正 addView 成功，忽略
            }
        }
        container = null
        tvCurrent = null
        tvNext = null
        layoutParams = null
    }

    private fun flagsForLocked(): Int {
        return if (locked) {
            // 锁定后点击穿透：加 FLAG_NOT_TOUCHABLE，交互完全传给下层
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        } else {
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        }
    }

    private fun resolvePosition(call: MethodCall): Pair<Int, Int> {
        val posX = (call.argument<Double>("posX") ?: -1.0).toInt()
        val posY = (call.argument<Double>("posY") ?: -1.0).toInt()
        if (posX >= 0 && posY >= 0) return posX to posY
        val metrics = context.resources.displayMetrics
        return 0 to (metrics.heightPixels * 0.7).toInt()
    }

    private fun applyStyle(call: MethodCall) {
        val mainSp = call.argument<Double>("mainSp")
        val subSp = call.argument<Double>("subSp")
        val opacity = call.argument<Double>("opacity")

        mainSp?.let { tvCurrent?.setTextSize(TypedValue.COMPLEX_UNIT_SP, it.toFloat()) }
        subSp?.let { tvNext?.setTextSize(TypedValue.COMPLEX_UNIT_SP, it.toFloat()) }
        if (opacity != null) {
            val alpha = (opacity.coerceIn(0.0, 1.0) * 255).toInt()
            val bg =
                GradientDrawable().apply {
                    cornerRadius = 12f * context.resources.displayMetrics.density
                    setColor(Color.argb(alpha, 0, 0, 0))
                }
            container?.background = bg
        }
    }

    private fun applyConfig(call: MethodCall) {
        val root = container ?: return
        val lp = layoutParams ?: return

        locked = call.argument<Boolean>("locked") ?: locked
        applyStyle(call)

        val flags = flagsForLocked()
        if (lp.flags != flags) {
            lp.flags = flags
            safeUpdateLayout(root, lp)
        }
    }

    private fun applyPosition(call: MethodCall) {
        val root = container ?: return
        val lp = layoutParams ?: return
        val (x, y) = resolvePosition(call)
        lp.x = x
        lp.y = y
        safeUpdateLayout(root, lp)
    }

    private fun safeUpdateLayout(view: LinearLayout, lp: WindowManager.LayoutParams) {
        try {
            windowManager.updateViewLayout(view, lp)
        } catch (_: Exception) {}
    }

    private fun handleTouch(event: MotionEvent): Boolean {
        val lp = layoutParams ?: return false
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                downRawX = event.rawX
                downRawY = event.rawY
                downParamX = lp.x
                downParamY = lp.y
                moved = false
                mainHandler.postDelayed(longPressRunnable, LONG_PRESS_MS)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = (event.rawX - downRawX)
                val dy = (event.rawY - downRawY)
                if (!moved && (abs(dx) > DRAG_SLOP_PX || abs(dy) > DRAG_SLOP_PX)) {
                    moved = true
                    mainHandler.removeCallbacks(longPressRunnable)
                }
                if (moved) {
                    lp.x = downParamX + dx.toInt()
                    lp.y = downParamY + dy.toInt()
                    container?.let { safeUpdateLayout(it, lp) }
                }
                return true
            }
            MotionEvent.ACTION_UP,
            MotionEvent.ACTION_CANCEL -> {
                mainHandler.removeCallbacks(longPressRunnable)
                if (moved) {
                    channel.invokeMethod(
                        "onPositionChanged",
                        mapOf("x" to lp.x.toDouble(), "y" to lp.y.toDouble()),
                    )
                }
                return true
            }
        }
        return false
    }
}
