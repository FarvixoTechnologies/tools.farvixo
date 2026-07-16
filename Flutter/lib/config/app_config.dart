import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central app configuration.
///
/// Supabase keys load from [Flutter]/.env (via flutter_dotenv), with optional
/// `--dart-define=SUPABASE_URL=...` / `SUPABASE_ANON_KEY=...` overrides.
/// Without keys the app cannot use real auth (guest still works).
class AppConfig {
  AppConfig._();

  static const String appName = 'Farvixo';
  static const String tagline = 'Smart Tools. AI Power. Limitless Possibilities.';
  static const String shortTagline = 'Smart Tools. AI Power.';
  static const String version = '1.0.0';

  /// Deep-link for OAuth + email magic-link return (AndroidManifest + Supabase allow-list).
  static const String authRedirectUrl = 'com.farvixo.app://login-callback';

  /// @deprecated Use [authRedirectUrl].
  static const String oauthRedirectUrl = authRedirectUrl;

  static const String _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _defineAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _definePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const String _defineGemini =
      String.fromEnvironment('GEMINI_API_KEY');
  static const String _defineApiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tools.farvixo.com/api',
  );

  static String get supabaseUrl {
    if (_defineUrl.isNotEmpty) return _defineUrl;
    return dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
  }

  static String get supabaseAnonKey {
    if (_defineAnonKey.isNotEmpty) return _defineAnonKey;
    return dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';
  }

  /// New-style publishable key (`sb_publishable_…`); falls back to anon JWT.
  static String get supabasePublishableKey {
    if (_definePublishableKey.isNotEmpty) return _definePublishableKey;
    final fromEnv = dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY')?.trim() ?? '';
    if (fromEnv.isNotEmpty) return fromEnv;
    return supabaseAnonKey;
  }

  static String get geminiApiKey {
    if (_defineGemini.isNotEmpty) return _defineGemini;
    return dotenv.maybeGet('GEMINI_API_KEY')?.trim() ?? '';
  }

  static const String geminiModel = 'gemini-2.0-flash';

  static String get apiBaseUrl => _defineApiBase.isNotEmpty
      ? _defineApiBase
      : (dotenv.maybeGet('API_BASE_URL')?.trim() ??
          'https://tools.farvixo.com/api');

  static bool get supabaseEnabled =>
      supabaseUrl.isNotEmpty &&
      (supabaseAnonKey.isNotEmpty || supabasePublishableKey.isNotEmpty);

  static bool get geminiEnabled => geminiApiKey.isNotEmpty;

  /// Load [Flutter]/.env — safe no-op if the file is missing.
  static Future<void> loadEnv() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Missing .env is fine when using --dart-define only.
    }
  }
}
