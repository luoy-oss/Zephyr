import 'package:flutter/material.dart';

class AppColors {
  // 主色调
  static const primary = Color(0xFF6366F1);      // Indigo
  static const secondary = Color(0xFF8B5CF6);    // Violet
  static const accent = Color(0xFF06B6D4);       // Cyan

  // 背景色
  static const background = Color(0xFF0F0F14);
  static const surface = Color(0xFF1A1A24);
  static const card = Color(0xFF222230);

  // 毛玻璃效果
  static const glassBg = Color(0x1AFFFFFF);      // 10% 白色
  static const glassBorder = Color(0x1AFFFFFF);   // 10% 白色边框
  static const glassHighlight = Color(0x0DFFFFFF); // 5% 白色高光

  // 文字颜色
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF64748B);

  // 状态颜色
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);

  // 渐变色
  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientSurface = LinearGradient(
    colors: [Color(0xFF1A1A24), Color(0xFF222230)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
