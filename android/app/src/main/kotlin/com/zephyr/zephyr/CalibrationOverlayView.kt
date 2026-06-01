package com.zephyr.zephyr

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View

/**
 * 校准覆盖层 - 在游戏上层显示琴键位置并可拖拽调整
 * 支持：单指拖动琴键位置，双指缩放调整间距
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

    // 画笔
    private val keyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.argb(120, 108, 99, 255)
    }
    private val keyBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = Color.parseColor("#6C63FF")
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 28f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    }
    private val crosshairPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.RED
        strokeWidth = 2f
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
    private val hintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#AAAAAA")
        textSize = 22f
        textAlign = Paint.Align.CENTER
    }

    // 拖拽状态
    private var isDragging = false
    private var lastTouchX = 0f
    private var lastTouchY = 0f

    // 双指缩放
    private var scaleDetector: ScaleGestureDetector
    private var isScaling = false

    // 固定控制面板区域（屏幕底部）
    private val panelHeight = 280f
    private var panelTop = 0f

    // 按钮区域（相对于面板）
    private var colMinusRect = RectF()
    private var colPlusRect = RectF()
    private var rowMinusRect = RectF()
    private var rowPlusRect = RectF()
    private var confirmBtnRect = RectF()
    private var cancelBtnRect = RectF()

    init {
        scaleDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                val scaleFactor = detector.scaleFactor
                colSpacing = (colSpacing * scaleFactor).coerceIn(60f, 400f)
                rowSpacing = (rowSpacing * scaleFactor).coerceIn(60f, 400f)
                invalidate()
                return true
            }

            override fun onScaleBegin(detector: ScaleGestureDetector): Boolean {
                isScaling = true
                return true
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

        // ===== 绘制琴键 =====
        for (row in 0..2) {
            for (col in 0..4) {
                val x = baseX + col * colSpacing
                val y = baseY + row * rowSpacing
                val radius = 40f

                canvas.drawCircle(x, y, radius, keyPaint)
                canvas.drawCircle(x, y, radius, keyBorderPaint)
                canvas.drawText(noteNames[row][col], x, y + 10f, textPaint)
            }
        }

        // 基准点十字标记
        canvas.drawLine(baseX - 15, baseY - 15, baseX + 15, baseY + 15, crosshairPaint)
        canvas.drawLine(baseX + 15, baseY - 15, baseX - 15, baseY + 15, crosshairPaint)

        // ===== 顶部提示 =====
        canvas.drawText("单指拖动琴键位置 · 双指缩放调整间距", w / 2f, 50f, hintPaint)

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

        // 确认/取消按钮
        val btnY2 = panelTop + panelHeight - 85f
        val btnWidth = (w - 80f) / 2

        cancelBtnRect.set(20f, btnY2, 20f + btnWidth, btnY2 + 65f)
        confirmBtnRect.set(w - 20f - btnWidth, btnY2, w - 20f, btnY2 + 65f)

        btnPaint.color = Color.parseColor("#D32F2F")
        canvas.drawRoundRect(cancelBtnRect, 14f, 14f, btnPaint)
        btnPaint.color = Color.parseColor("#388E3C")
        canvas.drawRoundRect(confirmBtnRect, 14f, 14f, btnPaint)

        canvas.drawText("取消", cancelBtnRect.centerX(), cancelBtnRect.centerY() + 12f, btnTextPaint)
        canvas.drawText("确认", confirmBtnRect.centerX(), confirmBtnRect.centerY() + 12f, btnTextPaint)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        // 让缩放检测器先处理
        scaleDetector.onTouchEvent(event)

        // 如果正在缩放，不处理其他触摸
        if (isScaling) return true

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val x = event.x
                val y = event.y

                // 检查底部面板按钮
                if (y >= panelTop) {
                    when {
                        colMinusRect.contains(x, y) -> {
                            colSpacing = (colSpacing - 10f).coerceAtLeast(60f)
                            invalidate()
                            return true
                        }
                        colPlusRect.contains(x, y) -> {
                            colSpacing = (colSpacing + 10f).coerceAtMost(400f)
                            invalidate()
                            return true
                        }
                        rowMinusRect.contains(x, y) -> {
                            rowSpacing = (rowSpacing - 10f).coerceAtLeast(60f)
                            invalidate()
                            return true
                        }
                        rowPlusRect.contains(x, y) -> {
                            rowSpacing = (rowSpacing + 10f).coerceAtMost(400f)
                            invalidate()
                            return true
                        }
                        confirmBtnRect.contains(x, y) -> {
                            onConfirm?.invoke(baseX, baseY, colSpacing, rowSpacing)
                            return true
                        }
                        cancelBtnRect.contains(x, y) -> {
                            onCancel?.invoke()
                            return true
                        }
                    }
                    return true // 在面板区域但没点到按钮
                }

                // 检查是否在琴键区域
                val keyAreaLeft = baseX - 50f
                val keyAreaTop = baseY - 50f
                val keyAreaRight = baseX + 4 * colSpacing + 50f
                val keyAreaBottom = baseY + 2 * rowSpacing + 50f

                if (x in keyAreaLeft..keyAreaRight && y in keyAreaTop..keyAreaBottom) {
                    isDragging = true
                    lastTouchX = x
                    lastTouchY = y
                    return true
                }
            }

            MotionEvent.ACTION_MOVE -> {
                if (isDragging && event.pointerCount == 1) {
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
}
