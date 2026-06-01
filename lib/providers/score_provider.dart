import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/score.dart';
import '../core/utils/score_parser.dart';

/// 乐谱列表状态
class ScoreListState {
  final List<Score> scores;
  final String? selectedId;
  final bool isLoading;

  const ScoreListState({
    this.scores = const [],
    this.selectedId,
    this.isLoading = false,
  });

  Score? get selectedScore =>
      selectedId != null ? scores.where((s) => s.id == selectedId).firstOrNull : null;

  ScoreListState copyWith({
    List<Score>? scores,
    String? selectedId,
    bool? isLoading,
  }) {
    return ScoreListState(
      scores: scores ?? this.scores,
      selectedId: selectedId ?? this.selectedId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 乐谱列表管理
class ScoreListNotifier extends StateNotifier<ScoreListState> {
  static const _uuid = Uuid();
  static const _storageFileName = 'scores.json';

  ScoreListNotifier() : super(const ScoreListState()) {
    _loadScores();
  }

  /// 获取存储目录
  Future<Directory> get _storageDir async {
    final dir = await getApplicationDocumentsDirectory();
    final scoresDir = Directory('${dir.path}/scores');
    if (!await scoresDir.exists()) {
      await scoresDir.create(recursive: true);
    }
    return scoresDir;
  }

  /// 加载已保存的乐谱
  Future<void> _loadScores() async {
    state = state.copyWith(isLoading: true);
    try {
      final dir = await _storageDir;
      final indexFile = File('${dir.path}/$_storageFileName');
      if (await indexFile.exists()) {
        final json = jsonDecode(await indexFile.readAsString()) as List;
        final scores = json.map((e) => Score(
          id: e['id'],
          name: e['name'],
          rawText: e['rawText'],
          events: ScoreParser.parse(e['rawText']),
          createdAt: DateTime.parse(e['createdAt']),
        )).toList();
        state = state.copyWith(scores: scores, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 保存乐谱索引
  Future<void> _saveIndex() async {
    final dir = await _storageDir;
    final indexFile = File('${dir.path}/$_storageFileName');
    final json = state.scores.map((s) => {
      'id': s.id,
      'name': s.name,
      'rawText': s.rawText,
      'createdAt': s.createdAt.toIso8601String(),
    }).toList();
    await indexFile.writeAsString(jsonEncode(json));
  }

  /// 导入琴谱文本
  Future<Score> importScore(String name, String rawText) async {
    final id = _uuid.v4();
    final score = ScoreParser.createScore(
      id: id,
      name: name,
      rawText: rawText,
    );
    state = state.copyWith(scores: [...state.scores, score]);
    await _saveIndex();
    return score;
  }

  /// 删除乐谱
  Future<void> deleteScore(String id) async {
    state = state.copyWith(
      scores: state.scores.where((s) => s.id != id).toList(),
      selectedId: state.selectedId == id ? null : state.selectedId,
    );
    await _saveIndex();
  }

  /// 选择乐谱
  void selectScore(String? id) {
    state = state.copyWith(selectedId: id);
  }
}

/// 乐谱列表 Provider
final scoreListProvider =
    StateNotifierProvider<ScoreListNotifier, ScoreListState>((ref) {
  return ScoreListNotifier();
});

/// 搜索关键词 Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 过滤后的乐谱列表
final filteredScoresProvider = Provider<List<Score>>((ref) {
  final scores = ref.watch(scoreListProvider).scores;
  final query = ref.watch(searchQueryProvider).toLowerCase();
  if (query.isEmpty) return scores;
  return scores.where((s) => s.name.toLowerCase().contains(query)).toList();
});
