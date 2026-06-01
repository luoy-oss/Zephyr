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

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  bool _hasAccessibility = false;
  bool _hasOverlay = false;
  bool _isFloatingRunning = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isChecking = true);

    final accessibility = await NativeService.checkAccessibility();
    final overlay = await NativeService.checkOverlayPermission();
    final floatingRunning = await NativeService.isFloatingWindowRunning();

    if (mounted) {
      setState(() {
        _hasAccessibility = accessibility;
        _hasOverlay = overlay;
        _isFloatingRunning = floatingRunning;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoreState = ref.watch(scoreListProvider);
    final playbackState = ref.watch(playbackProvider);
    final filteredScores = ref.watch(filteredScoresProvider);

    // 权限检查中显示加载状态
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('检查权限中...'),
            ],
          ),
        ),
      );
    }

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
            onPressed: _hasOverlay
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
                    )
                : () => _showPermissionDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 悬浮窗开关卡片
          _buildFloatingToggleCard(),

          // 权限提示
          if (!_hasAccessibility || !_hasOverlay)
            _buildPermissionBanner(),

          // 搜索栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildFloatingToggleCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isFloatingRunning
            ? AppColors.primary.withOpacity(0.2)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFloatingRunning ? AppColors.primary : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isFloatingRunning ? Icons.circle : Icons.circle_outlined,
            color: _isFloatingRunning ? Colors.green : AppColors.textSecondary,
            size: 12,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '悬浮窗控制',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _isFloatingRunning ? '运行中 - 点击小球展开控制面板' : '已关闭',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isFloatingRunning,
            activeColor: AppColors.primary,
            onChanged: (value) async {
              if (value) {
                // 检查权限
                if (!_hasOverlay) {
                  _showPermissionDialog();
                  return;
                }
                if (!_hasAccessibility) {
                  _showPermissionDialog();
                  return;
                }
                await NativeService.startFloatingWindow();
              } else {
                await NativeService.stopFloatingWindow();
              }
              // 延迟检查状态
              await Future.delayed(const Duration(milliseconds: 500));
              _checkAllPermissions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: AppColors.error, size: 20),
              SizedBox(width: 8),
              Text(
                '需要授予权限',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_hasAccessibility)
            _buildPermissionItem(
              icon: Icons.accessibility_new,
              title: '无障碍权限',
              subtitle: '用于模拟屏幕点击',
              onTap: () => NativeService.openAccessibilitySettings(),
            ),
          if (!_hasOverlay)
            _buildPermissionItem(
              icon: Icons.layers,
              title: '悬浮窗权限',
              subtitle: '用于在游戏上层显示控制面板',
              onTap: () => NativeService.requestOverlayPermission(),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(icon, color: AppColors.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.error),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedScoreBar(dynamic scoreState, PlaybackState playbackState) {
    final score = scoreState.selectedScore!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
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
          if (playbackState.status != PlaybackStatus.idle)
            LinearProgressIndicator(
              value: playbackState.progress,
              backgroundColor: AppColors.card,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (playbackState.status == PlaybackStatus.countdown)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '${playbackState.countdownRemaining}秒后开始',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              IconButton(
                iconSize: 36,
                icon: Icon(
                  playbackState.status == PlaybackStatus.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: _isFloatingRunning ? AppColors.primary : AppColors.textSecondary,
                ),
                onPressed: _isFloatingRunning
                    ? () {
                        final notifier = ref.read(playbackProvider.notifier);
                        if (playbackState.status == PlaybackStatus.playing) {
                          notifier.pause();
                        } else {
                          notifier.setOnNoteEvent(_onNoteEvent);
                          notifier.play();
                        }
                      }
                    : null,
              ),
              if (playbackState.status != PlaybackStatus.idle)
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.stop_circle, color: AppColors.error),
                  onPressed: () {
                    ref.read(playbackProvider.notifier).stop();
                  },
                ),
              const SizedBox(width: 16),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 16),
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
        title: const Text('需要权限'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zephyr 需要以下权限才能正常工作：'),
            const SizedBox(height: 16),
            if (!_hasAccessibility) ...[
              ListTile(
                leading: const Icon(Icons.accessibility_new, color: AppColors.primary),
                title: const Text('无障碍权限'),
                subtitle: const Text('用于模拟屏幕点击'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  NativeService.openAccessibilitySettings();
                  Navigator.pop(context);
                },
              ),
            ],
            if (!_hasOverlay) ...[
              ListTile(
                leading: const Icon(Icons.layers, color: AppColors.primary),
                title: const Text('悬浮窗权限'),
                subtitle: const Text('用于在游戏上层显示'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  NativeService.requestOverlayPermission();
                  Navigator.pop(context);
                },
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '授予权限后返回应用，状态会自动更新',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
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
      final note = notes[0];
      final x = config.getX(note.col);
      final y = config.getY(note.row);
      NativeService.tap(x, y, config.tapDurationMs);
    } else if (notes.length > 1) {
      final points = notes.map<List<double>>((note) => [
        config.getX(note.col),
        config.getY(note.row),
      ]).toList();
      NativeService.tapMultiple(points, config.tapDurationMs);
    }
  }
}
