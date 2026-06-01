import 'dart:convert';

/// 琴键位置配置 - 定义光遇钢琴在屏幕上的位置
class KeyPositionConfig {
  /// 基准X坐标（左上角第一个琴键 -1 的X）
  final double baseX;

  /// 基准Y坐标（左上角第一个琴键 -1 的Y）
  final double baseY;

  /// 列间距（相邻列之间的像素距离）
  final double columnSpacing;

  /// 行间距（相邻行之间的像素距离）
  final double rowSpacing;

  /// 点击持续时间（毫秒）
  final int tapDurationMs;

  /// 演奏前倒计时（秒）
  final int countdownSeconds;

  const KeyPositionConfig({
    this.baseX = 0,
    this.baseY = 0,
    this.columnSpacing = 100,
    this.rowSpacing = 100,
    this.tapDurationMs = 100,
    this.countdownSeconds = 3,
  });

  KeyPositionConfig copyWith({
    double? baseX,
    double? baseY,
    double? columnSpacing,
    double? rowSpacing,
    int? tapDurationMs,
    int? countdownSeconds,
  }) {
    return KeyPositionConfig(
      baseX: baseX ?? this.baseX,
      baseY: baseY ?? this.baseY,
      columnSpacing: columnSpacing ?? this.columnSpacing,
      rowSpacing: rowSpacing ?? this.rowSpacing,
      tapDurationMs: tapDurationMs ?? this.tapDurationMs,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    );
  }

  /// 计算指定行列的屏幕坐标
  double getX(int col) => baseX + col * columnSpacing;
  double getY(int row) => baseY + row * rowSpacing;

  Map<String, dynamic> toJson() => {
        'baseX': baseX,
        'baseY': baseY,
        'columnSpacing': columnSpacing,
        'rowSpacing': rowSpacing,
        'tapDurationMs': tapDurationMs,
        'countdownSeconds': countdownSeconds,
      };

  factory KeyPositionConfig.fromJson(Map<String, dynamic> json) {
    return KeyPositionConfig(
      baseX: (json['baseX'] ?? 0).toDouble(),
      baseY: (json['baseY'] ?? 0).toDouble(),
      columnSpacing: (json['columnSpacing'] ?? 100).toDouble(),
      rowSpacing: (json['rowSpacing'] ?? 100).toDouble(),
      tapDurationMs: json['tapDurationMs'] ?? 100,
      countdownSeconds: json['countdownSeconds'] ?? 3,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory KeyPositionConfig.fromJsonString(String str) =>
      KeyPositionConfig.fromJson(jsonDecode(str));
}
