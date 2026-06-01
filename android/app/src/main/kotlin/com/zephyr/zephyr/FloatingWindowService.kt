package com.zephyr.zephyr

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.*
import android.widget.*

/**
 * 悬浮窗服务 - 完整控制面板
 */
class FloatingWindowService : Service() {

    companion object {
        private const val TAG = "FloatingWindow"
        private const val CHANNEL_ID = "zephyr_floating"
        private const val NOTIFICATION_ID = 1

        var instance: FloatingWindowService? = null
            private set

        @Volatile
        var isRunning = false
            private set

        // Flutter 通信回调
        var onPlay: (() -> Unit)? = null
        var onPause: (() -> Unit)? = null
        var onStop: (() -> Unit)? = null
        var onSelectScore: ((String) -> Unit)? = null
        var onCalibrationChanged: ((Float, Float, Float, Float) -> Unit)? = null
    }

    private var windowManager: WindowManager? = null
    private var floatingBall: View? = null
    private var mainPanel: View? = null
    private var calibrationView: CalibrationOverlayView? = null

    private var isBallShowing = false
    private var isMainPanelShowing = false
    private var isCalibrating = false

    // 当前状态
    private var currentSpeed = 1.0f
    private var selectedScoreName = "未选择"
    private var isPlaying = false

    // 校准参数
    private var baseX = 200f
    private var baseY = 500f
    private var colSpacing = 150f
    private var rowSpacing = 120f

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        isRunning = true
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        showFloatingBall()
        Log.i(TAG, "Floating window service created")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Zephyr 悬浮窗", NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Zephyr 自动弹琴工具" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        return builder
            .setContentTitle("Zephyr 运行中")
            .setContentText("点击悬浮球打开控制面板")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .build()
    }

    // ========== 悬浮球 ==========

    @SuppressLint("ClickableViewAccessibility")
    private fun showFloatingBall() {
        if (isBallShowing) return

        val size = dpToPx(50)
        val ball = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_media_play)
            setBackgroundColor(Color.parseColor("#6C63FF"))
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setPadding(dpToPx(14), dpToPx(14), dpToPx(14), dpToPx(14))
        }

        var lastX = 0f
        var lastY = 0f
        var isDragging = false

        ball.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    lastX = event.rawX
                    lastY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - lastX
                    val dy = event.rawY - lastY
                    if (!isDragging && dx * dx + dy * dy > 100) isDragging = true
                    if (isDragging) {
                        val params = floatingBall?.layoutParams as? WindowManager.LayoutParams
                            ?: return@setOnTouchListener true
                        params.x += dx.toInt()
                        params.y += dy.toInt()
                        windowManager?.updateViewLayout(floatingBall, params)
                        lastX = event.rawX
                        lastY = event.rawY
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) showMainPanel()
                    else snapToEdge()
                    true
                }
                else -> false
            }
        }

        floatingBall = ball
        val params = WindowManager.LayoutParams(
            size, size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSPARENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 300
        }

        windowManager?.addView(floatingBall, params)
        isBallShowing = true
    }

    private fun hideFloatingBall() {
        try { floatingBall?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        floatingBall = null
        isBallShowing = false
    }

    private fun snapToEdge() {
        val params = floatingBall?.layoutParams as? WindowManager.LayoutParams ?: return
        val screenW = resources.displayMetrics.widthPixels
        params.x = if (params.x < screenW / 2) 0 else screenW - dpToPx(50)
        windowManager?.updateViewLayout(floatingBall, params)
    }

    // ========== 主控制面板 ==========

    @SuppressLint("ClickableViewAccessibility")
    private fun showMainPanel() {
        if (isMainPanelShowing) return
        hideFloatingBall()

        val panelW = dpToPx(280)
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#F01E1E1E"))
            setPadding(dpToPx(20), dpToPx(16), dpToPx(20), dpToPx(16))
        }

        // 标题栏
        val titleBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val title = TextView(this).apply {
            text = "Zephyr 控制面板"
            setTextColor(Color.WHITE)
            textSize = 16f
            setTypeface(null, Typeface.BOLD)
        }
        titleBar.addView(title, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

        // 关闭按钮
        val closeBtn = TextView(this).apply {
            text = "✕"
            setTextColor(Color.WHITE)
            textSize = 18f
            setPadding(dpToPx(8), dpToPx(4), dpToPx(8), dpToPx(4))
            setOnClickListener { hideMainPanel(); showFloatingBall() }
        }
        titleBar.addView(closeBtn)
        panel.addView(titleBar, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        panel.addView(createDivider())

        // 当前曲目
        val scoreRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dpToPx(8), 0, dpToPx(8))
        }
        val scoreIcon = TextView(this).apply {
            text = "🎵"
            textSize = 16f
        }
        scoreRow.addView(scoreIcon)
        val scoreName = TextView(this).apply {
            text = selectedScoreName
            setTextColor(Color.parseColor("#BBBBBB"))
            textSize = 13f
            setPadding(dpToPx(8), 0, 0, 0)
            tag = "scoreName"
        }
        scoreRow.addView(scoreName, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        val selectBtn = TextView(this).apply {
            text = "选择 ▸"
            setTextColor(Color.parseColor("#6C63FF"))
            textSize = 13f
            setOnClickListener { showScoreSelector() }
        }
        scoreRow.addView(selectBtn)
        panel.addView(scoreRow)

        panel.addView(createDivider())

        // 播放控制
        val controlRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(12), 0, dpToPx(12))
        }

        val playBtn = createCircleButton("▶", "#4CAF50") {
            Log.d(TAG, "Play button clicked")
            onPlay?.invoke()
            updatePlayState(true)
        }
        controlRow.addView(playBtn, LinearLayout.LayoutParams(dpToPx(52), dpToPx(52)).apply { marginEnd = dpToPx(12) })

        val pauseBtn = createCircleButton("⏸", "#FF9800") {
            Log.d(TAG, "Pause button clicked")
            onPause?.invoke()
            updatePlayState(false)
        }
        controlRow.addView(pauseBtn, LinearLayout.LayoutParams(dpToPx(52), dpToPx(52)).apply { marginEnd = dpToPx(12) })

        val stopBtn = createCircleButton("⏹", "#F44336") {
            Log.d(TAG, "Stop button clicked")
            onStop?.invoke()
            updatePlayState(false)
        }
        controlRow.addView(stopBtn, LinearLayout.LayoutParams(dpToPx(52), dpToPx(52)))
        panel.addView(controlRow)

        panel.addView(createDivider())

        // 速度控制
        val speedLabel = TextView(this).apply {
            text = "速度: ${String.format("%.2f", currentSpeed)}x"
            setTextColor(Color.WHITE)
            textSize = 13f
            tag = "speedLabel"
        }
        panel.addView(speedLabel)

        val speedBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dpToPx(4), 0, dpToPx(8))
        }
        val speedMinus = createSmallButton("−") {
            currentSpeed = (currentSpeed - 0.25f).coerceAtLeast(0.25f)
            speedLabel.text = "速度: ${String.format("%.2f", currentSpeed)}x"
        }
        speedBar.addView(speedMinus)

        val speedSlider = SeekBar(this).apply {
            max = 11
            progress = ((currentSpeed - 0.25f) / 0.25f).toInt()
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                    currentSpeed = 0.25f + progress * 0.25f
                    speedLabel.text = "速度: ${String.format("%.2f", currentSpeed)}x"
                }
                override fun onStartTrackingTouch(sb: SeekBar?) {}
                override fun onStopTrackingTouch(sb: SeekBar?) {}
            })
        }
        speedBar.addView(speedSlider, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginStart = dpToPx(8)
            marginEnd = dpToPx(8)
        })

        val speedPlus = createSmallButton("+") {
            currentSpeed = (currentSpeed + 0.25f).coerceAtMost(3.0f)
            speedLabel.text = "速度: ${String.format("%.2f", currentSpeed)}x"
        }
        speedBar.addView(speedPlus)
        panel.addView(speedBar)

        panel.addView(createDivider())

        // 校准按钮
        val calibrateBtn = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val bg = GradientDrawable()
            bg.setColor(Color.parseColor("#2A2A2A"))
            bg.cornerRadius = dpToPx(8).toFloat()
            background = bg
            setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))
            setOnClickListener { startCalibrationMode() }
        }
        val calIcon = TextView(this).apply { text = "🎯"; textSize = 16f }
        calibrateBtn.addView(calIcon)
        val calText = TextView(this).apply {
            text = "  校准琴键位置"
            setTextColor(Color.WHITE)
            textSize = 14f
        }
        calibrateBtn.addView(calText)
        val calArrow = TextView(this).apply {
            text = "▸"
            setTextColor(Color.parseColor("#6C63FF"))
            textSize = 14f
        }
        calibrateBtn.addView(calArrow, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
            gravity = Gravity.END
        })
        panel.addView(calibrateBtn, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dpToPx(8) })

        mainPanel = panel

        // 创建窗口参数 - 注意：不设置 FLAG_NOT_FOCUSABLE 以允许点击
        val params = WindowManager.LayoutParams(
            panelW, LinearLayout.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSPARENT
        ).apply {
            gravity = Gravity.CENTER
        }

        // 标题栏可拖拽
        var dragStartX = 0f
        var dragStartY = 0f
        var paramStartX = 0
        var paramStartY = 0
        titleBar.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    dragStartX = event.rawX
                    dragStartY = event.rawY
                    paramStartX = params.x
                    paramStartY = params.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = paramStartX + (event.rawX - dragStartX).toInt()
                    params.y = paramStartY + (event.rawY - dragStartY).toInt()
                    windowManager?.updateViewLayout(mainPanel, params)
                    true
                }
                else -> false
            }
        }

        windowManager?.addView(mainPanel, params)
        isMainPanelShowing = true
    }

    private fun hideMainPanel() {
        try { mainPanel?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        mainPanel = null
        isMainPanelShowing = false
    }

    private fun updatePlayState(playing: Boolean) {
        isPlaying = playing
        floatingBall?.let { ball ->
            (ball as? ImageView)?.setImageResource(
                if (playing) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play
            )
        }
    }

    // ========== 曲目选择器 ==========

    private var scoreList: List<Pair<String, String>> = emptyList()

    fun updateScoreList(scores: List<Pair<String, String>>) {
        scoreList = scores
    }

    private fun showScoreSelector() {
        hideMainPanel()

        val panelW = dpToPx(260)
        val panelH = dpToPx(400)
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#F01E1E1E"))
            setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))
        }

        // 标题
        val titleBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val backBtn = TextView(this).apply {
            text = "◂ 返回"
            setTextColor(Color.parseColor("#6C63FF"))
            textSize = 14f
            setOnClickListener { hideScoreSelector(); showMainPanel() }
        }
        titleBar.addView(backBtn)
        val title = TextView(this).apply {
            text = "  选择曲目"
            setTextColor(Color.WHITE)
            textSize = 16f
            setTypeface(null, Typeface.BOLD)
        }
        titleBar.addView(title, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        panel.addView(titleBar)

        panel.addView(createDivider())

        // 曲目列表
        val scrollView = ScrollView(this)
        val listLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        if (scoreList.isEmpty()) {
            val emptyText = TextView(this).apply {
                text = "暂无曲目\n请在应用中导入琴谱"
                setTextColor(Color.parseColor("#888888"))
                textSize = 14f
                gravity = Gravity.CENTER
                setPadding(0, dpToPx(40), 0, 0)
            }
            listLayout.addView(emptyText)
        } else {
            for ((id, name) in scoreList) {
                val item = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(dpToPx(12), dpToPx(12), dpToPx(12), dpToPx(12))
                    val bg = GradientDrawable()
                    bg.setColor(Color.parseColor("#2A2A2A"))
                    bg.cornerRadius = dpToPx(6).toFloat()
                    background = bg
                    setOnClickListener {
                        selectedScoreName = name
                        onSelectScore?.invoke(id)
                        hideScoreSelector()
                        showMainPanel()
                    }
                }
                val icon = TextView(this).apply { text = "🎵"; textSize = 14f }
                item.addView(icon)
                val nameText = TextView(this).apply {
                    text = "  $name"
                    setTextColor(Color.WHITE)
                    textSize = 14f
                }
                item.addView(nameText, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

                listLayout.addView(item, LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = dpToPx(4) })
            }
        }

        scrollView.addView(listLayout)
        panel.addView(scrollView, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
        ))

        val params = WindowManager.LayoutParams(
            panelW, panelH,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSPARENT
        ).apply { gravity = Gravity.CENTER }

        mainPanel = panel
        windowManager?.addView(mainPanel, params)
    }

    private fun hideScoreSelector() {
        try { mainPanel?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        mainPanel = null
    }

    // ========== 校准模式 ==========

    private fun startCalibrationMode() {
        hideMainPanel()

        calibrationView = CalibrationOverlayView(this, baseX, baseY, colSpacing, rowSpacing).apply {
            onConfirm = { bx, by, cs, rs ->
                baseX = bx
                baseY = by
                colSpacing = cs
                rowSpacing = rs
                onCalibrationChanged?.invoke(bx, by, cs, rs)
                stopCalibrationMode()
                showMainPanel()
            }
            onCancel = {
                stopCalibrationMode()
                showMainPanel()
            }
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSPARENT
        )

        windowManager?.addView(calibrationView, params)
        isCalibrating = true
    }

    private fun stopCalibrationMode() {
        try { calibrationView?.let { windowManager?.removeView(it) } } catch (_: Exception) {}
        calibrationView = null
        isCalibrating = false
    }

    // ========== 状态更新 ==========

    fun updateSelectedScore(name: String) {
        selectedScoreName = name
        mainPanel?.findViewWithTag<TextView>("scoreName")?.text = name
    }

    fun updateConfig(bx: Float, by: Float, cs: Float, rs: Float) {
        baseX = bx
        baseY = by
        colSpacing = cs
        rowSpacing = rs
    }

    // ========== 辅助方法 ==========

    private fun createDivider(): View {
        return View(this).apply {
            setBackgroundColor(Color.parseColor("#333333"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dpToPx(1)
            ).apply { topMargin = dpToPx(8); bottomMargin = dpToPx(8) }
        }
    }

    private fun createCircleButton(text: String, color: String, onClick: () -> Unit): FrameLayout {
        val container = FrameLayout(this)

        // 圆形背景
        val bg = GradientDrawable()
        bg.setColor(Color.parseColor(color))
        bg.cornerRadius = dpToPx(26).toFloat()
        container.background = bg

        // 文字
        val textView = TextView(this).apply {
            this.text = text
            setTextColor(Color.WHITE)
            textSize = 20f
            gravity = Gravity.CENTER
        }
        container.addView(textView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        // 点击效果
        container.isClickable = true
        container.isFocusable = true
        container.setOnClickListener {
            Log.d(TAG, "Button clicked: $text")
            onClick()
        }

        // 添加按压效果
        container.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    v.alpha = 0.7f
                    false
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.alpha = 1.0f
                    false
                }
                else -> false
            }
        }

        return container
    }

    private fun createSmallButton(text: String, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            this.text = text
            setTextColor(Color.WHITE)
            textSize = 16f
            gravity = Gravity.CENTER
            val bg = GradientDrawable()
            bg.setColor(Color.parseColor("#3A3A3A"))
            bg.cornerRadius = dpToPx(4).toFloat()
            background = bg
            setPadding(dpToPx(12), dpToPx(4), dpToPx(12), dpToPx(4))
            setOnClickListener { onClick() }
        }
    }

    override fun onDestroy() {
        isRunning = false
        stopCalibrationMode()
        hideMainPanel()
        hideFloatingBall()
        instance = null
        super.onDestroy()
    }

    private fun dpToPx(dp: Int): Int = (dp * resources.displayMetrics.density).toInt()
}
