import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/debug_log.dart';
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
  final double speed; // 速度倍率 (1.0 = 原速)

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

/// 播放引擎 - 基于事件时间戳的变间隔播放
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
      _scheduleNextEvent();
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
          _scheduleNextEvent();
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
      _scheduleNextEvent();
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
      // 速度改变后重新调度下一个事件
      _timer?.cancel();
      _scheduleNextEvent();
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

  /// 调度下一个事件（基于时间戳计算延迟）
  void _scheduleNextEvent() {
    final scoreState = ref.read(scoreListProvider);
    final score = scoreState.selectedScore;
    if (score == null) return;

    final idx = state.currentEventIndex;
    if (idx >= score.events.length) {
      stop();
      return;
    }

    final event = score.events[idx];

    // 触发当前事件
    if (!event.isRest) {
      _onNoteEvent?.call(event);
    }

    // 计算到下一个事件的延迟
    final nextIdx = idx + 1;
    if (nextIdx >= score.events.length) {
      // 最后一个事件，播放完成
      state = state.copyWith(currentEventIndex: nextIdx);
      // 延迟一小段时间后停止
      _timer = Timer(const Duration(milliseconds: 500), () => stop());
      return;
    }

    final nextEvent = score.events[nextIdx];
    final timeDiff = nextEvent.time - event.time;

    // 延迟计算：timeDiff * msPerTick / speed
    // msPerTick = 60000 / (bpm * 480)，其中 480 是标准 MIDI 每拍 tick 数
    final bpm = score.bpm > 0 ? score.bpm : 500;
    final msPerTick = 60000.0 / (bpm * 480);
    final delayMs = (timeDiff * msPerTick / state.speed).round().clamp(10, 10000);

    DebugLog.d('播放 #${idx}: delay=${delayMs}ms '
        '(timeDiff=$timeDiff, bpm=$bpm, speed=${state.speed})');

    state = state.copyWith(currentEventIndex: nextIdx);

    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (state.status == PlaybackStatus.playing) {
        _scheduleNextEvent();
      }
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
