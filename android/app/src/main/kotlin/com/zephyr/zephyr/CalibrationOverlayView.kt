package com.zephyr.zephyr

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View

/**
 * 校准覆盖层 - 两步校准流程
 *
 * 第一步：用户拖动十字准心定位第一个琴键（-1）的位置
 * 第二步：显示完整 3x5 网格，用户微调行/列间距
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

    // 当前步骤：1 = 定位第一个琴键，2 = 调整间距
    private var step = 1

    // 第一步确认后锁定的基准位置
    private var lockedX = baseX
    private var lockedY = baseY

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
    private val smallHintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#888888")
        textSize = 20f
        textAlign = Paint.Align.CENTER
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

    // 拖拽状态
    private var isDragging = false
    private var lastTouchX = 0f
    private var lastTouchY = 0f

    // 双指缩放（仅第二步）
    private var scaleDetector: ScaleGestureDetector
    private var isScaling = false

    // 底部面板
    private val panelHeight = 280f
    private var panelTop = 0f

    // 按钮区域
    private var colMinusRect = RectF()
    private var colPlusRect = RectF()
    private var rowMinusRect = RectF()
    private var rowPlusRect = RectF()
    private var nextBtnRect = RectF()
    private var backBtnRect = RectF()
    private var confirmBtnRect = RectF()
    private var cancelBtnRect = RectF()

    init {
        scaleDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                if (step != 2) return false
                val scaleFactor = detector.scaleFactor
                colSpacing = (colSpacing * scaleFactor).coerceIn(40f, 500f)
                rowSpacing = (rowSpacing * scaleFactor).coerceIn(40f, 500f)
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

        if (step == 1) {
            drawStep1(canvas, w, h)
        } else {
            drawStep2(canvas, w, h)
        }
    }

    // ===== 第一步：定位第一个琴键 =====
    private fun drawStep1(canvas: Canvas, w: Float, h: Float) {
        // 半透明遮罩（突出准心位置）
        canvas.drawRect(0f, 0f, w, h, dimPaint)

        // 十字准心
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
        canvas.drawCircle(cx, cy, 30f, crosshairCirclePaint)
        canvas.drawCircle(cx, cy, 60f, crosshairCirclePaint.apply { strokeWidth = 2f })

        // 中心点
        val centerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#FF5252")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(cx, cy, 5f, centerPaint)

        // 标签
        titlePaint.color = Color.parseColor("#FF5252")
        canvas.drawText("-1", cx, cy - 70f, titlePaint)

        // 顶部提示
        canvas.drawText("第一步：定位第一个琴键", w / 2f, 60f, titlePaint.apply { color = Color.WHITE })
        canvas.drawText("拖动红色准心到游戏中的「-1」琴键中心", w / 2f, 100f, hintPaint)
        canvas.drawText("这是所有琴键的基准位置，务必精确对齐", w / 2f, 135f, smallHintPaint)

        // 底部面板（只有下一步和取消）
        canvas.drawRect(0f, panelTop, w, h, panelPaint)

        val btnY = panelTop + panelHeight / 2f - 35f
        val btnWidth = (w - 80f) / 2

        cancelBtnRect.set(20f, btnY, 20f + btnWidth, btnY + 65f)
        nextBtnRect.set(w - 20f - btnWidth, btnY, w - 20f, btnY + 65f)

        btnPaint.color = Color.parseColor("#616161")
        canvas.drawRoundRect(cancelBtnRect, 14f, 14f, btnPaint)
        btnPaint.color = Color.parseColor("#388E3C")
        canvas.drawRoundRect(nextBtnRect, 14f, 14f, btnPaint)

        canvas.drawText("取消", cancelBtnRect.centerX(), cancelBtnRect.centerY() + 12f, btnTextPaint)
        canvas.drawText("下一步 ▸", nextBtnRect.centerX(), nextBtnRect.centerY() + 12f, btnTextPaint)
    }

    // ===== 第二步：调整琴键间距 =====
    private fun drawStep2(canvas: Canvas, w: Float, h: Float) {
        // 半透明遮罩（比第一步轻，但保证琴键可见）
        val dimPaint2 = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(80, 0, 0, 0)
        }
        canvas.drawRect(0f, 0f, w, h, dimPaint2)

        // 绘制完整 3x5 网格
        for (row in 0..2) {
            for (col in 0..4) {
                val x = lockedX + col * colSpacing
                val y = lockedY + row * rowSpacing
                val radius = 42f

                // 第一个琴键用红色高亮
                if (row == 0 && col == 0) {
                    canvas.drawCircle(x, y, radius + 4f, firstKeyPaint)
                    canvas.drawCircle(x, y, radius + 4f, firstKeyBorderPaint)
                }

                canvas.drawCircle(x, y, radius, keyPaint)
                canvas.drawCircle(x, y, radius, keyBorderPaint)
                canvas.drawText(noteNames[row][col], x, y + 10f, textPaint)
            }
        }

        // 连接线（帮助对齐视觉）
        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(80, 108, 99, 255)
            strokeWidth = 2f
        }
        for (row in 0..2) {
            canvas.drawLine(
                lockedX, lockedY + row * rowSpacing,
                lockedX + 4 * colSpacing, lockedY + row * rowSpacing,
                linePaint
            )
        }
        for (col in 0..4) {
            canvas.drawLine(
                lockedX + col * colSpacing, lockedY,
                lockedX + col * colSpacing, lockedY + 2 * rowSpacing,
                linePaint
            )
        }

        // 顶部提示
        canvas.drawText("第二步：调整琴键间距", w / 2f, 60f, titlePaint.apply { color = Color.WHITE })
        canvas.drawText("使用下方按钮或双指缩放调整行/列间距", w / 2f, 100f, hintPaint)
        canvas.drawText("红色「-1」锁定在第一步定位的位置，不可拖动", w / 2f, 135f, smallHintPaint)

        // ===== 底部控制面板 =====
        canvas.drawRect(0f, panelTop, w, h, panelPaint)

        val panelCenterY = panelTop + 40f

        // 列间距控制
        val colLabelX = w * 0.25f
        canvas.drawText("列间距", colLabelX, panelCenterY, labelTextPaint)
        canvas.drawText("${colSpacing.toInt()}", colLabelX, panelCenterY + 35f, btnTextPaint)

        val btnW = 70f
        val btnH = 55f
        val btnY1 = panelCenterY + 50f

        colMinusRect.set(colLabelX - 85f, btnY1, colLabelX - 15f, btnY1 + btnH)
        colPlusRect.set(colLabelX + 15f, btnY1, colLabelX + 85f, btnY1 + btnH)

        btnPaint.color = Color.parseColor("#444444")
        canvas.drawRoundRect(colMinusRect, 10f, 10f, btnPaint)
        canvas.drawRoundRect(colPlusRect, 10f, 10f, btnPaint)
        canvas.drawText("−", colMinusRect.centerX(), colMinusRect.centerY() + 12f, btnTextPaint)
        canvas.drawText("+", colPlusRect.centerX(), colPlusRect.centerY() + 12f, btnTextPaint)

        // 行间距控制
        val rowLabelX = w * 0.75f
        canvas.drawText("行间距", rowLabelX, panelCenterY, labelTextPaint)
        canvas.drawText("${rowSpacing.toInt()}", rowLabelX, panelCenterY + 35f, btnTextPaint)

        rowMinusRect.set(rowLabelX - 85f, btnY1, rowLabelX - 15f, btnY1 + btnH)
        rowPlusRect.set(rowLabelX + 15f, btnY1, rowLabelX + 85f, btnY1 + btnH)

        canvas.drawRoundRect(rowMinusRect, 10f, 10f, btnPaint)
        canvas.drawRoundRect(rowPlusRect, 10f, 10f, btnPaint)
        canvas.drawText("−", rowMinusRect.centerX(), rowMinusRect.centerY() + 12f, btnTextPaint)
        canvas.drawText("+", rowPlusRect.centerX(), rowPlusRect.centerY() + 12f, btnTextPaint)

        // 底部按钮：返回 / 确认
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

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        scaleDetector.onTouchEvent(event)
        if (isScaling) return true

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val x = event.x
                val y = event.y

                // 底部面板按钮
                if (y >= panelTop) {
                    handlePanelTouch(x, y)
                    return true
                }

                // 第一步：触摸任意位置开始拖动准心
                if (step == 1) {
                    isDragging = true
                    lastTouchX = x
                    lastTouchY = y
                    return true
                }
                // 第二步：不允许拖动，网格锁定在第一步位置
                // 只能通过底部面板按钮或双指缩放调整间距
            }

            MotionEvent.ACTION_MOVE -> {
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
            }
        }
        return true
    }

    private fun handlePanelTouch(x: Float, y: Float) {
        if (step == 1) {
            // 第一步面板：取消 / 下一步
            when {
                cancelBtnRect.contains(x, y) -> onCancel?.invoke()
                nextBtnRect.contains(x, y) -> {
                    lockedX = baseX
                    lockedY = baseY
                    step = 2
                    invalidate()
                }
            }
        } else {
            // 第二步面板：间距按钮 / 返回 / 确认
            when {
                colMinusRect.contains(x, y) -> {
                    colSpacing = (colSpacing - 10f).coerceAtLeast(40f)
                    invalidate()
                }
                colPlusRect.contains(x, y) -> {
                    colSpacing = (colSpacing + 10f).coerceAtMost(500f)
                    invalidate()
                }
                rowMinusRect.contains(x, y) -> {
                    rowSpacing = (rowSpacing - 10f).coerceAtLeast(40f)
                    invalidate()
                }
                rowPlusRect.contains(x, y) -> {
                    rowSpacing = (rowSpacing + 10f).coerceAtMost(500f)
                    invalidate()
                }
                backBtnRect.contains(x, y) -> {
                    step = 1
                    invalidate()
                }
                confirmBtnRect.contains(x, y) -> {
                    onConfirm?.invoke(lockedX, lockedY, colSpacing, rowSpacing)
                }
            }
        }
    }
}
