package com.zephyr.zephyr

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.zephyr.zephyr/main"
    private val TAP_CHANNEL = "com.zephyr.zephyr/tap"
    private val FLOATING_CHANNEL = "com.zephyr.zephyr/floating"

    private var mainChannel: MethodChannel? = null
    private var tapChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 主通信通道
        mainChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        mainChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibility" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
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
                else -> result.notImplemented()
            }
        }

        // 点击通信通道
        tapChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TAP_CHANNEL)
        tapChannel?.setMethodCallHandler { call, result ->
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
                        result.error("NO_SERVICE", "Accessibility service not running", null)
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
                        result.error("NO_SERVICE", "Accessibility service not running", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "${packageName}/${PianoAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(service)
    }

    private fun openAccessibilitySettings() {
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        }
    }

    private fun startFloatingWindowService() {
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
