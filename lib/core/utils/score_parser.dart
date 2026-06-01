import 'dart:convert';

import '../../models/note.dart';
import '../../models/score.dart';

/// 琴谱解析器 - 支持 JSON 格式
///
/// JSON 格式：
/// ```json
/// [{
///   "name": "曲目名",
///   "bpm": 500,
///   "songNotes": [
///     {"time": 1440, "key": "1Key5"},
///     {"time": 1920, "key": "1Key0"}
///   ]
/// }]
/// ```
///
/// Key 映射：
/// - Key0-4 = -1, -2, -3, -4, -5
/// - Key5-9 = -6, -7, 1, 2, 3
/// - Key10-14 = 4, 5, 6, 7, +1
class ScoreParser {
  // key 编号到音符名称的映射
  static const List<String> _keyToNote = [
    '-1', '-2', '-3', '-4', '-5',  // Key0-4
    '-6', '-7', '1', '2', '3',     // Key5-9
    '4', '5', '6', '7', '+1',      // Key10-14
  ];

  /// 解析琴谱文本为事件列表
  static List<ScoreEvent> parse(String text) {
    final events = <ScoreEvent>[];

    // 尝试解析 JSON 格式
    if (text.trimLeft().startsWith('[') || text.trimLeft().startsWith('{')) {
      return _parseJson(text);
    }

    // 其他格式暂不支持
    return events;
  }

  /// 解析 JSON 格式琴谱
  static List<ScoreEvent> _parseJson(String text) {
    final events = <ScoreEvent>[];

    try {
      // 清理文本中的特殊字符
      String cleanText = text.trim();

      // 处理可能的 BOM 和特殊空白字符
      cleanText = cleanText.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '');
      // 处理全角空格
      cleanText = cleanText.replaceAll('　', ' ');
      // 处理零宽字符
      cleanText = cleanText.replaceAll(RegExp(r'[​-‍﻿]'), '');

      final dynamic jsonData = jsonDecode(cleanText);

      List<dynamic> songList;

      if (jsonData is List) {
        songList = jsonData;
      } else if (jsonData is Map) {
        songList = [jsonData];
      } else {
        return events;
      }

      if (songList.isEmpty) return events;

      // 取第一首歌
      final song = songList[0] as Map<String, dynamic>;
      final songNotes = song['songNotes'] as List<dynamic>?;

      if (songNotes == null || songNotes.isEmpty) return events;

      // 按时间排序
      final sortedNotes = List<Map<String, dynamic>>.from(
        songNotes.map((n) => n as Map<String, dynamic>)
      );
      sortedNotes.sort((a, b) {
        final timeA = (a['time'] as num?)?.toInt() ?? 0;
        final timeB = (b['time'] as num?)?.toInt() ?? 0;
        return timeA.compareTo(timeB);
      });

      // 转换为事件列表
      int lastTime = 0;
      for (final note in sortedNotes) {
        final time = (note['time'] as num?)?.toInt() ?? 0;
        final key = note['key'] as String?;

        if (key == null) continue;

        // 如果有时间间隔，添加休止符
        if (time > lastTime + 100 && lastTime > 0) {
          events.add(ScoreEvent.rest());
        }

        // 解析 key
        final noteObj = _parseKey(key);
        if (noteObj != null) {
          events.add(ScoreEvent.note([noteObj]));
        }

        lastTime = time;
      }
    } catch (e) {
      // 解析失败返回空列表
      // JSON parse error
    }

    return events;
  }

  /// 解析 key 字符串为音符
  static Note? _parseKey(String key) {
    // 格式: "1Key0", "1Key5", "1Key10" 等
    // 提取数字部分
    final match = RegExp(r'Key(\d+)').firstMatch(key);
    if (match == null) return null;

    final keyIndex = int.tryParse(match.group(1)!);
    if (keyIndex == null || keyIndex < 0 || keyIndex >= _keyToNote.length) {
      return null;
    }

    return SkyNotes.findByName(_keyToNote[keyIndex]);
  }

  /// 从原始文本创建完整的Score对象
  static Score createScore({
    required String id,
    required String name,
    required String rawText,
  }) {
    final events = parse(rawText);

    // 如果没有指定名称，尝试从 JSON 中提取
    String scoreName = name;
    if (scoreName.isEmpty) {
      try {
        final jsonData = jsonDecode(rawText.trim());
        if (jsonData is List && jsonData.isNotEmpty) {
          scoreName = jsonData[0]['name']?.toString() ?? name;
        }
      } catch (_) {}
    }

    return Score(
      id: id,
      name: scoreName,
      rawText: rawText,
      events: events,
    );
  }
}
