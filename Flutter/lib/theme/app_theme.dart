import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Dark theme built around a custom [accent] color.
  static ThemeData dark(Color accent) {
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
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.bgSurface2,
        outline: AppColors.borderSubtle,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.bgBase,
    );
    return _common(base, accent);
  }

  /// Light theme built around a custom [accent] color. Uses explicit,
  /// hand-tuned surfaces (white cards on a soft lilac-grey background)
  /// rather than fromSeed tints so it matches the design in light mode.
  static ThemeData light(Color accent) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: AppColors.brandMagenta,
        onSecondary: Colors.white,
        tertiary: AppColors.goldPremium,
        surface: Colors.white,
        onSurface: const Color(0xFF1A1330),
        surfaceContainerHighest: const Color(0xFFEFEFF7),
        outline: const Color(0xFFE3E3F0),
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F6FB),
    );
    return _common(base, accent);
  }

  static ThemeData _common(ThemeData base, Color accent) {
    final cs = base.colorScheme;
    final isDark = base.brightness == Brightness.dark;
    final borderColor =
        isDark ? AppColors.borderSubtle : const Color(0xFFE5E5EF);
    return base.copyWith(
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
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.bgSurface2 : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        hintStyle: TextStyle(
            color: isDark ? AppColors.textMuted : const Color(0xFF8A88A3)),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Light mode must NOT fall back to Material's dark inverseSurface
        // (that showed up as a black bar with invisible text).
        backgroundColor: isDark ? AppColors.bgSurface2 : Colors.white,
        elevation: 6,
        contentTextStyle: TextStyle(color: cs.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.bgSurface : Colors.white,
        indicatorColor: accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: cs.onSurface),
        ),
      ),
    );
  }
}
