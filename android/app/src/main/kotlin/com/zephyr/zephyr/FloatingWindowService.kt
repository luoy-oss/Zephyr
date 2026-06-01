package com.zephyr.zephyr

import android.annotation.SuppressLint
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.*
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * 悬浮窗服务 - 显示控制面板
 */
class FloatingWindowService : Service() {

    companion object {
        private const val TAG = "FloatingWindow"
        private const val CHANNEL = "com.zephyr.zephyr/floating"
        private const val TAP_CHANNEL = "com.zephyr.zephyr/tap"

        var instance: FloatingWindowService? = null
            private set

        @Volatile
        var methodChannel: MethodChannel? = null
            private set

        @Volatile
        var tapMethodChannel: MethodChannel? = null
            private set
    }

    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var flutterEngine: FlutterEngine? = null

    override fun onBind(intent: Intent?): IBinder? = null

    @SuppressLint("ClickableViewAccessibility")
    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createFloatingWindow()
        Log.i(TAG, "Floating window service created")
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createFloatingWindow() {
        // 创建一个简单的悬浮球视图
        val ballSize = dpToPx(48)
        val container = FrameLayout(this).apply {
            setBackgroundColor(0x00000000) // 透明背景
        }

        // 创建悬浮球
        val ball = View(this).apply {
            setBackgroundResource(android.R.drawable.ic_media_play)
            setBackgroundColor(0xFF6C63FF.toInt())
        }

        val ballParams = FrameLayout.LayoutParams(ballSize, ballSize).apply {
            gravity = Gravity.CENTER
        }
        container.addView(ball, ballParams)

        // 拖拽和点击逻辑
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false

        container.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    val params = floatingView?.layoutParams as? WindowManager.LayoutParams ?: return@setOnTouchListener false
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    if (dx * dx + dy * dy > 25) { // 超过5px认为是拖拽
                        isDragging = true
                    }
                    if (isDragging) {
                        val params = floatingView?.layoutParams as? WindowManager.LayoutParams ?: return@setOnTouchListener false
                        params.x = initialX + dx.toInt()
                        params.y = initialY + dy.toInt()
                        windowManager?.updateViewLayout(floatingView, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        // 点击事件 - 发送到Flutter
                        methodChannel?.invokeMethod("onBallClick", null)
                    } else {
                        // 松手时贴边
                        snapToEdge()
                    }
                    true
                }
                else -> false
            }
        }

        floatingView = container

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSPARENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 200
        }

        windowManager?.addView(floatingView, params)
    }

    /**
     * 贴边处理
     */
    private fun snapToEdge() {
        val params = floatingView?.layoutParams as? WindowManager.LayoutParams ?: return
        val screenWidth = resources.displayMetrics.widthPixels
        val midX = screenWidth / 2
        // 贴到最近的边
        params.x = if (params.x < midX) -dpToPx(24) else screenWidth - dpToPx(24)
        windowManager?.updateViewLayout(floatingView, params)
    }

    /**
     * 发送点击事件到Flutter（模拟屏幕点击）
     */
    fun performTap(x: Float, y: Float, durationMs: Long) {
        val service = PianoAccessibilityService.instance
        if (service != null) {
            service.performTap(x, y, durationMs)
        } else {
            Log.w(TAG, "Accessibility service not available")
        }
    }

    fun performMultiTap(points: List<Pair<Float, Float>>, durationMs: Long) {
        val service = PianoAccessibilityService.instance
        if (service != null) {
            service.performMultiTap(points, durationMs)
        }
    }

    override fun onDestroy() {
        try {
            windowManager?.removeView(floatingView)
        } catch (e: Exception) {
            Log.w(TAG, "Error removing floating view", e)
        }
        instance = null
        methodChannel = null
        tapMethodChannel = null
        super.onDestroy()
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
