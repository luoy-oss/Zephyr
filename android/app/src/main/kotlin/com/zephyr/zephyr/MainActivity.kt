package com.zephyr.zephyr

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.zephyr.zephyr/main"
    private val TAP_CHANNEL = "com.zephyr.zephyr/tap"

    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 主通信通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibility" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    result.success(canDrawOverlays())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "startFloatingWindow" -> {
                    startFloatingWindowService()
                    result.success(true)
                }
                "stopFloatingWindow" -> {
                    stopFloatingWindowService()
                    result.success(true)
                }
                "isFloatingWindowRunning" -> {
                    result.success(FloatingWindowService.isRunning)
                }
                else -> result.notImplemented()
            }
        }

        // 点击通信通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TAP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "tap" -> {
                    val x = (call.argument<Number>("x"))?.toFloat() ?: 0f
                    val y = (call.argument<Number>("y"))?.toFloat() ?: 0f
                    val duration = call.argument<Number>("durationMs")?.toLong() ?: 100L
                    val service = PianoAccessibilityService.instance
                    if (service != null) {
                        service.performTap(x, y, duration)
                        result.success(true)
                    } else {
                        result.error("NO_SERVICE", "无障碍服务未运行", null)
                    }
                }
                "tapMultiple" -> {
                    val points = call.argument<List<List<Double>>>("points") ?: emptyList()
                    val duration = call.argument<Number>("durationMs")?.toLong() ?: 100L
                    val service = PianoAccessibilityService.instance
                    if (service != null) {
                        val pairs = points.map { it[0].toFloat() to it[1].toFloat() }
                        service.performMultiTap(pairs, duration)
                        result.success(true)
                    } else {
                        result.error("NO_SERVICE", "无障碍服务未运行", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        // 方法1: 检查服务实例是否存在
        if (PianoAccessibilityService.instance != null) {
            return true
        }

        // 方法2: 检查系统设置中的启用服务列表
        val serviceName = ComponentName(packageName, PianoAccessibilityService::class.java.name)
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = enabledServices.split(":")
        for (componentName in colonSplitter) {
            val cn = ComponentName.unflattenFromString(componentName.trim())
            if (cn != null && cn == serviceName) {
                return true
            }
        }
        return false
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun openAccessibilitySettings() {
        try {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        } catch (e: Exception) {
            Log.e(TAG, "Error opening accessibility settings", e)
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting overlay permission", e)
            }
        }
    }

    private fun startFloatingWindowService() {
        if (!canDrawOverlays()) {
            Log.w(TAG, "Overlay permission not granted")
            requestOverlayPermission()
            return
        }

        val intent = Intent(this, FloatingWindowService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopFloatingWindowService() {
        stopService(Intent(this, FloatingWindowService::class.java))
    }
}
