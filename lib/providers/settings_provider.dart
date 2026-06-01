import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/key_position.dart';

/// 设置状态管理
class SettingsNotifier extends StateNotifier<KeyPositionConfig> {
  static const _prefsKey = 'key_position_config';

  SettingsNotifier() : super(const KeyPositionConfig()) {
    _load();
  }

  /// 加载保存的配置
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      state = KeyPositionConfig.fromJsonString(json);
    }
  }

  /// 保存配置
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.toJsonString());
  }

  /// 更新基准位置
  Future<void> updateBasePosition(double x, double y) async {
    state = state.copyWith(baseX: x, baseY: y);
    await _save();
  }

  /// 更新列间距
  Future<void> updateColumnSpacing(double spacing) async {
    state = state.copyWith(columnSpacing: spacing);
    await _save();
  }

  /// 更新行间距
  Future<void> updateRowSpacing(double spacing) async {
    state = state.copyWith(rowSpacing: spacing);
    await _save();
  }

  /// 更新点击时长
  Future<void> updateTapDuration(int ms) async {
    state = state.copyWith(tapDurationMs: ms);
    await _save();
  }

  /// 更新倒计时秒数
  Future<void> updateCountdown(int seconds) async {
    state = state.copyWith(countdownSeconds: seconds);
    await _save();
  }

  /// 完整更新配置
  Future<void> updateConfig(KeyPositionConfig config) async {
    state = config;
    await _save();
  }
}

/// 设置 Provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, KeyPositionConfig>((ref) {
  return SettingsNotifier();
});

/// BPM Provider（默认75）
final bpmProvider = StateProvider<double>((ref) => 75);
