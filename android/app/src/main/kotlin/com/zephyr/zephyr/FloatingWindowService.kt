package com.zephyr.zephyr

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.*
import android.widget.FrameLayout
import android.widget.ImageView
import android.graphics.Color
import android.widget.LinearLayout
import android.widget.TextView

/**
 * 悬浮窗服务 - 显示控制面板
 */
class FloatingWindowService : Service() {

    companion object {
        private const val TAG = "FloatingWindow"
        private const val CHANNEL_ID = "zephyr_floating"
        private const val NOTIFICATION_ID = 1

        var instance: FloatingWindowService? = null
            private set

        // 回调：当用户点击悬浮球时
        var onBallClick: (() -> Unit)? = null
        // 回调：当用户点击播放按钮时
        var onPlayClick: (() -> Unit)? = null
        // 回调：当用户点击暂停按钮时
        var onPauseClick: (() -> Unit)? = null
        // 回调：当用户点击停止按钮时
        var onStopClick: (() -> Unit)? = null

        @Volatile
        var isRunning = false
            private set
    }

    private var windowManager: WindowManager? = null
    private var floatingBall: View? = null
    private var controlPanel: View? = null
    private var isPanelShowing = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        isRunning = true
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        createFloatingBall()
        Log.i(TAG, "Floating window service created")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Zephyr 悬浮窗",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Zephyr 自动弹琴工具悬浮窗服务"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Zephyr 运行中")
                .setContentText("悬浮窗已启用")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Zephyr 运行中")
                .setContentText("悬浮窗已启用")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .build()
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createFloatingBall() {
        val ballSize = dpToPx(50)

        // 创建悬浮球容器
        val container = FrameLayout(this)

        // 创建悬浮球
        val ball = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_media_play)
            setBackgroundColor(Color.parseColor("#6C63FF"))
            scaleType = ImageView.ScaleType.CENTER
            setPadding(dpToPx(12), dpToPx(12), dpToPx(12), dpToPx(12))
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
                    val params = floatingBall?.layoutParams as? WindowManager.LayoutParams
                        ?: return@setOnTouchListener false
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
                    if (dx * dx + dy * dy > 100) {
                        isDragging = true
                    }
                    if (isDragging) {
                        val params = floatingBall?.layoutParams as? WindowManager.LayoutParams
                            ?: return@setOnTouchListener false
                        params.x = initialX + dx.toInt()
                        params.y = initialY + dy.toInt()
                        try {
                            windowManager?.updateViewLayout(floatingBall, params)
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating layout", e)
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        // 点击：显示/隐藏控制面板
                        toggleControlPanel()
                    } else {
                        // 松手贴边
                        snapToEdge()
                    }
                    true
                }
                else -> false
            }
        }

        floatingBall = container

        val params = WindowManager.LayoutParams(
            ballSize,
            ballSize,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSPARENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 200
        }

        try {
            windowManager?.addView(floatingBall, params)
        } catch (e: Exception) {
            Log.e(TAG, "Error adding floating ball", e)
        }
    }

    private fun toggleControlPanel() {
        if (isPanelShowing) {
            hideControlPanel()
        } else {
            showControlPanel()
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun showControlPanel() {
        if (controlPanel != null) return

        val panelWidth = dpToPx(200)
        val panelHeight = dpToPx(120)

        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#E61E1E1E"))
            setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))
        }

        // 标题
        val title = TextView(this).apply {
            text = "Zephyr 控制"
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
        }
        panel.addView(title)

        // 按钮容器
        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(12), 0, 0)
        }

        // 播放按钮
        val playBtn = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_media_play)
            setBackgroundColor(Color.parseColor("#4CAF50"))
            setPadding(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8))
            setOnClickListener {
                onPlayClick?.invoke()
            }
        }
        buttonRow.addView(playBtn, LinearLayout.LayoutParams(dpToPx(40), dpToPx(40)).apply {
            marginEnd = dpToPx(8)
        })

        // 暂停按钮
        val pauseBtn = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_media_pause)
            setBackgroundColor(Color.parseColor("#FF9800"))
            setPadding(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8))
            setOnClickListener {
                onPauseClick?.invoke()
            }
        }
        buttonRow.addView(pauseBtn, LinearLayout.LayoutParams(dpToPx(40), dpToPx(40)).apply {
            marginEnd = dpToPx(8)
        })

        // 停止按钮
        val stopBtn = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_delete)
            setBackgroundColor(Color.parseColor("#F44336"))
            setPadding(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8))
            setOnClickListener {
                onStopClick?.invoke()
            }
        }
        buttonRow.addView(stopBtn, LinearLayout.LayoutParams(dpToPx(40), dpToPx(40)))

        panel.addView(buttonRow)

        controlPanel = panel

        val params = WindowManager.LayoutParams(
            panelWidth,
            panelHeight,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSPARENT
        ).apply {
            gravity = Gravity.CENTER
        }

        try {
            windowManager?.addView(controlPanel, params)
            isPanelShowing = true
        } catch (e: Exception) {
            Log.e(TAG, "Error showing control panel", e)
        }
    }

    private fun hideControlPanel() {
        try {
            controlPanel?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Error hiding control panel", e)
        }
        controlPanel = null
        isPanelShowing = false
    }

    private fun snapToEdge() {
        val params = floatingBall?.layoutParams as? WindowManager.LayoutParams ?: return
        val screenWidth = resources.displayMetrics.widthPixels
        val midX = screenWidth / 2
        params.x = if (params.x < midX) 0 else screenWidth - dpToPx(50)
        try {
            windowManager?.updateViewLayout(floatingBall, params)
        } catch (e: Exception) {
            Log.w(TAG, "Error snapping to edge", e)
        }
    }

    /**
     * 更新悬浮球状态图标
     */
    fun updateBallIcon(isPlaying: Boolean) {
        val ball = (floatingBall as? FrameLayout)?.getChildAt(0) as? ImageView ?: return
        ball.setImageResource(
            if (isPlaying) android.R.drawable.ic_media_pause
            else android.R.drawable.ic_media_play
        )
    }

    override fun onDestroy() {
        isRunning = false
        hideControlPanel()
        try {
            floatingBall?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Error removing floating ball", e)
        }
        instance = null
        super.onDestroy()
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
