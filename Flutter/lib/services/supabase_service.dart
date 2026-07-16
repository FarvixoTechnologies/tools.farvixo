import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Guarded Supabase wrapper — skips initialization when keys are missing.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static bool get isAvailable => _initialized;

  static SupabaseClient? get client =>
      _initialized ? Supabase.instance.client : null;

  static GoTrueClient? get auth => client?.auth;

  static Future<void> init() async {
    if (!AppConfig.supabaseEnabled) {
      debugPrint('Supabase keys missing — auth requires Flutter/.env or '
          '--dart-define SUPABASE_URL / SUPABASE_ANON_KEY.');
      return;
    }
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _initialized = true;
      debugPrint('Supabase initialized (${AppConfig.supabaseUrl})');
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  }
}
