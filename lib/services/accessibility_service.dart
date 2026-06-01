import 'package:flutter/services.dart';

/// 与Android原生层通信的服务
class NativeService {
  static const _mainChannel = MethodChannel('com.zephyr.zephyr/main');
  static const _tapChannel = MethodChannel('com.zephyr.zephyr/tap');
  static const _floatingChannel = MethodChannel('com.zephyr.zephyr/floating');

  // ========== 权限相关 ==========

  static Future<bool> checkAccessibility() async {
    try {
      return await _mainChannel.invokeMethod<bool>('checkAccessibility') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    await _mainChannel.invokeMethod('openAccessibilitySettings');
  }

  static Future<bool> checkOverlayPermission() async {
    try {
      return await _mainChannel.invokeMethod<bool>('checkOverlayPermission') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    await _mainChannel.invokeMethod('requestOverlayPermission');
  }

  // ========== 悬浮窗控制 ==========

  static Future<void> startFloatingWindow() async {
    await _mainChannel.invokeMethod('startFloatingWindow');
  }

  static Future<void> stopFloatingWindow() async {
    await _mainChannel.invokeMethod('stopFloatingWindow');
  }

  static Future<bool> isFloatingWindowRunning() async {
    try {
      return await _mainChannel.invokeMethod<bool>('isFloatingWindowRunning') ?? false;
    } catch (e) {
      return false;
    }
  }

  // ========== 悬浮窗数据同步 ==========

  /// 更新悬浮窗中的曲目列表
  static Future<void> updateScoreList(List<Map<String, String>> scores) async {
    await _floatingChannel.invokeMethod('updateScoreList', {'scores': scores});
  }

  /// 更新悬浮窗中选中的曲目名称
  static Future<void> updateSelectedScore(String name) async {
    await _floatingChannel.invokeMethod('updateSelectedScore', {'name': name});
  }

  /// 更新悬浮窗中的校准配置
  static Future<void> updateFloatingConfig(
    double baseX, double baseY, double colSpacing, double rowSpacing
  ) async {
    await _floatingChannel.invokeMethod('updateConfig', {
      'baseX': baseX, 'baseY': baseY,
      'colSpacing': colSpacing, 'rowSpacing': rowSpacing,
    });
  }

  /// 更新播放进度
  static Future<void> updateProgress(int current, int total) async {
    await _floatingChannel.invokeMethod('updateProgress', {
      'current': current,
      'total': total,
    });
  }

  /// 显示点击动效
  static Future<void> showTapEffect(double x, double y) async {
    await _floatingChannel.invokeMethod('showTapEffect', {
      'x': x,
      'y': y,
    });
  }

  /// 显示带坐标的 Debug 点击动效
  static Future<void> showDebugTapEffect(double x, double y, String label) async {
    await _floatingChannel.invokeMethod('showDebugTapEffect', {
      'x': x, 'y': y, 'label': label,
    });
  }

  /// 显示倒计时覆盖层
  static Future<void> showCountdown(int seconds) async {
    await _floatingChannel.invokeMethod('showCountdown', {'seconds': seconds});
  }

  /// 更新倒计时
  static Future<void> updateCountdown(int seconds) async {
    await _floatingChannel.invokeMethod('updateCountdown', {'seconds': seconds});
  }

  /// 隐藏倒计时覆盖层
  static Future<void> hideCountdown() async {
    await _floatingChannel.invokeMethod('hideCountdown');
  }

  /// 设置悬浮窗回调
  static Future<void> setFloatingCallbacks({
    required Function() onPlay,
    required Function() onPause,
    required Function() onStop,
    required Function(String) onSelectScore,
    required Function(double, double, double, double) onCalibrationChanged,
    Function()? onPanelOpened,
  }) async {
    // 先设置原生端回调
    await _floatingChannel.invokeMethod('setCallbacks');

    // 设置 Flutter 端回调
    _floatingChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlay':
          onPlay();
          break;
        case 'onPause':
          onPause();
          break;
        case 'onStop':
          onStop();
          break;
        case 'onSelectScore':
          final id = call.arguments as String? ?? '';
          onSelectScore(id);
          break;
        case 'onCalibrationChanged':
          final args = call.arguments as Map<dynamic, dynamic>;
          onCalibrationChanged(
            (args['baseX'] as num).toDouble(),
            (args['baseY'] as num).toDouble(),
            (args['colSpacing'] as num).toDouble(),
            (args['rowSpacing'] as num).toDouble(),
          );
          break;
        case 'onPanelOpened':
          onPanelOpened?.call();
          break;
      }
    });
  }

  // ========== 点击模拟 ==========

  static Future<bool> tap(double x, double y, int durationMs) async {
    try {
      await _tapChannel.invokeMethod('tap', {'x': x, 'y': y, 'durationMs': durationMs});
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> tapMultiple(List<List<double>> points, int durationMs) async {
    try {
      await _tapChannel.invokeMethod('tapMultiple', {'points': points, 'durationMs': durationMs});
      return true;
    } catch (e) {
      return false;
    }
  }
}
