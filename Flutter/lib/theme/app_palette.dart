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
            bg: const Color(0xFFF6F6FB),
            surface: Colors.white,
            surface2: const Color(0xFFEFEFF7),
            border: const Color(0xFFE3E3F0),
            textPrimary: const Color(0xFF1A1330),
            textSecondary: const Color(0xFF5A5876),
            textMuted: const Color(0xFF8A88A3),
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
