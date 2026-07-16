import 'package:flutter/foundation.dart';

import 'models/splash_config.dart';

/// Loads splash configuration — Remote Config (Firebase / API) with a
/// local JSON/asset fallback (see LAUNCH & SPLASH SYSTEM v2.0.0, section 8).
///
/// Remote fetch is a hook today; the local default mirrors the production
/// config so behavior is identical with or without a backend.
class ConfigManager {
  SplashConfig? _cached;

  /// Local fallback — same values as the shipped remote config.
  static const _localConfig = <String, dynamic>{
    'splash': {
      'enabled': true,
      'minDuration': 1500,
      'maxDuration': 3000,
      'animationType': 'ai_orbit',
      'backgroundType': 'gradient',
      'background': '#0A0E27',
      'logo': 'assets/logo/farvixo_logo.png',
      'logoAnimation': 'scale_fade_rotate',
      'showProgress': true,
      'progressColor': '#8C52FF',
      'progressTrackColor': '#2A2E45',
      'enableParticles': true,
      'particleColor': ['#8C52FF', '#00D4FF'],
      'redirect': {
        'loggedIn': '/home',
        'loggedOut': '/login',
        'firstTime': '/onboarding',
      },
    },
  };

  Future<SplashConfig> load() async {
    if (_cached != null) return _cached!;
    try {
      // TODO(backend): fetch remote config (Firebase / API) with a short
      // timeout, then merge over the local fallback (Dynamic Update —
      // restyle the splash with no new build).
      final json = _localConfig['splash'] as Map<String, dynamic>;
      _cached = SplashConfig.fromJson(json);
    } catch (e) {
      debugPrint('ConfigManager: falling back to defaults ($e)');
      _cached = const SplashConfig();
    }
    return _cached!;
  }
}
