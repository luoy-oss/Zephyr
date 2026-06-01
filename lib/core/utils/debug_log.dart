import 'dart:developer' as developer;

/// Debug 日志工具
///
/// 仅在 debug 模式开启时输出日志，支持分级打印。
/// 使用 [DebugLog.enabled] 全局控制开关。
class DebugLog {
  /// 是否启用 debug 日志
  static bool enabled = false;

  /// 标签
  static const _tag = 'Zephyr';

  /// 普通调试信息
  static void d(String message) {
    if (!enabled) return;
    developer.log(message, name: _tag);
    // ignore: avoid_print
    print('[$_tag] $message');
  }

  /// 信息级别
  static void i(String message) {
    if (!enabled) return;
    developer.log('ℹ️ $message', name: _tag);
    // ignore: avoid_print
    print('[$_tag] ℹ️ $message');
  }

  /// 警告级别
  static void w(String message) {
    if (!enabled) return;
    developer.log('⚠️ $message', name: _tag);
    // ignore: avoid_print
    print('[$_tag] ⚠️ $message');
  }

  /// 错误级别
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;
    developer.log('❌ $message', name: _tag, error: error, stackTrace: stackTrace);
    // ignore: avoid_print
    print('[$_tag] ❌ $message${error != null ? ' | $error' : ''}');
  }

  /// 分隔线
  static void divider([String title = '']) {
    if (!enabled) return;
    final line = title.isEmpty ? '─' * 50 : '─── $title ${'─' * (47 - title.length)}';
    // ignore: avoid_print
    print('[$_tag] $line');
  }

  /// 打印多行文本块（用于 JSON 内容预览等）
  static void block(String title, String content) {
    if (!enabled) return;
    divider(title);
    for (final line in content.split('\n')) {
      // ignore: avoid_print
      print('[$_tag]   $line');
    }
    divider();
  }

  /// 打印列表数据
  static void list(String title, List<dynamic> items) {
    if (!enabled) return;
    divider(title);
    for (var i = 0; i < items.length; i++) {
      // ignore: avoid_print
      print('[$_tag]   [$i] ${items[i]}');
    }
    divider();
  }
}
