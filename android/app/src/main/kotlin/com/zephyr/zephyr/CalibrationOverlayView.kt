package com.zephyr.zephyr

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View

/**
 * 校准覆盖层 - 在游戏上层显示琴键位置并可拖拽调整
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

    private val keyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.argb(100, 108, 99, 255)
    }

    private val keyBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2f
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

    private val btnPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val btnTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 32f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    }

    private val hintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 24f
        textAlign = Paint.Align.CENTER
    }

    // 拖拽状态
    private var isDraggingBase = false
    private var isDraggingSpacingH = false
    private var isDraggingSpacingV = false
    private var lastTouchX = 0f
    private var lastTouchY = 0f

    // 按钮区域
    private var confirmBtnRect = RectF()
    private var cancelBtnRect = RectF()
    private var spacingHPlusRect = RectF()
    private var spacingHMinusRect = RectF()
    private var spacingVPlusRect = RectF()
    private var spacingVMinusRect = RectF()

    private val btnSize = 60f
    private val btnMargin = 10f

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // 绘制半透明背景提示
        canvas.drawText("拖动琴键调整位置，拖动间距按钮调整大小",
            width / 2f, 60f, hintPaint)

        // 绘制15个琴键
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

        // 绘制基准点十字标记
        canvas.drawLine(baseX - 15, baseY - 15, baseX + 15, baseY + 15, crosshairPaint)
        canvas.drawLine(baseX + 15, baseY - 15, baseX - 15, baseY + 15, crosshairPaint)

        // 绘制间距调整按钮
        val btnY = baseY + 3 * rowSpacing + 60f

        // 列间距调整
        val csLabelX = baseX + 2 * colSpacing
        canvas.drawText("列间距: ${colSpacing.toInt()}", csLabelX, btnY, hintPaint)

        spacingHMinusRect.set(csLabelX - 120f, btnY + 10f, csLabelX - 60f, btnY + 70f)
        spacingHPlusRect.set(csLabelX + 60f, btnY + 10f, csLabelX + 120f, btnY + 70f)

        btnPaint.color = Color.parseColor("#3A3A3A")
        canvas.drawRoundRect(spacingHMinusRect, 8f, 8f, btnPaint)
        canvas.drawRoundRect(spacingHPlusRect, 8f, 8f, btnPaint)
        canvas.drawText("−", spacingHMinusRect.centerX(), spacingHMinusRect.centerY() + 10f, btnTextPaint)
        canvas.drawText("+", spacingHPlusRect.centerX(), spacingHPlusRect.centerY() + 10f, btnTextPaint)

        // 行间距调整
        val vsLabelY = btnY + 100f
        canvas.drawText("行间距: ${rowSpacing.toInt()}", csLabelX, vsLabelY, hintPaint)

        spacingVMinusRect.set(csLabelX - 120f, vsLabelY + 10f, csLabelX - 60f, vsLabelY + 70f)
        spacingVPlusRect.set(csLabelX + 60f, vsLabelY + 10f, csLabelX + 120f, vsLabelY + 70f)

        canvas.drawRoundRect(spacingVMinusRect, 8f, 8f, btnPaint)
        canvas.drawRoundRect(spacingVPlusRect, 8f, 8f, btnPaint)
        canvas.drawText("−", spacingVMinusRect.centerX(), spacingVMinusRect.centerY() + 10f, btnTextPaint)
        canvas.drawText("+", spacingVPlusRect.centerX(), spacingVPlusRect.centerY() + 10f, btnTextPaint)

        // 绘制确认/取消按钮
        val bottomY = height - 120f
        cancelBtnRect.set(width / 2f - 160f, bottomY, width / 2f - 20f, bottomY + 70f)
        confirmBtnRect.set(width / 2f + 20f, bottomY, width / 2f + 160f, bottomY + 70f)

        btnPaint.color = Color.parseColor("#F44336")
        canvas.drawRoundRect(cancelBtnRect, 12f, 12f, btnPaint)
        btnPaint.color = Color.parseColor("#4CAF50")
        canvas.drawRoundRect(confirmBtnRect, 12f, 12f, btnPaint)

        canvas.drawText("取消", cancelBtnRect.centerX(), cancelBtnRect.centerY() + 10f, btnTextPaint)
        canvas.drawText("确认", confirmBtnRect.centerX(), confirmBtnRect.centerY() + 10f, btnTextPaint)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                val x = event.x
                val y = event.y

                // 检查按钮点击
                if (confirmBtnRect.contains(x, y)) {
                    onConfirm?.invoke(baseX, baseY, colSpacing, rowSpacing)
                    return true
                }
                if (cancelBtnRect.contains(x, y)) {
                    onCancel?.invoke()
                    return true
                }

                // 间距调整按钮
                if (spacingHMinusRect.contains(x, y)) {
                    colSpacing = (colSpacing - 10f).coerceAtLeast(60f)
                    invalidate()
                    return true
                }
                if (spacingHPlusRect.contains(x, y)) {
                    colSpacing = (colSpacing + 10f).coerceAtMost(400f)
                    invalidate()
                    return true
                }
                if (spacingVMinusRect.contains(x, y)) {
                    rowSpacing = (rowSpacing - 10f).coerceAtLeast(60f)
                    invalidate()
                    return true
                }
                if (spacingVPlusRect.contains(x, y)) {
                    rowSpacing = (rowSpacing + 10f).coerceAtMost(400f)
                    invalidate()
                    return true
                }

                // 检查是否点击在琴键区域（拖拽基准点）
                val keyAreaRight = baseX + 4 * colSpacing + 50f
                val keyAreaBottom = baseY + 2 * rowSpacing + 50f
                if (x in (baseX - 50f)..keyAreaRight && y in (baseY - 50f)..keyAreaBottom) {
                    isDraggingBase = true
                    lastTouchX = x
                    lastTouchY = y
                    return true
                }
            }
            MotionEvent.ACTION_MOVE -> {
                if (isDraggingBase) {
                    baseX += event.x - lastTouchX
                    baseY += event.y - lastTouchY
                    lastTouchX = event.x
                    lastTouchY = event.y
                    invalidate()
                    return true
                }
            }
            MotionEvent.ACTION_UP -> {
                isDraggingBase = false
            }
        }
        return true
    }
}
