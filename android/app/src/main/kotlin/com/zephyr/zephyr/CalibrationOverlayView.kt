package com.zephyr.zephyr

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.util.Log
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View

/**
 * 校准覆盖层 - 两步校准流程
 *
 * 第一步：用户点击屏幕放置准心，然后拖动微调到「-1」琴键中心
 * 第二步：显示完整 3x5 网格，用滑条调整行/列间距
 */
@SuppressLint("ViewConstructor")
class CalibrationOverlayView(
    context: Context,
    private var baseX: Float,
    private var baseY: Float,
    private var colSpacing: Float,
    private var rowSpacing: Float
) : View(context) {

    var onConfirm: ((Float, Float, Float, Float) -> Unit)? = null
    var onCancel: (() -> Unit)? = null

    private val noteNames = arrayOf(
        arrayOf("-1", "-2", "-3", "-4", "-5"),
        arrayOf("-6", "-7", "1", "2", "3"),
        arrayOf("4", "5", "6", "7", "+1")
    )

    // 当前步骤
    private var step = 1

    // 第一步：准心是否已放置
    private var crosshairPlaced = false

    // 第一步确认后锁定的基准位置（视图坐标）
    private var lockedX = baseX
    private var lockedY = baseY

    // 视图在屏幕上的偏移量（用于转换为屏幕坐标）
    private val screenOffset = IntArray(2)

    /**
     * 将视图坐标转为屏幕坐标
     * event.x/y 是相对于视图左上角的，dispatchGesture 需要屏幕绝对坐标
     */
    private fun viewToScreenX(viewX: Float): Float {
        return viewX + screenOffset[0]
    }

    private fun viewToScreenY(viewY: Float): Float {
        return viewY + screenOffset[1]
    }

    // ===== 画笔 =====
    private val crosshairPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#FF5252")
        strokeWidth = 3f
        strokeCap = Paint.Cap.ROUND
    }
    private val crosshairCirclePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = Color.parseColor("#FF5252")
    }
    private val keyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.argb(200, 30, 30, 50)
    }
    private val keyBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 4f
        color = Color.parseColor("#6C63FF")
    }
    private val firstKeyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.argb(220, 255, 82, 82)
    }
    private val firstKeyBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 5f
        color = Color.parseColor("#FF5252")
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 32f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
        setShadowLayer(6f, 0f, 0f, Color.BLACK)
    }
    private val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 36f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    }
    private val hintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#BBBBBB")
        textSize = 24f
        textAlign = Paint.Align.CENTER
    }
    private val coordPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#FFEB3B")
        textSize = 22f
        textAlign = Paint.Align.LEFT
        typeface = Typeface.MONOSPACE
        setShadowLayer(4f, 0f, 0f, Color.BLACK)
    }
    private val panelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#E61A1A1A")
    }
    private val btnPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val btnTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 36f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    }
    private val labelTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 26f
        textAlign = Paint.Align.CENTER
    }
    private val dimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(120, 0, 0, 0)
    }

    // 滑条画笔
    private val sliderTrackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#555555")
        strokeWidth = 6f
        strokeCap = Paint.Cap.ROUND
    }
    private val sliderFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#6C63FF")
        strokeWidth = 6f
        strokeCap = Paint.Cap.ROUND
    }
    private val sliderThumbPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }
    private val sliderValuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 28f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    }

    // 拖拽状态
    private var isDragging = false
    private var lastTouchX = 0f
    private var lastTouchY = 0f

    // 双指缩放（仅第二步）
    private var scaleDetector: ScaleGestureDetector
    private var isScaling = false

    // 滑条状态
    private var isDraggingColSlider = false
    private var isDraggingRowSlider = false

    // 底部面板
    private val panelHeight = 320f
    private var panelTop = 0f

    // 按钮区域
    private var nextBtnRect = RectF()
    private var backBtnRect = RectF()
    private var confirmBtnRect = RectF()
    private var cancelBtnRect = RectF()

    // 滑条区域
    private var colSliderRect = RectF()
    private var rowSliderRect = RectF()

    // 滑条范围
    private val spacingMin = 40f
    private val spacingMax = 500f

    init {
        scaleDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                if (step != 2) return false
                val scaleFactor = detector.scaleFactor
                colSpacing = (colSpacing * scaleFactor).coerceIn(spacingMin, spacingMax)
                rowSpacing = (rowSpacing * scaleFactor).coerceIn(spacingMin, spacingMax)
                invalidate()
                return true
            }
            override fun onScaleBegin(detector: ScaleGestureDetector): Boolean {
                if (step == 2) { isScaling = true; return true }
                return false
            }
            override fun onScaleEnd(detector: ScaleGestureDetector) {
                isScaling = false
            }
        })
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        panelTop = h - panelHeight

        // 获取视图在屏幕上的绝对位置（关键：event.x 是视图坐标，dispatchGesture 需要屏幕坐标）
        getLocationOnScreen(screenOffset)

        if (step == 1) drawStep1(canvas, w, h)
        else drawStep2(canvas, w, h)
    }

    // ===== 第一步：点击放置准心，拖动微调 =====
    private fun drawStep1(canvas: Canvas, w: Float, h: Float) {
        canvas.drawRect(0f, 0f, w, h, dimPaint)

        // 顶部提示
        titlePaint.color = Color.WHITE
        if (!crosshairPlaced) {
            canvas.drawText("第一步：定位「-1」琴键", w / 2f, 60f, titlePaint)
            canvas.drawText("点击游戏中的「-1」琴键位置", w / 2f, 100f, hintPaint)
        } else {
            canvas.drawText("拖动准心精确对齐「-1」琴键中心", w / 2f, 60f, titlePaint)
        }

        // 只在准心已放置时绘制
        if (crosshairPlaced) {
            val cx = baseX
            val cy = baseY
            val crossLen = 40f
            val gap = 15f

            // 十字线
            crosshairPaint.strokeWidth = 3f
            canvas.drawLine(cx - crossLen, cy, cx - gap, cy, crosshairPaint)
            canvas.drawLine(cx + gap, cy, cx + crossLen, cy, crosshairPaint)
            canvas.drawLine(cx, cy - crossLen, cx, cy - gap, crosshairPaint)
            canvas.drawLine(cx, cy + gap, cx, cy + crossLen, crosshairPaint)

            // 外圈
            crosshairCirclePaint.color = Color.parseColor("#FF5252")
            crosshairCirclePaint.strokeWidth = 3f
            canvas.drawCircle(cx, cy, 30f, crosshairCirclePaint)
            crosshairCirclePaint.strokeWidth = 2f
            canvas.drawCircle(cx, cy, 60f, crosshairCirclePaint)

            // 中心点
            val centerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#FF5252")
                style = Paint.Style.FILL
            }
            canvas.drawCircle(cx, cy, 5f, centerPaint)

            // 音符标签
            titlePaint.color = Color.parseColor("#FF5252")
            canvas.drawText("-1", cx, cy - 70f, titlePaint)

            // 实时坐标显示（屏幕坐标 = 视图坐标 + 偏移）
            val screenX = viewToScreenX(cx).toInt()
            val screenY = viewToScreenY(cy).toInt()
            canvas.drawText("X: $screenX  (view:${cx.toInt()} + offset:${screenOffset[0]})", 20f, 160f, coordPaint)
            canvas.drawText("Y: $screenY  (view:${cy.toInt()} + offset:${screenOffset[1]})", 20f, 188f, coordPaint)
        }

        // 底部面板
        canvas.drawRect(0f, panelTop, w, h, panelPaint)

        val btnY = panelTop + panelHeight / 2f - 35f
        val btnWidth = (w - 80f) / 2

        cancelBtnRect.set(20f, btnY, 20f + btnWidth, btnY + 65f)
        nextBtnRect.set(w - 20f - btnWidth, btnY, w - 20f, btnY + 65f)

        btnPaint.color = Color.parseColor("#616161")
        canvas.drawRoundRect(cancelBtnRect, 14f, 14f, btnPaint)

        // 下一步按钮：准心已放置时才可点击
        btnPaint.color = if (crosshairPlaced) Color.parseColor("#388E3C") else Color.parseColor("#333333")
        canvas.drawRoundRect(nextBtnRect, 14f, 14f, btnPaint)

        canvas.drawText("取消", cancelBtnRect.centerX(), cancelBtnRect.centerY() + 12f, btnTextPaint)
        val nextColor = if (crosshairPlaced) Color.WHITE else Color.parseColor("#666666")
        btnTextPaint.color = nextColor
        canvas.drawText("下一步 ▸", nextBtnRect.centerX(), nextBtnRect.centerY() + 12f, btnTextPaint)
        btnTextPaint.color = Color.WHITE // 恢复
    }

    // ===== 第二步：滑条调整间距 =====
    private fun drawStep2(canvas: Canvas, w: Float, h: Float) {
        val dimPaint2 = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(80, 0, 0, 0)
        }
        canvas.drawRect(0f, 0f, w, h, dimPaint2)

        // 绘制 3x5 网格
        for (row in 0..2) {
            for (col in 0..4) {
                val x = lockedX + col * colSpacing
                val y = lockedY + row * rowSpacing
                val radius = 42f

                if (row == 0 && col == 0) {
                    canvas.drawCircle(x, y, radius + 4f, firstKeyPaint)
                    canvas.drawCircle(x, y, radius + 4f, firstKeyBorderPaint)
                }

                canvas.drawCircle(x, y, radius, keyPaint)
                canvas.drawCircle(x, y, radius, keyBorderPaint)
                canvas.drawText(noteNames[row][col], x, y + 10f, textPaint)
            }
        }

        // 连接线
        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(80, 108, 99, 255)
            strokeWidth = 2f
        }
        for (row in 0..2) {
            canvas.drawLine(lockedX, lockedY + row * rowSpacing,
                lockedX + 4 * colSpacing, lockedY + row * rowSpacing, linePaint)
        }
        for (col in 0..4) {
            canvas.drawLine(lockedX + col * colSpacing, lockedY,
                lockedX + col * colSpacing, lockedY + 2 * rowSpacing, linePaint)
        }

        // 顶部提示
        titlePaint.color = Color.WHITE
        canvas.drawText("第二步：调整琴键间距", w / 2f, 60f, titlePaint)
        canvas.drawText("拖动滑条或双指缩放调整间距", w / 2f, 100f, hintPaint)

        // 坐标显示（屏幕坐标）
        val screenLX = viewToScreenX(lockedX).toInt()
        val screenLY = viewToScreenY(lockedY).toInt()
        canvas.drawText("-1: screen($screenLX, $screenLY)  offset(${screenOffset[0]}, ${screenOffset[1]})", 20f, 140f, coordPaint)

        // ===== 底部控制面板 =====
        canvas.drawRect(0f, panelTop, w, h, panelPaint)

        val padding = 40f
        val sliderLeft = padding + 80f
        val sliderRight = w - padding - 80f
        val sliderW = sliderRight - sliderLeft

        // 列间距滑条
        val colY = panelTop + 45f
        canvas.drawText("列间距", padding + 30f, colY + 6f, labelTextPaint)
        canvas.drawText("${colSpacing.toInt()}", sliderRight + 45f, colY + 6f, sliderValuePaint)

        colSliderRect.set(sliderLeft, colY - 3f, sliderRight, colY + 3f)
        drawSlider(canvas, sliderLeft, sliderRight, colY, colSpacing, spacingMin, spacingMax)

        // 行间距滑条
        val rowY = panelTop + 120f
        canvas.drawText("行间距", padding + 30f, rowY + 6f, labelTextPaint)
        canvas.drawText("${rowSpacing.toInt()}", sliderRight + 45f, rowY + 6f, sliderValuePaint)

        rowSliderRect.set(sliderLeft, rowY - 3f, sliderRight, rowY + 3f)
        drawSlider(canvas, sliderLeft, sliderRight, rowY, rowSpacing, spacingMin, spacingMax)

        // 底部按钮
        val btnY2 = panelTop + panelHeight - 85f
        val btnWidth = (w - 80f) / 2

        backBtnRect.set(20f, btnY2, 20f + btnWidth, btnY2 + 65f)
        confirmBtnRect.set(w - 20f - btnWidth, btnY2, w - 20f, btnY2 + 65f)

        btnPaint.color = Color.parseColor("#616161")
        canvas.drawRoundRect(backBtnRect, 14f, 14f, btnPaint)
        btnPaint.color = Color.parseColor("#388E3C")
        canvas.drawRoundRect(confirmBtnRect, 14f, 14f, btnPaint)

        canvas.drawText("◂ 返回", backBtnRect.centerX(), backBtnRect.centerY() + 12f, btnTextPaint)
        canvas.drawText("确认", confirmBtnRect.centerX(), confirmBtnRect.centerY() + 12f, btnTextPaint)
    }

    private fun drawSlider(canvas: Canvas, left: Float, right: Float, y: Float,
                            value: Float, min: Float, max: Float) {
        val ratio = (value - min) / (max - min)
        val thumbX = left + ratio * (right - left)

        // 轨道背景
        canvas.drawLine(left, y, right, y, sliderTrackPaint)
        // 已填充部分
        canvas.drawLine(left, y, thumbX, y, sliderFillPaint)
        // 滑块
        canvas.drawCircle(thumbX, y, 16f, sliderThumbPaint)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        scaleDetector.onTouchEvent(event)
        if (isScaling) return true

        val x = event.x
        val y = event.y

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                // 底部面板区域
                if (y >= panelTop) {
                    handlePanelTouchDown(x, y)
                    return true
                }

                if (step == 1) {
                    // 第一步：点击放置准心 或 开始拖动已放置的准心
                    if (!crosshairPlaced) {
                        // 点击放置
                        baseX = x
                        baseY = y
                        crosshairPlaced = true
                        invalidate()
                    } else {
                        // 开始拖动
                        isDragging = true
                        lastTouchX = x
                        lastTouchY = y
                    }
                    return true
                }
            }

            MotionEvent.ACTION_MOVE -> {
                // 滑条拖动
                if (isDraggingColSlider) {
                    val sliderLeft = 40f + 80f
                    val sliderRight = width.toFloat() - 40f - 80f
                    val ratio = ((x - sliderLeft) / (sliderRight - sliderLeft)).coerceIn(0f, 1f)
                    colSpacing = spacingMin + ratio * (spacingMax - spacingMin)
                    invalidate()
                    return true
                }
                if (isDraggingRowSlider) {
                    val sliderLeft = 40f + 80f
                    val sliderRight = width.toFloat() - 40f - 80f
                    val ratio = ((x - sliderLeft) / (sliderRight - sliderLeft)).coerceIn(0f, 1f)
                    rowSpacing = spacingMin + ratio * (spacingMax - spacingMin)
                    invalidate()
                    return true
                }

                // 第一步准心拖动
                if (isDragging && step == 1 && event.pointerCount == 1) {
                    baseX += event.x - lastTouchX
                    baseY += event.y - lastTouchY
                    lastTouchX = event.x
                    lastTouchY = event.y
                    invalidate()
                    return true
                }
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                isDragging = false
                isDraggingColSlider = false
                isDraggingRowSlider = false
            }
        }
        return true
    }

    private fun handlePanelTouchDown(x: Float, y: Float) {
        if (step == 1) {
            when {
                cancelBtnRect.contains(x, y) -> onCancel?.invoke()
                nextBtnRect.contains(x, y) && crosshairPlaced -> {
                    lockedX = baseX
                    lockedY = baseY
                    Log.d("Calibration", "Step1→Step2: viewX=$baseX, viewY=$baseY, " +
                        "screenX=${viewToScreenX(baseX)}, screenY=${viewToScreenY(baseY)}, " +
                        "offset=(${screenOffset[0]}, ${screenOffset[1]})")
                    step = 2
                    invalidate()
                }
            }
        } else {
            // 滑条触摸检测（滑条上下各 30px 的范围）
            val sliderLeft = 40f + 80f
            val sliderRight = width.toFloat() - 40f - 80f

            val colY = panelTop + 45f
            val rowY = panelTop + 120f

            when {
                // 列间距滑条
                y in (colY - 30f)..(colY + 30f) && x in sliderLeft..sliderRight -> {
                    isDraggingColSlider = true
                    val ratio = ((x - sliderLeft) / (sliderRight - sliderLeft)).coerceIn(0f, 1f)
                    colSpacing = spacingMin + ratio * (spacingMax - spacingMin)
                    invalidate()
                }
                // 行间距滑条
                y in (rowY - 30f)..(rowY + 30f) && x in sliderLeft..sliderRight -> {
                    isDraggingRowSlider = true
                    val ratio = ((x - sliderLeft) / (sliderRight - sliderLeft)).coerceIn(0f, 1f)
                    rowSpacing = spacingMin + ratio * (spacingMax - spacingMin)
                    invalidate()
                }
                backBtnRect.contains(x, y) -> {
                    step = 1
                    invalidate()
                }
                confirmBtnRect.contains(x, y) -> {
                    // 转换为屏幕坐标后回调
                    val screenX = viewToScreenX(lockedX)
                    val screenY = viewToScreenY(lockedY)
                    Log.d("Calibration", "Confirm: viewX=$lockedX, viewY=$lockedY, " +
                        "screenX=$screenX, screenY=$screenY, " +
                        "offset=(${screenOffset[0]}, ${screenOffset[1]})")
                    onConfirm?.invoke(screenX, screenY, colSpacing, rowSpacing)
                }
            }
        }
    }
}
