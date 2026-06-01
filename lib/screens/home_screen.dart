import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../providers/score_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/settings_provider.dart';
import '../services/accessibility_service.dart';
import '../widgets/score_card.dart';
import 'settings_screen.dart';
import 'calibration_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasAccessibility = false;
  bool _hasOverlay = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final accessibility = await NativeService.checkAccessibility();
    final overlay = await NativeService.checkOverlayPermission();
    if (mounted) {
      setState(() {
        _hasAccessibility = accessibility;
        _hasOverlay = overlay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoreState = ref.watch(scoreListProvider);
    final playbackState = ref.watch(playbackProvider);
    final filteredScores = ref.watch(filteredScoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        actions: [
          // 权限状态指示
          if (!_hasAccessibility || !_hasOverlay)
            IconButton(
              icon: const Icon(Icons.warning, color: AppColors.error),
              onPressed: _showPermissionDialog,
              tooltip: '权限不足',
            ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          // 校准按钮
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalibrationScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppStrings.searchScore,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // 当前选中的乐谱信息
          if (scoreState.selectedScore != null)
            _buildSelectedScoreBar(scoreState, playbackState),

          // 乐谱列表
          Expanded(
            child: scoreState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredScores.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredScores.length,
                        itemBuilder: (context, index) {
                          final score = filteredScores[index];
                          final isSelected = score.id == scoreState.selectedId;
                          return ScoreCard(
                            score: score,
                            isSelected: isSelected,
                            onTap: () {
                              ref.read(scoreListProvider.notifier).selectScore(score.id);
                            },
                            onDelete: () => _confirmDelete(score.id, score.name),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importScore,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSelectedScoreBar(dynamic scoreState, PlaybackState playbackState) {
    final score = scoreState.selectedScore!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 乐谱名称和进度
          Row(
            children: [
              Expanded(
                child: Text(
                  score.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (playbackState.status != PlaybackStatus.idle)
                Text(
                  '${playbackState.currentEventIndex}/${playbackState.totalEvents}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 进度条
          if (playbackState.status != PlaybackStatus.idle)
            LinearProgressIndicator(
              value: playbackState.progress,
              backgroundColor: AppColors.card,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          const SizedBox(height: 8),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 倒计时显示
              if (playbackState.status == PlaybackStatus.countdown)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '${playbackState.countdownRemaining}${AppStrings.countdownStart}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),

              // 播放/暂停按钮
              IconButton(
                iconSize: 36,
                icon: Icon(
                  playbackState.status == PlaybackStatus.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  final notifier = ref.read(playbackProvider.notifier);
                  if (playbackState.status == PlaybackStatus.playing) {
                    notifier.pause();
                  } else {
                    notifier.setOnNoteEvent(_onNoteEvent);
                    notifier.play();
                  }
                },
              ),

              // 停止按钮
              if (playbackState.status != PlaybackStatus.idle)
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.stop_circle, color: AppColors.error),
                  onPressed: () {
                    ref.read(playbackProvider.notifier).stop();
                  },
                ),

              const SizedBox(width: 16),

              // 速度调节
              const Text('速度:'),
              SizedBox(
                width: 100,
                child: Slider(
                  value: playbackState.speed,
                  min: 0.25,
                  max: 3.0,
                  divisions: 11,
                  label: '${playbackState.speed.toStringAsFixed(2)}x',
                  onChanged: (value) {
                    ref.read(playbackProvider.notifier).setSpeed(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            AppStrings.noScores,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _importScore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content;

        if (file.bytes != null) {
          content = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          final fileObj = await File(file.path!).readAsBytes();
          content = String.fromCharCodes(fileObj);
        } else {
          return;
        }

        // 使用文件名作为乐谱名称
        final name = file.name.replaceAll('.txt', '');
        await ref.read(scoreListProvider.notifier).importScore(name, content);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导入: $name')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteScore),
        content: Text('${AppStrings.deleteConfirm}\n$name'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(scoreListProvider.notifier).deleteScore(id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.permissionRequired),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_hasAccessibility) ...[
              const Text(AppStrings.accessibilityDesc),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  NativeService.openAccessibilitySettings();
                  Navigator.pop(context);
                },
                child: const Text('${AppStrings.grantPermission} - ${AppStrings.accessibilityPermission}'),
              ),
            ],
            if (!_hasOverlay) ...[
              const SizedBox(height: 16),
              const Text(AppStrings.overlayDesc),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  NativeService.requestOverlayPermission();
                  Navigator.pop(context);
                },
                child: const Text('${AppStrings.grantPermission} - ${AppStrings.overlayPermission}'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 音符事件回调 - 执行实际的屏幕点击
  void _onNoteEvent(dynamic event) {
    final config = ref.read(settingsProvider);
    final notes = event.notes as List;

    if (notes.length == 1) {
      // 单音符
      final note = notes[0];
      final x = config.getX(note.col);
      final y = config.getY(note.row);
      NativeService.tap(x, y, config.tapDurationMs);
    } else if (notes.length > 1) {
      // 和弦 - 同时点击多个位置
      final points = notes.map<List<double>>((note) => [
        config.getX(note.col),
        config.getY(note.row),
      ]).toList();
      NativeService.tapMultiple(points, config.tapDurationMs);
    }
  }
}
