import 'note.dart';

/// 乐谱中的一个事件：可以是音符或休止
class ScoreEvent {
  /// 要按下的音符列表（休止符时为空）
  final List<Note> notes;

  /// 是否为休止符
  final bool isRest;

  /// 段落标记（如 "前奏"、"主歌A"），null表示无标记
  final String? section;

  const ScoreEvent({
    required this.notes,
    this.isRest = false,
    this.section,
  });

  factory ScoreEvent.rest({String? section}) {
    return ScoreEvent(notes: [], isRest: true, section: section);
  }

  factory ScoreEvent.note(List<Note> notes, {String? section}) {
    return ScoreEvent(notes: notes, isRest: false, section: section);
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

  /// 创建时间
  final DateTime createdAt;

  Score({
    required this.id,
    required this.name,
    required this.rawText,
    required this.events,
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
