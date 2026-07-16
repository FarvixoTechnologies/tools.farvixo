import 'package:flutter/material.dart';

/// Farvixo design tokens — deep-space dark, violet primary, gold premium.
class AppColors {
  AppColors._();

  // Base surfaces (dark)
  static const Color bgBase = Color(0xFF0A0A12);
  static const Color bgSurface = Color(0xFF12121C);
  static const Color bgSurface2 = Color(0xFF1A1A28);
  static const Color borderSubtle = Color(0xFF2A2A3C);

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
