package com.zephyr.zephyr

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.util.Log

/**
 * 点击模拟辅助类 - 通过无障碍服务模拟屏幕点击
 */
class TapHelper(private val service: AccessibilityService) {

    companion object {
        private const val TAG = "TapHelper"
    }

    /**
     * 在指定坐标执行点击
     * @param x 屏幕X坐标
     * @param y 屏幕Y坐标
     * @param durationMs 按下持续时间（毫秒）
     * @param callback 点击完成回调
     */
    fun tap(
        x: Float,
        y: Float,
        durationMs: Long = 100,
        callback: ((Boolean) -> Unit)? = null
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            Log.w(TAG, "GestureDescription requires API 24+")
            callback?.invoke(false)
            return
        }

        val path = Path().apply {
            moveTo(x, y)
        }

        val stroke = GestureDescription.StrokeDescription(
            path,
            0,
            durationMs
        )

        val gesture = GestureDescription.Builder()
            .addStroke(stroke)
            .build()

        val success = service.dispatchGesture(gesture, object : AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                callback?.invoke(true)
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                callback?.invoke(false)
            }
        }, null)

        if (!success) {
            Log.w(TAG, "dispatchGesture returned false")
            callback?.invoke(false)
        }
    }

    /**
     * 同时点击多个坐标（和弦）
     */
    fun tapMultiple(
        points: List<Pair<Float, Float>>,
        durationMs: Long = 100,
        callback: ((Boolean) -> Unit)? = null
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            callback?.invoke(false)
            return
        }

        val builder = GestureDescription.Builder()
        for ((x, y) in points) {
            val path = Path().apply { moveTo(x, y) }
            builder.addStroke(
                GestureDescription.StrokeDescription(path, 0, durationMs)
            )
        }

        val gesture = builder.build()
        service.dispatchGesture(gesture, object : AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                callback?.invoke(true)
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                callback?.invoke(false)
            }
        }, null)
    }
}
