import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// 毛玻璃效果容器
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? color;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.margin,
    this.blur = 10,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? AppColors.glassBg,
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                colors: [
                  AppColors.glassBg,
                  AppColors.glassBg.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 毛玻璃按钮
class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double borderRadius;

  const GlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (color ?? AppColors.primary).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: (color ?? AppColors.primary).withOpacity(0.15),
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: color ?? AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        color: color ?? AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
