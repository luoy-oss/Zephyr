package com.zephyr.zephyr

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.view.View

/**
 * 点击动效覆盖层 - 在琴键位置显示点击波纹效果
 * 收到的坐标是屏幕绝对坐标，需要减去本视图的屏幕偏移转换为视图坐标
 */
class TapEffectOverlay(context: Context) : View(context) {

    private data class TapEffect(
        val x: Float,  // 视图坐标
        val y: Float,
        val startTime: Long,
        val duration: Long = 500,
        val label: String? = null
    )

    private data class NextKeyIndicator(
        val x: Float,  // 视图坐标
        val y: Float,
        val noteName: String
    )

    private val effects = mutableListOf<TapEffect>()
    private var nextKey: NextKeyIndicator? = null
    private val animators = mutableListOf<ValueAnimator>()

    // 视图在屏幕上的偏移量
    private val screenOffset = IntArray(2)

    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 4f
    }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 32f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
        setShadowLayer(4f, 0f, 0f, Color.BLACK)
    }
    private val nextKeyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 5f
    }
    private val nextKeyFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    /** 屏幕坐标 → 视图坐标 */
    private fun screenToViewX(screenX: Float): Float {
        return screenX - screenOffset[0]
    }

    private fun screenToViewY(screenY: Float): Float {
        return screenY - screenOffset[1]
    }

    /** 添加点击动效（接收屏幕坐标） */
    fun addTapEffect(screenX: Float, screenY: Float) {
        val vx = screenToViewX(screenX)
        val vy = screenToViewY(screenY)
        val effect = TapEffect(vx, vy, System.currentTimeMillis())
        effects.add(effect)
        startEffectAnimation(effect)
    }

    /** 添加 Debug 点击动效（接收屏幕坐标） */
    fun addDebugTapEffect(screenX: Float, screenY: Float, label: String) {
        val vx = screenToViewX(screenX)
        val vy = screenToViewY(screenY)
        val effect = TapEffect(vx, vy, System.currentTimeMillis(), duration = 800, label = label)
        effects.add(effect)
        startEffectAnimation(effect)
    }

    /** 设置下一个按键指示器（接收屏幕坐标） */
    fun setNextKeyIndicator(screenX: Float, screenY: Float, noteName: String) {
        nextKey = NextKeyIndicator(screenToViewX(screenX), screenToViewY(screenY), noteName)
        invalidate()
    }

    fun clearNextKeyIndicator() {
        nextKey = null
        invalidate()
    }

    private fun startEffectAnimation(effect: TapEffect) {
        val animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = effect.duration
            addUpdateListener {
                invalidate()
                if (it.animatedFraction >= 1f) {
                    synchronized(effects) {
                        effects.remove(effect)
                    }
                }
            }
        }
        animators.add(animator)
        animator.start()
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // 获取视图屏幕偏移
        getLocationOnScreen(screenOffset)

        val currentTime = System.currentTimeMillis()

        // 绘制下一个按键预指示
        nextKey?.let { nk ->
            val breathe = (Math.sin(System.currentTimeMillis() / 300.0) * 0.3 + 0.7).toFloat()
            val radius = 45f * breathe

            nextKeyFillPaint.color = Color.argb(60, 76, 175, 80)
            canvas.drawCircle(nk.x, nk.y, radius, nextKeyFillPaint)

            nextKeyPaint.color = Color.argb(200, 76, 175, 80)
            canvas.drawCircle(nk.x, nk.y, radius, nextKeyPaint)

            textPaint.color = Color.argb(230, 76, 175, 80)
            textPaint.textSize = 28f
            canvas.drawText(nk.noteName, nk.x, nk.y + 10f, textPaint)

            postInvalidateDelayed(16)
        }

        // 绘制点击动效
        val iterator = effects.iterator()
        while (iterator.hasNext()) {
            val effect = iterator.next()
            val elapsed = currentTime - effect.startTime
            val progress = (elapsed.toFloat() / effect.duration).coerceIn(0f, 1f)

            if (progress >= 1f) {
                iterator.remove()
                continue
            }

            // 外圈波纹
            val outerRadius = 40f + progress * 60f
            val outerAlpha = ((1f - progress) * 200).toInt()
            strokePaint.color = Color.argb(outerAlpha, 108, 99, 255)
            strokePaint.strokeWidth = 4f * (1f - progress * 0.5f)
            canvas.drawCircle(effect.x, effect.y, outerRadius, strokePaint)

            // 内圈
            val innerRadius = 20f + progress * 25f
            val innerAlpha = ((1f - progress) * 150).toInt()
            fillPaint.color = Color.argb(innerAlpha, 108, 99, 255)
            canvas.drawCircle(effect.x, effect.y, innerRadius, fillPaint)

            // 中心高亮
            val centerAlpha = ((1f - progress) * 255).toInt()
            fillPaint.color = Color.argb(centerAlpha, 255, 255, 255)
            canvas.drawCircle(effect.x, effect.y, 8f * (1f - progress * 0.5f), fillPaint)

            // Debug 标签
            effect.label?.let { label ->
                val textAlpha = ((1f - progress) * 255).toInt()
                textPaint.color = Color.argb(textAlpha, 255, 255, 100)
                textPaint.textSize = 24f
                canvas.drawText(label, effect.x, effect.y - outerRadius - 10f, textPaint)
            }
        }

        if (effects.isNotEmpty()) {
            postInvalidateDelayed(16)
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        animators.forEach { it.cancel() }
        animators.clear()
        effects.clear()
        nextKey = null
    }
}
