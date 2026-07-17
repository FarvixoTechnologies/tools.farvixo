import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Android Play Integrity (release) + debug provider (debug builds).
class AppCheckService {
  AppCheckService._();
  static final AppCheckService instance = AppCheckService._();

  Future<void> activate() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
      );
      debugPrint(
        'AppCheck activated (${kDebugMode ? 'debug' : 'play_integrity'})',
      );
    } catch (e) {
      debugPrint('AppCheckService.activate: $e');
    }
  }
}
