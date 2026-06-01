import '../../models/note.dart';
import '../../models/score.dart';

/// 琴谱解析器 - 支持多种格式
///
/// 支持格式：
/// 1. keyX 格式（如 key0, key5-9）
///    - key0-4 = -1, -2, -3, -4, -5
///    - key5-9 = -6, -7, 1, 2, 3
///    - key10-14 = 4, 5, 6, 7, +1
///
/// 2. 数字格式（如 1, -1, +1）
/// 3. / = 短停顿，// = 长停顿
/// 4. //标题 = 段落标记
class ScoreParser {
  // key 编号到音符名称的映射
  static const List<String> _keyToNote = [
    '-1', '-2', '-3', '-4', '-5',  // key0-4
    '-6', '-7', '1', '2', '3',     // key5-9
    '4', '5', '6', '7', '+1',      // key10-14
  ];

  /// 解析琴谱文本为事件列表
  static List<ScoreEvent> parse(String text) {
    final events = <ScoreEvent>[];
    final lines = text.split('\n');

    String? currentSection;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 检查段落标记（行首为 //）
      if (trimmed.startsWith('//') && !trimmed.startsWith('///')) {
        currentSection = trimmed.substring(2).trim();
        continue;
      }

      // 跳过非音符行（如 1keyx 等配置行）
      if (trimmed.contains('keyx') || trimmed.contains('keyX')) {
        continue;
      }

      // 解析音符行
      final tokens = _tokenize(trimmed);
      for (final token in tokens) {
        if (token == '/') {
          events.add(ScoreEvent.rest(section: currentSection));
          currentSection = null;
        } else if (token == '//') {
          events.add(ScoreEvent.rest(section: currentSection));
          events.add(ScoreEvent.rest());
          currentSection = null;
        } else if (token == '0') {
          events.add(ScoreEvent.rest(section: currentSection));
          currentSection = null;
        } else {
          // 尝试解析为 key 格式或数字格式
          final notes = _parseToken(token);
          if (notes.isNotEmpty) {
            events.add(ScoreEvent.note(notes, section: currentSection));
            currentSection = null;
          }
        }
      }
    }

    return events;
  }

  /// 解析单个 token 为音符列表
  static List<Note> _parseToken(String token) {
    final notes = <Note>[];

    // 尝试解析 key 格式
    if (token.startsWith('key')) {
      final keyPart = token.substring(3);

      // 检查是否是范围（如 key0-4）
      if (keyPart.contains('-')) {
        final parts = keyPart.split('-');
        if (parts.length == 2) {
          final start = int.tryParse(parts[0]);
          final end = int.tryParse(parts[1]);
          if (start != null && end != null) {
            for (int i = start; i <= end && i < _keyToNote.length; i++) {
              if (i >= 0) {
                final note = SkyNotes.findByName(_keyToNote[i]);
                if (note != null) notes.add(note);
              }
            }
          }
        }
      } else {
        // 单个 key（如 key0）
        final keyIndex = int.tryParse(keyPart);
        if (keyIndex != null && keyIndex >= 0 && keyIndex < _keyToNote.length) {
          final note = SkyNotes.findByName(_keyToNote[keyIndex]);
          if (note != null) notes.add(note);
        }
      }
      return notes;
    }

    // 尝试解析数字格式（1, -1, +1 等）
    final note = SkyNotes.findByName(token);
    if (note != null) {
      notes.add(note);
    }

    return notes;
  }

  /// 将一行文本分词
  static List<String> _tokenize(String line) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    int i = 0;

    while (i < line.length) {
      final ch = line[i];

      if (ch == ' ' || ch == '\t') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        i++;
        continue;
      }

      if (ch == '/') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        int slashCount = 0;
        while (i < line.length && line[i] == '/') {
          slashCount++;
          i++;
        }
        tokens.add('/' * slashCount);
        continue;
      }

      buffer.write(ch);
      i++;
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// 从原始文本创建完整的Score对象
  static Score createScore({
    required String id,
    required String name,
    required String rawText,
  }) {
    final events = parse(rawText);
    return Score(
      id: id,
      name: name,
      rawText: rawText,
      events: events,
    );
  }
}
