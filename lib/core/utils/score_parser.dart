import '../../models/note.dart';
import '../../models/score.dart';

/// 琴谱解析器 - 将文本格式解析为乐谱对象
///
/// 格式说明：
/// - 数字 1-7 = 中音区音符
/// - -1 到 -7 = 低音区音符
/// - +1 = 高音区最高音
/// - 0 = 休止符
/// - / = 短停顿（八分休止）
/// - // = 长停顿（四分休止）
/// - //标题 = 段落标记
class ScoreParser {
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

      // 解析音符行
      final tokens = _tokenize(trimmed);
      for (final token in tokens) {
        if (token == '/') {
          // 短停顿
          events.add(ScoreEvent.rest(section: currentSection));
          currentSection = null;
        } else if (token == '//') {
          // 长停顿（两个休止符）
          events.add(ScoreEvent.rest(section: currentSection));
          events.add(ScoreEvent.rest());
          currentSection = null;
        } else if (token == '0') {
          // 休止符
          events.add(ScoreEvent.rest(section: currentSection));
          currentSection = null;
        } else {
          // 音符（可能有和弦，用空格分隔的多个音符）
          final noteNames = token.split(RegExp(r'\s+'));
          final notes = <Note>[];
          for (final name in noteNames) {
            final note = SkyNotes.findByName(name);
            if (note != null) {
              notes.add(note);
            }
          }
          if (notes.isNotEmpty) {
            events.add(ScoreEvent.note(notes, section: currentSection));
            currentSection = null;
          }
        }
      }
    }

    return events;
  }

  /// 将一行文本分词
  static List<String> _tokenize(String line) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    int i = 0;

    while (i < line.length) {
      final ch = line[i];

      if (ch == ' ') {
        // 空格：缓冲区内容作为一个token
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        i++;
        continue;
      }

      if (ch == '/') {
        // 斜杠：先保存缓冲区内容
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        // 计算连续斜杠数量
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
