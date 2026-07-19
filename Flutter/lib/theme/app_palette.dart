import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-wide, theme-adaptive palette so every screen flips correctly between
/// dark, light and custom (accent) modes. Read once per build:
///
/// ```dart
/// final p = AppPalette.of(context);
/// ```
///
/// Use [bg] for scaffolds, [surface]/[surface2] for cards, the `text*` colors
/// for copy, [border] for outlines and [accent] for interactive highlights.
/// Brand colors (gold, magenta, category accents) stay fixed and should keep
/// using [AppColors] directly.
class AppPalette {
  const AppPalette({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
  });

  factory AppPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    return isDark
        ? AppPalette(
            isDark: true,
            bg: AppColors.bgBase,
            surface: AppColors.bgSurface,
            surface2: AppColors.bgSurface2,
            border: AppColors.borderSubtle,
            textPrimary: AppColors.textPrimary,
            textSecondary: AppColors.textSecondary,
            textMuted: AppColors.textMuted,
            accent: accent,
          )
        : AppPalette(
            isDark: false,
            bg: AppColors.lightBg,
            surface: AppColors.lightSurface,
            surface2: AppColors.lightSurface2,
            border: AppColors.lightBorder,
            textPrimary: AppColors.lightTextPrimary,
            textSecondary: AppColors.lightTextSecondary,
            textMuted: AppColors.lightTextMuted,
            accent: accent,
          );
  }

  final bool isDark;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
}
