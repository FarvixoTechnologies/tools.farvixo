import 'package:flutter/material.dart';

/// Splash configuration — remote/local (see LAUNCH & SPLASH SYSTEM v2.0.0,
/// section 8 "Configuration"). Loaded by ConfigManager with local fallback;
/// a remote JSON with the same shape can restyle the splash without a new
/// build (Dynamic Update).
class SplashConfig {
  const SplashConfig({
    this.enabled = true,
    this.minDuration = 1500,
    this.maxDuration = 3000,
    this.animationType = 'ai_orbit',
    this.backgroundType = 'gradient',
    this.background = const Color(0xFF0A0E27),
    this.logoAnimation = 'scale_fade_rotate',
    this.showProgress = true,
    this.progressColor = const Color(0xFF8C52FF),
    this.progressTrackColor = const Color(0xFF2A2E45),
    this.enableParticles = true,
    this.particleColors = const [Color(0xFF8C52FF), Color(0xFF00D4FF)],
    this.redirectLoggedIn = '/home',
    this.redirectLoggedOut = '/login',
    this.redirectFirstTime = '/onboarding',
  });

  final bool enabled;

  /// Milliseconds the splash stays visible at minimum (no flash).
  final int minDuration;

  /// Hard cap in milliseconds — startup must never hang beyond this.
  final int maxDuration;

  /// 'ai_orbit' | 'minimal_glow' | 'particle_orbit' | 'gradient_wave'
  final String animationType;

  /// 'gradient' | 'solid'
  final String backgroundType;
  final Color background;

  /// 'scale_fade_rotate' | 'fade' | 'scale'
  final String logoAnimation;

  final bool showProgress;
  final Color progressColor;
  final Color progressTrackColor;

  final bool enableParticles;
  final List<Color> particleColors;

  final String redirectLoggedIn;
  final String redirectLoggedOut;
  final String redirectFirstTime;

  /// Theme adaptation (section 9) — light mode overrides.
  SplashConfig copyWith({
    Color? background,
    Color? progressTrackColor,
    String? backgroundType,
  }) {
    return SplashConfig(
      enabled: enabled,
      minDuration: minDuration,
      maxDuration: maxDuration,
      animationType: animationType,
      backgroundType: backgroundType ?? this.backgroundType,
      background: background ?? this.background,
      logoAnimation: logoAnimation,
      showProgress: showProgress,
      progressColor: progressColor,
      progressTrackColor: progressTrackColor ?? this.progressTrackColor,
      enableParticles: enableParticles,
      particleColors: particleColors,
      redirectLoggedIn: redirectLoggedIn,
      redirectLoggedOut: redirectLoggedOut,
      redirectFirstTime: redirectFirstTime,
    );
  }

  static Color _color(dynamic hex, Color fallback) {
    if (hex is! String || hex.isEmpty) return fallback;
    final value = int.tryParse(hex.replaceFirst('#', 'FF'), radix: 16);
    return value == null ? fallback : Color(value);
  }

  factory SplashConfig.fromJson(Map<String, dynamic> json) {
    const def = SplashConfig();
    final redirect = json['redirect'] as Map<String, dynamic>? ?? const {};
    return SplashConfig(
      enabled: json['enabled'] as bool? ?? def.enabled,
      minDuration: json['minDuration'] as int? ?? def.minDuration,
      maxDuration: json['maxDuration'] as int? ?? def.maxDuration,
      animationType: json['animationType'] as String? ?? def.animationType,
      backgroundType: json['backgroundType'] as String? ?? def.backgroundType,
      background: _color(json['background'], def.background),
      logoAnimation: json['logoAnimation'] as String? ?? def.logoAnimation,
      showProgress: json['showProgress'] as bool? ?? def.showProgress,
      progressColor: _color(json['progressColor'], def.progressColor),
      progressTrackColor:
          _color(json['progressTrackColor'], def.progressTrackColor),
      enableParticles: json['enableParticles'] as bool? ?? def.enableParticles,
      particleColors: (json['particleColor'] as List?)
              ?.map((c) => _color(c, def.particleColors.first))
              .toList() ??
          def.particleColors,
      redirectLoggedIn: redirect['loggedIn'] as String? ?? def.redirectLoggedIn,
      redirectLoggedOut:
          redirect['loggedOut'] as String? ?? def.redirectLoggedOut,
      redirectFirstTime:
          redirect['firstTime'] as String? ?? def.redirectFirstTime,
    );
  }
}
