package com.zephyr.zephyr

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * 无障碍服务 - 提供屏幕点击能力
 */
class PianoAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "PianoAccessibility"
        private const val CHANNEL = "com.zephyr.zephyr/accessibility"

        var instance: PianoAccessibilityService? = null
            private set

        var tapHelper: TapHelper? = null
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        tapHelper = TapHelper(this)

        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        }

        Log.i(TAG, "Accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 不需要处理无障碍事件，仅用于获取点击能力
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility service interrupted")
    }

    override fun onDestroy() {
        instance = null
        tapHelper = null
        super.onDestroy()
    }

    /**
     * 在指定坐标执行点击
     */
    fun performTap(x: Float, y: Float, durationMs: Long): Boolean {
        val helper = tapHelper ?: return false
        helper.tap(x, y, durationMs)
        return true
    }

    /**
     * 同时点击多个坐标（和弦）
     */
    fun performMultiTap(points: List<Pair<Float, Float>>, durationMs: Long): Boolean {
        val helper = tapHelper ?: return false
        helper.tapMultiple(points, durationMs)
        return true
    }
}
