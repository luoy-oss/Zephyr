import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(settingsProvider);
    final bpm = ref.watch(bpmProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 演奏设置
          _buildSectionTitle('演奏设置'),
          _buildCard([
            // BPM 设置
            _buildSliderRow(
              icon: Icons.speed,
              label: AppStrings.bpm,
              value: bpm,
              min: 30,
              max: 200,
              divisions: 170,
              format: (v) => '${v.round()} BPM',
              onChanged: (v) => ref.read(bpmProvider.notifier).state = v,
            ),
            const Divider(),

            // 点击时长
            _buildSliderRow(
              icon: Icons.touch_app,
              label: AppStrings.tapDuration,
              value: config.tapDurationMs.toDouble(),
              min: 50,
              max: 500,
              divisions: 45,
              format: (v) => '${v.round()} ms',
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).updateTapDuration(v.round()),
            ),
            const Divider(),

            // 倒计时
            _buildSliderRow(
              icon: Icons.timer,
              label: AppStrings.countdown,
              value: config.countdownSeconds.toDouble(),
              min: 0,
              max: 15,
              divisions: 15,
              format: (v) => '${v.round()} 秒',
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).updateCountdown(v.round()),
            ),
          ]),

          const SizedBox(height: 24),

          // 琴键布局设置
          _buildSectionTitle(AppStrings.keyLayout),
          _buildCard([
            // 行间距
            _buildSliderRow(
              icon: Icons.swap_vert,
              label: AppStrings.rowSpacing,
              value: config.rowSpacing,
              min: 50,
              max: 300,
              divisions: 50,
              format: (v) => '${v.round()} px',
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).updateRowSpacing(v),
            ),
            const Divider(),

            // 列间距
            _buildSliderRow(
              icon: Icons.swap_horiz,
              label: AppStrings.columnSpacing,
              value: config.columnSpacing,
              min: 50,
              max: 300,
              divisions: 50,
              format: (v) => '${v.round()} px',
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).updateColumnSpacing(v),
            ),
          ]),

          const SizedBox(height: 24),

          // 琴键预览
          _buildSectionTitle('琴键预览'),
          _buildPianoPreview(config),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 70,
          child: Text(
            format(value),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildPianoPreview(dynamic config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '光遇钢琴布局',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            // 简化的琴键网格预览
            for (int row = 0; row < 3; row++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (int col = 0; col < 5; col++)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getNoteName(row, col),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '行间距: ${config.rowSpacing.round()}px  列间距: ${config.columnSpacing.round()}px',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNoteName(int row, int col) {
    const names = [
      ['-1', '-2', '-3', '-4', '-5'],
      ['-6', '-7', '1', '2', '3'],
      ['4', '5', '6', '7', '+1'],
    ];
    return names[row][col];
  }
}
