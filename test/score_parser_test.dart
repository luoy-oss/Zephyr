import 'dart:convert';
import 'dart:io';

/// 模拟 ScoreParser 的核心逻辑进行本地测试
/// 不依赖 Flutter，纯 Dart 运行

const List<String> _keyToNote = [
  '-1', '-2', '-3', '-4', '-5',
  '-6', '-7', '1', '2', '3',
  '4', '5', '6', '7', '+1',
];

String? parseKey(String key) {
  final match = RegExp(r'Key(\d+)').firstMatch(key);
  if (match == null) return null;
  final keyIndex = int.tryParse(match.group(1)!);
  if (keyIndex == null || keyIndex < 0 || keyIndex >= _keyToNote.length) {
    return null;
  }
  return _keyToNote[keyIndex];
}

void main() {
  final filePath = '${Directory.current.path}/多情种(1).txt';
  print('=== 琴谱解析测试 ===');
  print('文件路径: $filePath\n');

  // 1. 读取原始字节
  final bytes = File(filePath).readAsBytesSync();
  print('原始字节长度: ${bytes.length}');
  print('前20字节 hex: ${bytes.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

  // 2. 检测编码
  bool isUtf16Le = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE;
  bool isUtf16Be = bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF;
  bool isUtf8Bom = bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;

  print('编码检测:');
  print('  UTF-16 LE BOM: $isUtf16Le');
  print('  UTF-16 BE BOM: $isUtf16Be');
  print('  UTF-8 BOM:     $isUtf8Bom');

  // 3. 正确解码
  String text;
  if (isUtf16Le) {
    print('\n使用 UTF-16 LE 解码...');
    text = decodeUtf16Le(bytes);
  } else if (isUtf16Be) {
    print('\n使用 UTF-16 BE 解码...');
    text = decodeUtf16Be(bytes);
  } else {
    print('\n使用 UTF-8 解码...');
    text = utf8.decode(bytes, allowMalformed: true);
  }

  print('解码后文本长度: ${text.length} 字符');
  print('前80字符: ${text.substring(0, text.length.clamp(0, 80))}');

  // 4. 模拟旧代码的问题
  print('\n=== 旧代码问题演示 ===');
  final brokenText = String.fromCharCodes(bytes);
  print('String.fromCharCodes 结果长度: ${brokenText.length}');
  print('前80字符: "${brokenText.substring(0, brokenText.length.clamp(0, 80))}"');
  print('注意: 每个字符间有空格，因为 UTF-16 的高字节被当作独立字符');

  // 5. 清洗文本
  String cleanText = text.trim();
  cleanText = cleanText.replaceAll('﻿', '');
  cleanText = cleanText.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '');
  cleanText = cleanText.replaceAll('　', ' ');
  cleanText = cleanText.replaceAll(
    RegExp(r'[​‌‍‎‏⁠⁡⁢⁣]'),
    '',
  );

  print('\n=== JSON 解析 ===');
  print('清洗后文本前100字符: ${cleanText.substring(0, cleanText.length.clamp(0, 100))}');

  // 6. 解析 JSON
  final dynamic jsonData = jsonDecode(cleanText);
  List<dynamic> songList;
  if (jsonData is List) {
    songList = jsonData;
  } else if (jsonData is Map) {
    songList = [jsonData];
  } else {
    print('JSON 类型不支持: ${jsonData.runtimeType}');
    return;
  }

  final song = songList[0] as Map<String, dynamic>;
  print('歌曲名: ${song['name']}');
  print('BPM: ${song['bpm']}');
  print('songNotes 条目数: ${(song['songNotes'] as List).length}');

  // 7. 按 time 分组（修复后的逻辑）
  final songNotes = song['songNotes'] as List<dynamic>;
  final Map<int, List<String>> timeGroups = {};
  for (final note in songNotes) {
    final noteMap = note as Map<String, dynamic>;
    final time = (noteMap['time'] as num?)?.toInt() ?? 0;
    final key = noteMap['key'] as String?;
    if (key == null) continue;
    timeGroups.putIfAbsent(time, () => []).add(key);
  }

  final sortedTimes = timeGroups.keys.toList()..sort();
  print('\n按 time 分组后共 ${sortedTimes.length} 个时间点');

  // 8. 转换为事件
  int chordCount = 0;
  int singleCount = 0;
  int failCount = 0;
  final events = <Map<String, dynamic>>[];

  for (final time in sortedTimes) {
    final keys = timeGroups[time]!;
    final notes = <String>[];

    for (final key in keys) {
      final noteName = parseKey(key);
      if (noteName != null) {
        notes.add(noteName);
      } else {
        failCount++;
        print('  ⚠️ 无法解析 key: $key (time=$time)');
      }
    }

    if (notes.isNotEmpty) {
      if (notes.length > 1) chordCount++;
      else singleCount++;
      events.add({'time': time, 'notes': notes});
    }
  }

  print('\n=== 解析结果 ===');
  print('总事件数: ${events.length}');
  print('和弦事件: $chordCount');
  print('单音事件: $singleCount');
  print('解析失败: $failCount');

  // 9. 打印前20个事件
  print('\n前20个事件:');
  for (var i = 0; i < events.length.clamp(0, 20); i++) {
    final e = events[i];
    final notes = e['notes'] as List<String>;
    final label = notes.length > 1 ? '🎵和弦' : '  单音';
    print('  [$i] ${e['time']} $label ${notes.join(" + ")}');
  }

  // 10. 与旧代码对比
  print('\n=== 旧代码 vs 新代码对比 ===');
  int oldRestCount = 0;
  int oldEventCount = 0;
  int lastTime = 0;
  for (final note in songNotes) {
    final noteMap = note as Map<String, dynamic>;
    final time = (noteMap['time'] as num?)?.toInt() ?? 0;
    final key = noteMap['key'] as String?;
    if (key == null) continue;

    if (time > lastTime + 100 && lastTime > 0) {
      oldRestCount++;
    }
    oldEventCount++;
    lastTime = time;
  }
  print('旧代码: $oldEventCount 个事件 (含 $oldRestCount 个虚假休止符)');
  print('新代码: ${events.length} 个事件 (无休止符，和弦正确合并)');

  print('\n✅ 测试完成');
}

/// UTF-16 LE 解码
String decodeUtf16Le(List<int> bytes) {
  final codeUnits = <int>[];
  for (var i = 0; i < bytes.length - 1; i += 2) {
    codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
  }
  // 移除 BOM
  if (codeUnits.isNotEmpty && codeUnits[0] == 0xFEFF) {
    codeUnits.removeAt(0);
  }
  return String.fromCharCodes(codeUnits);
}

/// UTF-16 BE 解码
String decodeUtf16Be(List<int> bytes) {
  final codeUnits = <int>[];
  for (var i = 0; i < bytes.length - 1; i += 2) {
    codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
  }
  if (codeUnits.isNotEmpty && codeUnits[0] == 0xFEFF) {
    codeUnits.removeAt(0);
  }
  return String.fromCharCodes(codeUnits);
}
