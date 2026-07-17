import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashRepository {
  final FirebaseCrashlytics _crash = FirebaseCrashlytics.instance;

  Future<void> setCrashlyticsCollectionEnabled(bool enabled) =>
      _crash.setCrashlyticsCollectionEnabled(enabled);

  Future<void> setUserId(String? id) async {
    try {
      await _crash.setUserIdentifier(id ?? '');
    } catch (e) {
      debugPrint('CrashRepository.setUserId: $e');
    }
  }

  Future<void> log(String message) async {
    try {
      await _crash.log(message);
    } catch (_) {}
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    try {
      await _crash.recordFlutterFatalError(details);
    } catch (e) {
      debugPrint('CrashRepository.recordFlutterError: $e');
    }
  }

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    try {
      await _crash.recordError(
        error,
        stack,
        fatal: fatal,
        reason: reason,
      );
    } catch (e) {
      debugPrint('CrashRepository.recordError: $e');
    }
  }
}
