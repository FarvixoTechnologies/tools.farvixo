import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../../services/analytics_service.dart';
import '../../services/app_check_service.dart';
import '../../services/crashlytics_service.dart';
import '../../services/notification_service.dart';
import '../../services/remote_config_service.dart';

/// Ordered Firebase production bootstrap (farvixo-production-2026).
/// Auth stays on Supabase — this never initializes Firebase Auth.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;

  static Future<void> init({
    void Function(String? path)? onNotificationOpen,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      await AppCheckService.instance.activate();
      await CrashlyticsService.instance.install();
      await RemoteConfigService.instance.init();
      await NotificationService.instance.init(
        onOpen: onNotificationOpen,
      );
      await AnalyticsService.instance.setDefaults();

      ready = true;
      debugPrint('FirebaseBootstrap ready (farvixo-production-2026)');
    } catch (e, st) {
      ready = false;
      debugPrint('FirebaseBootstrap skipped: $e\n$st');
    }
  }
}
