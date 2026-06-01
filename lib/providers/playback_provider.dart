import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/score.dart';
import 'score_provider.dart';
import 'settings_provider.dart';

/// 播放状态
enum PlaybackStatus {
  idle, // 空闲
  countdown, // 倒计时中
  playing, // 播放中
  paused, // 暂停
}

/// 播放状态数据
class PlaybackState {
  final PlaybackStatus status;
  final int currentEventIndex;
  final int totalEvents;
  final int countdownRemaining;
  final double speed; // BPM倍率 (1.0 = 原速)

  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.currentEventIndex = 0,
    this.totalEvents = 0,
    this.countdownRemaining = 0,
    this.speed = 1.0,
  });

  PlaybackState copyWith({
    PlaybackStatus? status,
    int? currentEventIndex,
    int? totalEvents,
    int? countdownRemaining,
    double? speed,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      currentEventIndex: currentEventIndex ?? this.currentEventIndex,
      totalEvents: totalEvents ?? this.totalEvents,
      countdownRemaining: countdownRemaining ?? this.countdownRemaining,
      speed: speed ?? this.speed,
    );
  }

  double get progress =>
      totalEvents > 0 ? currentEventIndex / totalEvents : 0;

  /// 下一个事件索引（用于预显示待按按键）
  int get nextEventIndex =>
      currentEventIndex < totalEvents ? currentEventIndex : totalEvents;
}

/// 播放引擎
class PlaybackNotifier extends StateNotifier<PlaybackState> {
  final Ref ref;
  Timer? _timer;
  Timer? _countdownTimer;

  PlaybackNotifier(this.ref) : super(const PlaybackState());

  /// 开始播放（或恢复）
  void play() {
    final scoreState = ref.read(scoreListProvider);
    final score = scoreState.selectedScore;
    if (score == null || score.events.isEmpty) return;

    if (state.status == PlaybackStatus.paused) {
      // 恢复播放
      state = state.copyWith(status: PlaybackStatus.playing);
      _startTimer();
      return;
    }

    // 新播放：先倒计时
    final countdown = ref.read(settingsProvider).countdownSeconds;
    if (countdown > 0) {
      state = state.copyWith(
        status: PlaybackStatus.countdown,
        countdownRemaining: countdown,
        totalEvents: score.events.length,
        currentEventIndex: 0,
      );
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final remaining = state.countdownRemaining - 1;
        if (remaining <= 0) {
          timer.cancel();
          state = state.copyWith(
            status: PlaybackStatus.playing,
            countdownRemaining: 0,
          );
          _startTimer();
        } else {
          state = state.copyWith(countdownRemaining: remaining);
        }
      });
    } else {
      state = state.copyWith(
        status: PlaybackStatus.playing,
        totalEvents: score.events.length,
        currentEventIndex: 0,
      );
      _startTimer();
    }
  }

  /// 暂停
  void pause() {
    _timer?.cancel();
    state = state.copyWith(status: PlaybackStatus.paused);
  }

  /// 停止
  void stop() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    state = const PlaybackState();
  }

  /// 设置速度倍率
  void setSpeed(double speed) {
    state = state.copyWith(speed: speed.clamp(0.1, 10.0));
    if (state.status == PlaybackStatus.playing) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// 获取当前待播放的事件（用于预显示下一个按键）
  ScoreEvent? get currentEvent {
    final scoreState = ref.read(scoreListProvider);
    final score = scoreState.selectedScore;
    if (score == null) return null;
    final idx = state.currentEventIndex;
    if (idx < 0 || idx >= score.events.length) return null;
    return score.events[idx];
  }

  /// 获取下一个待播放的事件（用于预显示）
  ScoreEvent? get nextEvent {
    final scoreState = ref.read(scoreListProvider);
    final score = scoreState.selectedScore;
    if (score == null) return null;
    final idx = state.nextEventIndex;
    if (idx < 0 || idx >= score.events.length) return null;
    return score.events[idx];
  }

  /// 启动播放定时器
  void _startTimer() {
    final bpm = ref.read(bpmProvider);
    final intervalMs = (60000 / bpm / state.speed).round();

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      final scoreState = ref.read(scoreListProvider);
      final score = scoreState.selectedScore;
      if (score == null) {
        stop();
        return;
      }

      final idx = state.currentEventIndex;
      if (idx >= score.events.length) {
        stop();
        return;
      }

      final event = score.events[idx];

      // 通知回调（由UI层监听并执行点击）
      if (!event.isRest) {
        _onNoteEvent?.call(event);
      }

      // 移动到下一个事件
      state = state.copyWith(currentEventIndex: idx + 1);
    });
  }

  /// 音符事件回调
  void Function(ScoreEvent event)? _onNoteEvent;

  void setOnNoteEvent(void Function(ScoreEvent event)? callback) {
    _onNoteEvent = callback;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}

/// 播放状态 Provider
final playbackProvider =
    StateNotifierProvider<PlaybackNotifier, PlaybackState>((ref) {
  return PlaybackNotifier(ref);
});
