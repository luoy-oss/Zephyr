import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/debug_log.dart';
import '../providers/score_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/settings_provider.dart';
import '../services/accessibility_service.dart';
import '../widgets/score_card.dart';
import '../widgets/glass_container.dart';
import 'settings_screen.dart';

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
  bool _callbacksSet = false;

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

      if (floatingRunning && (!accessibility || !overlay)) {
        await NativeService.stopFloatingWindow();
        if (mounted) {
          setState(() {
            _isFloatingRunning = false;
            _callbacksSet = false;
          });
          _showSnackBar('权限不足，悬浮窗已自动关闭', isError: true);
        }
        return;
      }

      if (floatingRunning && !_callbacksSet) {
        _setupFloatingCallbacks();
      }
    }
  }

  void _setupFloatingCallbacks() {
    NativeService.setFloatingCallbacks(
      onPlay: () {
        final notifier = ref.read(playbackProvider.notifier);
        notifier.setOnNoteEvent(_onNoteEvent);
        notifier.play();
      },
      onPause: () => ref.read(playbackProvider.notifier).pause(),
      onStop: () => ref.read(playbackProvider.notifier).stop(),
      onSelectScore: (id) => ref.read(scoreListProvider.notifier).selectScore(id),
      onCalibrationChanged: (baseX, baseY, colSpacing, rowSpacing) {
        ref.read(settingsProvider.notifier).updateConfig(
          ref.read(settingsProvider).copyWith(
            baseX: baseX, baseY: baseY,
            columnSpacing: colSpacing, rowSpacing: rowSpacing,
          ),
        );
      },
      onPanelOpened: () {
        // 悬浮窗面板打开时暂停播放
        final playbackState = ref.read(playbackProvider);
        if (playbackState.status == PlaybackStatus.playing) {
          ref.read(playbackProvider.notifier).pause();
          DebugLog.d('悬浮窗面板打开，自动暂停播放');
        }
      },
    );
    _callbacksSet = true;
    _syncDataToFloating();
  }

  void _syncDataToFloating() {
    final scores = ref.read(scoreListProvider).scores;
    NativeService.updateScoreList(
      scores.map((s) => {'id': s.id, 'name': s.name}).toList(),
    );
    final selectedScore = ref.read(scoreListProvider).selectedScore;
    if (selectedScore != null) {
      NativeService.updateSelectedScore(selectedScore.name);
    }
    final config = ref.read(settingsProvider);
    NativeService.updateFloatingConfig(
      config.baseX, config.baseY, config.columnSpacing, config.rowSpacing,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scoreState = ref.watch(scoreListProvider);
    final playbackState = ref.watch(playbackProvider);
    final filteredScores = ref.watch(filteredScoresProvider);

    ref.listen(scoreListProvider, (prev, next) {
      if (_isFloatingRunning) {
        NativeService.updateScoreList(
          next.scores.map((s) => {'id': s.id, 'name': s.name}).toList(),
        );
        if (next.selectedScore != null) {
          NativeService.updateSelectedScore(next.selectedScore!.name);
        }
      }
    });

    ref.listen(playbackProvider, (prev, next) {
      if (_isFloatingRunning) {
        NativeService.updateProgress(next.currentEventIndex, next.totalEvents);

        // 倒计时同步到悬浮窗覆盖层
        if (next.status == PlaybackStatus.countdown) {
          if (prev?.status != PlaybackStatus.countdown) {
            // 倒计时开始
            NativeService.showCountdown(next.countdownRemaining);
          } else {
            // 倒计时更新
            NativeService.updateCountdown(next.countdownRemaining);
          }
        } else if (prev?.status == PlaybackStatus.countdown) {
          // 倒计时结束
          NativeService.hideCountdown();
        }
      }
    });

    if (_isChecking) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.gradientSurface),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('检查权限中...', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部栏
              _buildAppBar(),

              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // 悬浮窗开关
                    SliverToBoxAdapter(child: _buildFloatingToggleCard()),

                    // 权限提示
                    if (!_hasAccessibility || !_hasOverlay)
                      SliverToBoxAdapter(child: _buildPermissionBanner()),

                    // 使用提示
                    if (_isFloatingRunning)
                      SliverToBoxAdapter(child: _buildInfoCard()),

                    // 搜索栏
                    SliverToBoxAdapter(child: _buildSearchBar()),

                    // 播放控制
                    if (scoreState.selectedScore != null)
                      SliverToBoxAdapter(
                        child: _buildPlaybackCard(scoreState, playbackState),
                      ),

                    // 乐谱列表标题
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          '琴谱列表',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // 乐谱列表
                    if (scoreState.isLoading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (filteredScores.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState())
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final score = filteredScores[index];
                            final isSelected = score.id == scoreState.selectedId;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ScoreCard(
                                score: score,
                                isSelected: isSelected,
                                onTap: () {
                                  ref.read(scoreListProvider.notifier).selectScore(score.id);
                                  if (_isFloatingRunning) {
                                    NativeService.updateSelectedScore(score.name);
                                  }
                                },
                                onDelete: () => _confirmDelete(score.id, score.name),
                              ),
                            );
                          },
                          childCount: filteredScores.length,
                        ),
                      ),

                    // 底部间距
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          // Logo 和标题
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zephyr',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'Auto Piano Player',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),

          // 权限警告
          if (!_hasAccessibility || !_hasOverlay)
            IconButton(
              icon: const Icon(Icons.warning_rounded, color: AppColors.warning),
              onPressed: _showPermissionDialog,
              tooltip: '权限不足',
            ),

          // 设置按钮
          _buildGlassIconButton(
            icon: Icons.settings_rounded,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.textSecondary, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildFloatingToggleCard() {
    final canToggle = _hasAccessibility && _hasOverlay;
    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // 状态指示灯
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isFloatingRunning ? AppColors.success : AppColors.textTertiary,
              shape: BoxShape.circle,
              boxShadow: _isFloatingRunning
                  ? [BoxShadow(color: AppColors.success.withOpacity(0.5), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '悬浮窗控制',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canToggle
                      ? (_isFloatingRunning ? '运行中 · 点击悬浮球打开面板' : '已关闭')
                      : '需要先授予权限',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 开关
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: _isFloatingRunning,
              activeColor: AppColors.success,
              activeTrackColor: AppColors.success.withOpacity(0.3),
              inactiveThumbColor: AppColors.textTertiary,
              inactiveTrackColor: AppColors.glassBg,
              onChanged: canToggle
                  ? (value) async {
                      if (value) {
                        await NativeService.startFloatingWindow();
                        await Future.delayed(const Duration(milliseconds: 500));
                        await _checkAllPermissions();
                        if (_isFloatingRunning) _setupFloatingCallbacks();
                      } else {
                        await NativeService.stopFloatingWindow();
                        setState(() {
                          _isFloatingRunning = false;
                          _callbacksSet = false;
                        });
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      color: AppColors.warning.withOpacity(0.1),
      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Text(
                '需要授予权限',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_hasAccessibility)
            _buildPermissionItem(
              icon: Icons.accessibility_new_rounded,
              title: '无障碍权限',
              subtitle: '用于模拟屏幕点击',
              onTap: () => NativeService.openAccessibilitySettings(),
            ),
          if (!_hasOverlay)
            _buildPermissionItem(
              icon: Icons.layers_rounded,
              title: '悬浮窗权限',
              subtitle: '用于在游戏上层显示',
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '悬浮窗已开启，点击悬浮球打开控制面板',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: TextField(
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '搜索琴谱...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackCard(dynamic scoreState, PlaybackState playbackState) {
    final score = scoreState.selectedScore!;
    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 曲目信息
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (playbackState.status != PlaybackStatus.idle)
                      Text(
                        '${playbackState.currentEventIndex} / ${playbackState.totalEvents}',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // 进度条
          if (playbackState.status != PlaybackStatus.idle) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: playbackState.progress,
                backgroundColor: AppColors.glassBg,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ],

          // 倒计时
          if (playbackState.status == PlaybackStatus.countdown) ...[
            const SizedBox(height: 16),
            Text(
              '${playbackState.countdownRemaining}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Text(
              '秒后开始',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],

          const SizedBox(height: 16),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 播放/暂停
              _buildPlayButton(
                icon: playbackState.status == PlaybackStatus.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: () {
                  final notifier = ref.read(playbackProvider.notifier);
                  if (playbackState.status == PlaybackStatus.playing) {
                    notifier.pause();
                  } else {
                    notifier.setOnNoteEvent(_onNoteEvent);
                    notifier.play();
                  }
                },
              ),

              if (playbackState.status != PlaybackStatus.idle) ...[
                const SizedBox(width: 16),
                _buildPlayButton(
                  icon: Icons.stop_rounded,
                  color: AppColors.error,
                  onTap: () => ref.read(playbackProvider.notifier).stop(),
                ),
              ],

              const SizedBox(width: 24),

              // 速度调节
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.glassBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, color: AppColors.textTertiary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${playbackState.speed.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.glassBg,
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withOpacity(0.2),
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        ),
                        child: Slider(
                          value: playbackState.speed.clamp(0.1, 10.0),
                          min: 0.1,
                          max: 10.0,
                          divisions: 99,
                          onChanged: (value) => ref.read(playbackProvider.notifier).setSpeed(value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Debug 模式：测试点击按钮
          if (ref.watch(debugModeProvider)) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.adb_rounded, size: 16),
                label: const Text('调试：依次点击所有琴键'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: BorderSide(color: AppColors.warning.withOpacity(0.5)),
                ),
                onPressed: _testTapAllKeys,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 调试：依次点击所有 15 个琴键，验证校准是否正确
  Future<void> _testTapAllKeys() async {
    final config = ref.read(settingsProvider);

    DebugLog.divider('调试点击测试');
    DebugLog.i('开始依次点击所有琴键...');
    DebugLog.d('配置: baseX=${config.baseX}, baseY=${config.baseY}, '
        'colSpacing=${config.columnSpacing}, rowSpacing=${config.rowSpacing}');

    const noteNames = [
      ['-1', '-2', '-3', '-4', '-5'],
      ['-6', '-7', '1', '2', '3'],
      ['4', '5', '6', '7', '+1'],
    ];

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 5; col++) {
        final x = config.getX(col);
        final y = config.getY(row);
        final name = noteNames[row][col];

        DebugLog.d('$name (row=$row, col=$col) → ($x, $y)');

        NativeService.tap(x, y, config.tapDurationMs);
        if (_isFloatingRunning) {
          NativeService.showTapEffect(x, y);
        }

        // 间隔 300ms 便于观察
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    DebugLog.i('调试点击测试完成');
    DebugLog.divider();
  }

  Widget _buildPlayButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: buttonColor.withOpacity(0.3)),
        ),
        child: Icon(icon, color: buttonColor, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_rounded, size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text(
            AppStrings.noScores,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.gradientPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _importScore,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Future<void> _importScore() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        List<int> bytes;
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        } else {
          return;
        }
        final content = _decodeText(bytes);
        final name = file.name.replaceAll('.txt', '');
        await ref.read(scoreListProvider.notifier).importScore(name, content);
        _showSnackBar('已导入: $name');
      }
    } catch (e) {
      _showSnackBar('导入失败: $e', isError: true);
    }
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(AppStrings.deleteScore, style: TextStyle(color: AppColors.textPrimary)),
        content: Text('确定要删除「$name」吗？', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppColors.textTertiary)),
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('需要权限', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zephyr 需要以下权限才能正常工作：', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            if (!_hasAccessibility)
              ListTile(
                leading: const Icon(Icons.accessibility_new_rounded, color: AppColors.primary),
                title: const Text('无障碍权限', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('模拟屏幕点击', style: TextStyle(color: AppColors.textTertiary)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textTertiary),
                onTap: () {
                  NativeService.openAccessibilitySettings();
                  Navigator.pop(context);
                },
              ),
            if (!_hasOverlay)
              ListTile(
                leading: const Icon(Icons.layers_rounded, color: AppColors.primary),
                title: const Text('悬浮窗权限', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('在游戏上层显示', style: TextStyle(color: AppColors.textTertiary)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textTertiary),
                onTap: () {
                  NativeService.requestOverlayPermission();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }

  /// 自动检测编码并解码文本（支持 UTF-8、UTF-16 LE/BE）
  String _decodeText(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // UTF-16 LE BOM
      final codeUnits = <int>[];
      for (var i = 2; i < bytes.length - 1; i += 2) {
        codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
      }
      return String.fromCharCodes(codeUnits);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // UTF-16 BE BOM
      final codeUnits = <int>[];
      for (var i = 2; i < bytes.length - 1; i += 2) {
        codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(codeUnits);
    }
    // 默认 UTF-8
    return utf8.decode(bytes, allowMalformed: true);
  }

  void _onNoteEvent(dynamic event) {
    final config = ref.read(settingsProvider);
    final playbackState = ref.read(playbackProvider);
    final notes = event.notes as List;

    if (notes.isEmpty) return;

    // Debug 日志：配置参数
    DebugLog.divider('按键事件 #${playbackState.currentEventIndex}');
    DebugLog.d('配置: baseX=${config.baseX}, baseY=${config.baseY}, '
        'colSpacing=${config.columnSpacing}, rowSpacing=${config.rowSpacing}');

    final noteNames = notes.map((n) => n.name).toList();

    if (notes.length == 1) {
      final note = notes[0];
      final x = config.getX(note.col);
      final y = config.getY(note.row);

      DebugLog.d('单音: ${note.name} (row=${note.row}, col=${note.col})');
      DebugLog.d('  计算: x = ${config.baseX} + ${note.col} × ${config.columnSpacing} = $x');
      DebugLog.d('  计算: y = ${config.baseY} + ${note.row} × ${config.rowSpacing} = $y');
      DebugLog.d('  → 点击 ($x, $y)');

      NativeService.tap(x, y, config.tapDurationMs);
      if (_isFloatingRunning) {
        NativeService.showTapEffect(x, y);
      }
    } else {
      DebugLog.d('和弦: $noteNames');
      final points = <List<double>>[];
      for (final note in notes) {
        final x = config.getX(note.col);
        final y = config.getY(note.row);
        points.add([x, y]);
        DebugLog.d('  ${note.name} (row=${note.row}, col=${note.col}) → ($x, $y)');
      }

      NativeService.tapMultiple(points, config.tapDurationMs);
      if (_isFloatingRunning) {
        for (final point in points) {
          NativeService.showTapEffect(point[0], point[1]);
        }
      }
    }

    // 预显示下一个待按按键
    if (_isFloatingRunning) {
      final nextEvent = ref.read(playbackProvider.notifier).nextEvent;
      if (nextEvent != null && !nextEvent.isRest && nextEvent.notes.isNotEmpty) {
        final nextNotes = nextEvent.notes;
        for (final note in nextNotes) {
          final nx = config.getX(note.col);
          final ny = config.getY(note.row);
          NativeService.showNextKeyIndicator(nx, ny, note.name);
        }
        DebugLog.d('  预显示下一个: ${nextNotes.map((n) => n.name).toList()}');
      } else {
        NativeService.clearNextKeyIndicator();
      }
    }
  }
}
