import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
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
    // Single source of truth for the type ramp — see app_typography.dart.
    // `boldText` bumps body/label weights for the accessibility preference
    // without changing the metric scale.
    final textTheme = AppTypography.textTheme(
      color: cs.onSurface,
      boldText: boldText,
    );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: base.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLargeStyle.copyWith(
          color: cs.onSurface,
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
          textStyle: AppTypography.bodyLargeStyle
              .copyWith(fontWeight: FontWeights.semibold),
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
          textStyle: AppTypography.bodyLargeStyle
              .copyWith(fontWeight: FontWeights.semibold),
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
        hintStyle: AppTypography.bodyMediumStyle.copyWith(
            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Light mode must NOT fall back to Material's dark inverseSurface
        // (that showed up as a black bar with invisible text).
        backgroundColor: isDark ? AppColors.bgSurface2 : AppColors.lightSurface,
        elevation: 6,
        contentTextStyle:
            AppTypography.bodyMediumStyle.copyWith(color: cs.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brButton,
          side: BorderSide(color: borderColor),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.bgSurface : AppColors.lightSurface,
        indicatorColor: accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.labelMediumStyle.copyWith(color: cs.onSurface),
        ),
      ),
    );
  }
}
