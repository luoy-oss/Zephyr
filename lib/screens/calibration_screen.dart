import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/key_position.dart';
import '../providers/settings_provider.dart';
import '../services/accessibility_service.dart';

class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  late double _baseX;
  late double _baseY;
  late double _colSpacing;
  late double _rowSpacing;
  int _selectedRow = -1;
  int _selectedCol = -1;

  @override
  void initState() {
    super.initState();
    final config = ref.read(settingsProvider);
    _baseX = config.baseX;
    _baseY = config.baseY;
    _colSpacing = config.columnSpacing;
    _rowSpacing = config.rowSpacing;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.calibrate),
        actions: [
          TextButton(
            onPressed: _saveConfig,
            child: const Text('保存', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 说明文字
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: const Text(
              '调整琴键位置使其与游戏中的钢琴对齐。\n'
              '1. 拖动基准点（左上角第一个琴键）到正确位置\n'
              '2. 调整行间距和列间距使网格对齐\n'
              '3. 点击琴键测试点击位置',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),

          // 可视化校准区域
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  if (_selectedRow == -1 && _selectedCol == -1) {
                    // 移动整个基准点
                    _baseX += details.delta.dx;
                    _baseY += details.delta.dy;
                  }
                });
              },
              child: CustomPaint(
                painter: _PianoGridPainter(
                  baseX: _baseX,
                  baseY: _baseY,
                  colSpacing: _colSpacing,
                  rowSpacing: _rowSpacing,
                  selectedRow: _selectedRow,
                  selectedCol: _selectedCol,
                ),
                size: Size.infinite,
              ),
            ),
          ),

          // 控制面板
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                // 基准位置显示
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoChip('X: ${_baseX.round()}'),
                    _buildInfoChip('Y: ${_baseY.round()}'),
                  ],
                ),
                const SizedBox(height: 16),

                // 行间距调节
                _buildAdjustRow(
                  label: AppStrings.rowSpacing,
                  value: _rowSpacing,
                  onDecrease: () => setState(() {
                    _rowSpacing = (_rowSpacing - 5).clamp(50, 300);
                  }),
                  onIncrease: () => setState(() {
                    _rowSpacing = (_rowSpacing + 5).clamp(50, 300);
                  }),
                  onChanged: (v) => setState(() => _rowSpacing = v),
                ),
                const SizedBox(height: 8),

                // 列间距调节
                _buildAdjustRow(
                  label: AppStrings.columnSpacing,
                  value: _colSpacing,
                  onDecrease: () => setState(() {
                    _colSpacing = (_colSpacing - 5).clamp(50, 300);
                  }),
                  onIncrease: () => setState(() {
                    _colSpacing = (_colSpacing + 5).clamp(50, 300);
                  }),
                  onChanged: (v) => setState(() => _colSpacing = v),
                ),
                const SizedBox(height: 16),

                // 测试按钮
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _testTap,
                        icon: const Icon(Icons.touch_app),
                        label: const Text('测试点击'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppColors.card,
    );
  }

  Widget _buildAdjustRow({
    required String label,
    required double value,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove, size: 20),
          onPressed: onDecrease,
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 50,
            max: 300,
            divisions: 50,
            onChanged: onChanged,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: onIncrease,
        ),
        SizedBox(
          width: 50,
          child: Text('${value.round()}px', style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  void _testTap() {
    // 测试点击第一个琴键位置
    NativeService.tap(_baseX, _baseY, 100);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已发送测试点击')),
    );
  }

  void _saveConfig() {
    final config = KeyPositionConfig(
      baseX: _baseX,
      baseY: _baseY,
      columnSpacing: _colSpacing,
      rowSpacing: _rowSpacing,
      tapDurationMs: ref.read(settingsProvider).tapDurationMs,
      countdownSeconds: ref.read(settingsProvider).countdownSeconds,
    );
    ref.read(settingsProvider.notifier).updateConfig(config);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已保存')),
    );
  }
}

/// 琴键网格绘制器
class _PianoGridPainter extends CustomPainter {
  final double baseX;
  final double baseY;
  final double colSpacing;
  final double rowSpacing;
  final int selectedRow;
  final int selectedCol;

  static const _noteNames = [
    ['-1', '-2', '-3', '-4', '-5'],
    ['-6', '-7', '1', '2', '3'],
    ['4', '5', '6', '7', '+1'],
  ];

  _PianoGridPainter({
    required this.baseX,
    required this.baseY,
    required this.colSpacing,
    required this.rowSpacing,
    this.selectedRow = -1,
    this.selectedCol = -1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 5; col++) {
        final x = baseX + col * colSpacing;
        final y = baseY + row * rowSpacing;
        final radius = 20.0;

        // 选中状态
        final isSelected = row == selectedRow && col == selectedCol;

        // 绘制圆形琴键
        fillPaint.color = isSelected
            ? AppColors.primary
            : AppColors.primary.withOpacity(0.3);
        paint.color = AppColors.primary;

        canvas.drawCircle(Offset(x, y), radius, fillPaint);
        canvas.drawCircle(Offset(x, y), radius, paint);

        // 绘制音符名称
        final textPainter = TextPainter(
          text: TextSpan(
            text: _noteNames[row][col],
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2),
        );
      }
    }

    // 绘制基准点标记
    final crossPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(baseX - 10, baseY - 10),
      Offset(baseX + 10, baseY + 10),
      crossPaint,
    );
    canvas.drawLine(
      Offset(baseX + 10, baseY - 10),
      Offset(baseX - 10, baseY + 10),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
