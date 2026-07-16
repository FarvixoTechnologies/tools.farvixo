import 'package:flutter/foundation.dart';

import '../../services/secure_storage_service.dart';
import '../../services/storage_service.dart';
import 'models/splash_config.dart';

/// Smart Decision Engine (see LAUNCH & SPLASH SYSTEM v2.0.0, section 4).
///
/// ```text
/// App Launch → Initialize System → User Logged In?
///   ├─ Yes → Session Valid? ── Yes → Home Dashboard
///   │                       └─ No  → Refresh Token or Re-Login
///   └─ No  → First Time User? ── Yes → Onboarding
///                              └─ No  → Login / Register
/// ```
class DecisionEngine {
  DecisionEngine(this._storage, this._secure);

  final StorageService _storage;
  final SecureStorageService _secure;

  Future<String> decide(SplashConfig config) async {
    // First Time User? → Onboarding.
    if (!_storage.onboardingDone) return config.redirectFirstTime;

    // User Logged In?
    if (_storage.userJson == null) return config.redirectLoggedOut;

    // Session Valid?
    final expiry = await _secure.sessionExpiry;
    final expired = expiry != null && expiry.isBefore(DateTime.now());
    if (!expired) return config.redirectLoggedIn;

    // Refresh Token or Re-Login.
    final refreshToken = await _secure.refreshToken;
    if (refreshToken != null) {
      await _refreshSession();
      return config.redirectLoggedIn;
    }
    return config.redirectLoggedOut;
  }

  Future<void> _refreshSession() async {
    // TODO(backend): exchange the refresh token for new tokens.
    await _secure.setSessionExpiry(DateTime.now().add(const Duration(hours: 1)));
    debugPrint('DecisionEngine: session silently refreshed');
  }
}
