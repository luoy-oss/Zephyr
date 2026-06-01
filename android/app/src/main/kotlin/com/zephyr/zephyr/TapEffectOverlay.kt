package com.zephyr.zephyr

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.view.View

/**
 * 点击动效覆盖层 - 在琴键位置显示点击波纹效果
 */
class TapEffectOverlay(context: Context) : View(context) {

    private data class TapEffect(
        val x: Float,
        val y: Float,
        val startTime: Long,
        val duration: Long = 400
    )

    private val effects = mutableListOf<TapEffect>()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
    }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val animators = mutableListOf<ValueAnimator>()

    fun addTapEffect(x: Float, y: Float) {
        val effect = TapEffect(x, y, System.currentTimeMillis())
        effects.add(effect)

        // 创建波纹动画
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

        val currentTime = System.currentTimeMillis()
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
            val outerRadius = 30f + progress * 40f
            val outerAlpha = ((1f - progress) * 180).toInt()
            paint.color = Color.argb(outerAlpha, 108, 99, 255)
            canvas.drawCircle(effect.x, effect.y, outerRadius, paint)

            // 内圈
            val innerRadius = 15f + progress * 15f
            val innerAlpha = ((1f - progress) * 120).toInt()
            fillPaint.color = Color.argb(innerAlpha, 108, 99, 255)
            canvas.drawCircle(effect.x, effect.y, innerRadius, fillPaint)

            // 中心点
            val centerAlpha = ((1f - progress) * 255).toInt()
            fillPaint.color = Color.argb(centerAlpha, 255, 255, 255)
            canvas.drawCircle(effect.x, effect.y, 5f * (1f - progress * 0.5f), fillPaint)
        }

        // 如果还有动画，继续刷新
        if (effects.isNotEmpty()) {
            postInvalidateDelayed(16) // ~60fps
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        animators.forEach { it.cancel() }
        animators.clear()
        effects.clear()
    }
}
