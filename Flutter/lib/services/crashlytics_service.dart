import 'package:flutter/foundation.dart';

import '../data/repositories/crash_repository.dart';

class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  final CrashRepository _repo = CrashRepository();

  Future<void> install() async {
    try {
      await _repo.setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _repo.recordFlutterError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        _repo.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('CrashlyticsService.install: $e');
    }
  }

  Future<void> setUserId(String? id) => _repo.setUserId(id);

  Future<void> log(String message) => _repo.log(message);

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) =>
      _repo.recordError(error, stack, fatal: fatal, reason: reason);

  Future<void> recordApiError(
    String endpoint,
    Object error, [
    StackTrace? stack,
  ]) =>
      _repo.recordError(
        error,
        stack,
        fatal: false,
        reason: 'api:$endpoint',
      );
}

/// Thin helper — prefer [CrashlyticsService].
void recordCrash(Object error, StackTrace? stack, {bool fatal = false}) {
  // ignore: discarded_futures
  CrashlyticsService.instance.recordError(error, stack, fatal: fatal);
}
