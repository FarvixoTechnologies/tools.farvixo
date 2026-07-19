import 'package:flutter/material.dart';

/// Farvixo design tokens — deep-space dark, violet primary, gold premium.
class AppColors {
  AppColors._();

  // Base surfaces (dark)
  static const Color bgBase = Color(0xFF0A0A12);
  static const Color bgSurface = Color(0xFF12121C);
  static const Color bgSurface2 = Color(0xFF1A1A28);
  static const Color borderSubtle = Color(0xFF2A2A3C);

  // Base surfaces + text (light) — single source for the light theme, shared by
  // AppTheme.light() and AppPalette so Light/Dark/Custom stay consistent.
  static const Color lightBg = Color(0xFFF6F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFEFEFF7);
  static const Color lightBorder = Color(0xFFE3E3F0);
  static const Color lightTextPrimary = Color(0xFF1A1330);
  static const Color lightTextSecondary = Color(0xFF5A5876);
  static const Color lightTextMuted = Color(0xFF8A88A3);

  // Brand
  static const Color brandPrimary = Color(0xFF7C3AED);
  static const Color brandPrimaryHover = Color(0xFF8B5CF6);
  static const Color brandMagenta = Color(0xFFC026D3);
  static const Color goldPremium = Color(0xFFF5B93D);

  // Text (dark theme)
  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textSecondary = Color(0xFFA0A0B8);
  static const Color textMuted = Color(0xFF6B6B85);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);

  // Category accents
  static const Color accentPdf = Color(0xFFEF4444);
  static const Color accentImage = Color(0xFF22C55E);
  static const Color accentVideo = Color(0xFFA855F7);
  static const Color accentAudio = Color(0xFFF97316);
  static const Color accentAi = Color(0xFFC026D3);
  static const Color accentDev = Color(0xFF3B82F6);
  static const Color accentText = Color(0xFF06B6D4);
  static const Color accentUtility = Color(0xFF64748B);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPrimary, brandMagenta],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5B93D), Color(0xFFD97706)],
  );
}
