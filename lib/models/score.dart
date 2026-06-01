import 'note.dart';

/// 乐谱中的一个事件：可以是音符或休止
class ScoreEvent {
  /// 要按下的音符列表（休止符时为空）
  final List<Note> notes;

  /// 是否为休止符
  final bool isRest;

  /// 段落标记（如 "前奏"、"主歌A"），null表示无标记
  final String? section;

  /// 时间戳（原始 JSON 中的 time 值，用于计算事件间隔）
  final int time;

  const ScoreEvent({
    required this.notes,
    this.isRest = false,
    this.section,
    this.time = 0,
  });

  factory ScoreEvent.rest({String? section, int time = 0}) {
    return ScoreEvent(notes: [], isRest: true, section: section, time: time);
  }

  factory ScoreEvent.note(List<Note> notes, {String? section, int time = 0}) {
    return ScoreEvent(notes: notes, isRest: false, section: section, time: time);
  }
}

/// 完整乐谱模型
class Score {
  /// 唯一ID
  final String id;

  /// 乐谱名称
  final String name;

  /// 原始文本内容
  final String rawText;

  /// 解析后的事件列表
  final List<ScoreEvent> events;

  /// 乐曲 BPM（从 JSON 中解析，默认 500）
  final int bpm;

  /// 创建时间
  final DateTime createdAt;

  Score({
    required this.id,
    required this.name,
    required this.rawText,
    required this.events,
    this.bpm = 500,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 总事件数
  int get eventCount => events.length;

  /// 总音符数（不含休止符）
  int get noteCount => events.where((e) => !e.isRest).length;

  /// 获取所有段落标记
  List<String> get sections =>
      events.where((e) => e.section != null).map((e) => e.section!).toList();
}
