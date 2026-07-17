import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsRepository {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> setAnalyticsCollectionEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);

  Future<void> setUser({required String userId, String? plan}) async {
    await _analytics.setUserId(id: userId);
    if (plan != null) {
      await _analytics.setUserProperty(name: 'plan', value: plan);
    }
  }

  Future<void> clearUser() async {
    await _analytics.setUserId(id: null);
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('AnalyticsRepository.logEvent($name): $e');
    }
  }
}
