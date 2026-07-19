import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  /// Dark theme built around a custom [accent] color.
  static ThemeData dark(
    Color accent, {
    bool boldText = false,
    bool highContrast = false,
  }) {
    final onSurface =
        highContrast ? Colors.white : AppColors.textPrimary;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        secondary: AppColors.brandMagenta,
        onSecondary: Colors.white,
        tertiary: AppColors.goldPremium,
        surface: AppColors.bgSurface,
        onSurface: onSurface,
        surfaceContainerHighest: AppColors.bgSurface2,
        outline: highContrast ? Colors.white54 : AppColors.borderSubtle,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.bgBase,
    );
    return _common(base, accent, boldText: boldText);
  }

  /// Light theme built around a custom [accent] color. Uses explicit,
  /// hand-tuned surfaces (white cards on a soft lilac-grey background)
  /// rather than fromSeed tints so it matches the design in light mode.
  static ThemeData light(
    Color accent, {
    bool boldText = false,
    bool highContrast = false,
  }) {
    final onSurface =
        highContrast ? AppColors.bgBase : AppColors.lightTextPrimary;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: AppColors.brandMagenta,
        onSecondary: Colors.white,
        tertiary: AppColors.goldPremium,
        surface: AppColors.lightSurface,
        onSurface: onSurface,
        surfaceContainerHighest: AppColors.lightSurface2,
        outline: highContrast
            ? AppColors.lightTextPrimary
            : AppColors.lightBorder,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.lightBg,
    );
    return _common(base, accent, boldText: boldText);
  }

  static ThemeData _common(
    ThemeData base,
    Color accent, {
    bool boldText = false,
  }) {
    final cs = base.colorScheme;
    final isDark = base.brightness == Brightness.dark;
    final borderColor =
        isDark ? AppColors.borderSubtle : AppColors.lightBorder;
    final weight = boldText ? FontWeight.w700 : FontWeight.w400;
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: cs.onSurface,
        displayColor: cs.onSurface,
      ).copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontWeight: weight),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontWeight: weight),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontWeight: weight),
        titleMedium:
            base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: base.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brButton,
          side: BorderSide(color: borderColor),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: Radii.brSm,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: accent),
          shape: const RoundedRectangleBorder(
            borderRadius: Radii.brSm,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.bgSurface2 : AppColors.lightSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.md),
        border: OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.brSm,
          borderSide: BorderSide(color: accent, width: 2),
        ),
        hintStyle: TextStyle(
            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Light mode must NOT fall back to Material's dark inverseSurface
        // (that showed up as a black bar with invisible text).
        backgroundColor: isDark ? AppColors.bgSurface2 : AppColors.lightSurface,
        elevation: 6,
        contentTextStyle: TextStyle(color: cs.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brButton,
          side: BorderSide(color: borderColor),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.bgSurface : AppColors.lightSurface,
        indicatorColor: accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: cs.onSurface),
        ),
      ),
    );
  }
}
