import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'config/app_config.dart';
import 'core/firebase/pending_deep_link.dart';
import 'providers/app_providers.dart';
import 'services/firebase_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await AppConfig.loadEnv();
  final prefs = await SharedPreferences.getInstance();
  // Respect analytics opt-out before any further product events.
  final analyticsEnabled = prefs.getBool('pref_analytics') ?? true;
  await SupabaseService.init();

  // Firebase (Crashlytics, Remote Config, FCM/notifications) boots in the
  // BACKGROUND. The app must open instantly even when notifications are
  // disabled, Google Play Services is unavailable, or the network is slow —
  // push simply attaches once this completes. Notifications need no login:
  // the 'all_users' topic + token are set up here, before any sign-in.
  unawaited(
    FirebaseService.init(onNotificationOpen: PendingDeepLink.set)
        .then((_) => FirebaseService.applyAnalyticsCollection(analyticsEnabled))
        .catchError(
          (Object e) => debugPrint('Firebase background init failed: $e'),
        ),
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FarvixoApp(),
    ),
  );
}
