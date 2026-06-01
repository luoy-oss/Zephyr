import 'package:flutter/services.dart';

/// 与Android原生层通信的服务
class NativeService {
  static const _mainChannel = MethodChannel('com.zephyr.zephyr/main');
  static const _tapChannel = MethodChannel('com.zephyr.zephyr/tap');

  /// 检查无障碍服务是否已启用
  static Future<bool> checkAccessibility() async {
    try {
      final result = await _mainChannel.invokeMethod<bool>('checkAccessibility');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 打开无障碍设置页面
  static Future<void> openAccessibilitySettings() async {
    await _mainChannel.invokeMethod('openAccessibilitySettings');
  }

  /// 检查悬浮窗权限
  static Future<bool> checkOverlayPermission() async {
    try {
      final result = await _mainChannel.invokeMethod<bool>('checkOverlayPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 请求悬浮窗权限
  static Future<void> requestOverlayPermission() async {
    await _mainChannel.invokeMethod('requestOverlayPermission');
  }

  /// 启动悬浮窗服务
  static Future<void> startFloatingWindow() async {
    await _mainChannel.invokeMethod('startFloatingWindow');
  }

  /// 停止悬浮窗服务
  static Future<void> stopFloatingWindow() async {
    await _mainChannel.invokeMethod('stopFloatingWindow');
  }

  /// 执行单点点击
  static Future<void> tap(double x, double y, int durationMs) async {
    await _tapChannel.invokeMethod('tap', {
      'x': x,
      'y': y,
      'durationMs': durationMs,
    });
  }

  /// 执行多点点击（和弦）
  static Future<void> tapMultiple(
    List<List<double>> points,
    int durationMs,
  ) async {
    await _tapChannel.invokeMethod('tapMultiple', {
      'points': points,
      'durationMs': durationMs,
    });
  }
}
