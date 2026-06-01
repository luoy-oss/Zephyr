import 'dart:convert';

import '../../models/note.dart';
import '../../models/score.dart';
import 'debug_log.dart';

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
    DebugLog.divider('ScoreParser.parse');
    DebugLog.d('原始文本长度: ${text.length} 字符');
    DebugLog.d('文本前100字符: ${text.substring(0, text.length.clamp(0, 100))}');

    // 检测 BOM
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      DebugLog.w('检测到 BOM 头 (U+FEFF)，将在解析前移除');
    }

    // 尝试解析 JSON 格式
    if (text.trimLeft().startsWith('[') || text.trimLeft().startsWith('{')) {
      DebugLog.d('检测到 JSON 格式，开始解析');
      return _parseJson(text);
    }

    DebugLog.w('未识别的文本格式（非 JSON），返回空事件列表');
    return [];
  }

  /// 解析 JSON 格式琴谱
  static List<ScoreEvent> _parseJson(String text) {
    final events = <ScoreEvent>[];

    try {
      // 清理文本中的特殊字符
      String cleanText = text.trim();

      // 【修复】显式移除 BOM (U+FEFF)
      final hadBom = cleanText.startsWith('﻿');
      cleanText = cleanText.replaceAll('﻿', '');

      // 清理控制字符
      cleanText = cleanText.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '');
      // 处理全角空格
      cleanText = cleanText.replaceAll('　', ' ');
      // 处理零宽字符
      cleanText = cleanText.replaceAll(
        RegExp(r'[​‌‍‎‏⁠⁡⁢⁣]'),
        '',
      );

      DebugLog.d('文本清洗完成: hadBom=$hadBom, 清洗后长度=${cleanText.length}');
      DebugLog.block('清洗后文本前500字符', cleanText.substring(0, cleanText.length.clamp(0, 500)));

      final dynamic jsonData = jsonDecode(cleanText);
      DebugLog.d('JSON 解析成功，类型: ${jsonData.runtimeType}');

      List<dynamic> songList;

      if (jsonData is List) {
        songList = jsonData;
        DebugLog.d('JSON 是数组，包含 ${songList.length} 首歌曲');
      } else if (jsonData is Map) {
        songList = [jsonData];
        DebugLog.d('JSON 是单个对象，包装为数组');
      } else {
        DebugLog.e('JSON 类型不支持: ${jsonData.runtimeType}');
        return events;
      }

      if (songList.isEmpty) {
        DebugLog.w('歌曲列表为空');
        return events;
      }

      // 取第一首歌
      final song = songList[0] as Map<String, dynamic>;
      DebugLog.d('歌曲信息: name=${song['name']}, bpm=${song['bpm']}');
      DebugLog.d('歌曲 keys: ${song.keys.toList()}');

      final songNotes = song['songNotes'] as List<dynamic>?;

      if (songNotes == null || songNotes.isEmpty) {
        DebugLog.w('songNotes 为 null 或为空');
        return events;
      }

      DebugLog.d('songNotes 原始条目数: ${songNotes.length}');

      // 【修复】按时间分组，相同 time 的音符合并为和弦
      final Map<int, List<String>> timeGroups = {};
      for (final note in songNotes) {
        final noteMap = note as Map<String, dynamic>;
        final time = (noteMap['time'] as num?)?.toInt() ?? 0;
        final key = noteMap['key'] as String?;
        if (key == null) continue;
        timeGroups.putIfAbsent(time, () => []).add(key);
      }

      DebugLog.d('按 time 分组后共 ${timeGroups.length} 个时间点');

      // 打印前几个时间点的详细信息
      final sortedTimes = timeGroups.keys.toList()..sort();
      final previewCount = sortedTimes.length.clamp(0, 10);
      for (var i = 0; i < previewCount; i++) {
        final time = sortedTimes[i];
        final keys = timeGroups[time]!;
        DebugLog.d('  time=$time, keys=$keys (${keys.length}个音符)');
      }
      if (sortedTimes.length > previewCount) {
        DebugLog.d('  ... 还有 ${sortedTimes.length - previewCount} 个时间点');
      }

      // 【修复】转换为事件列表，不自动插入休止符
      for (final time in sortedTimes) {
        final keys = timeGroups[time]!;
        final notes = <Note>[];

        for (final key in keys) {
          final noteObj = _parseKey(key);
          if (noteObj != null) {
            notes.add(noteObj);
          } else {
            DebugLog.w('无法解析 key: $key');
          }
        }

        if (notes.isNotEmpty) {
          // 多个音符 → 和弦事件；单个音符 → 单音事件
          events.add(ScoreEvent.note(notes));
        }
      }

      DebugLog.i('解析完成: 共 ${events.length} 个事件');
      DebugLog.d('其中和弦事件: ${events.where((e) => e.notes.length > 1).length} 个');
      DebugLog.d('其中单音事件: ${events.where((e) => e.notes.length == 1).length} 个');

      // 打印前几个事件详情
      final eventPreview = events.length.clamp(0, 8);
      for (var i = 0; i < eventPreview; i++) {
        final e = events[i];
        DebugLog.d('  事件[$i]: notes=${e.notes.map((n) => n.name).toList()}');
      }

    } catch (e, stackTrace) {
      DebugLog.e('JSON 解析失败', e, stackTrace);
    }

    DebugLog.divider();
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
      DebugLog.w('keyIndex 越界: key=$key, index=$keyIndex');
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
    DebugLog.divider('ScoreParser.createScore');
    DebugLog.d('id=$id, name=$name');

    final events = parse(rawText);

    // 如果没有指定名称，尝试从 JSON 中提取；同时提取 BPM
    String scoreName = name;
    int bpm = 500;
    try {
      String cleanText = rawText.trim().replaceAll('﻿', '');
      final jsonData = jsonDecode(cleanText);
      if (jsonData is List && jsonData.isNotEmpty) {
        final song = jsonData[0];
        if (scoreName.isEmpty) {
          scoreName = song['name']?.toString() ?? name;
          DebugLog.d('从 JSON 中提取到名称: $scoreName');
        }
        bpm = (song['bpm'] as num?)?.toInt() ?? 500;
        DebugLog.d('从 JSON 中提取到 BPM: $bpm');
      }
    } catch (_) {}

    DebugLog.i('创建 Score: name=$scoreName, bpm=$bpm, events=${events.length}');
    DebugLog.divider();

    return Score(
      id: id,
      name: scoreName,
      rawText: rawText,
      events: events,
      bpm: bpm,
    );
  }
}
