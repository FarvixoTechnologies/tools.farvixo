import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/analytics_repository.dart';

/// Production analytics — Supabase Auth events + product funnel.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final AnalyticsRepository _repo = AnalyticsRepository();

  FirebaseAnalyticsObserver get observer => _repo.observer;

  Future<void> setDefaults() async {
    try {
      await _repo.setAnalyticsCollectionEnabled(true);
    } catch (e) {
      debugPrint('AnalyticsService.setDefaults: $e');
    }
  }

  Future<void> setUser({
    required String userId,
    String? plan,
  }) =>
      _repo.setUser(userId: userId, plan: plan);

  Future<void> clearUser() => _repo.clearUser();

  Future<void> screenView(String screenName) =>
      _repo.logEvent('screen_view', {'screen_name': screenName});

  Future<void> login(String method) =>
      _repo.logEvent('login', {'method': method});

  Future<void> logout() => _repo.logEvent('logout');

  Future<void> signup(String method) =>
      _repo.logEvent('signup', {'method': method});

  Future<void> search(String query) =>
      _repo.logEvent('search', {'search_term': query});

  Future<void> toolOpen(String toolSlug) =>
      _repo.logEvent('tool_open', {'tool_slug': toolSlug});

  Future<void> toolFinish(String toolSlug, {bool success = true}) =>
      _repo.logEvent('tool_finish', {
        'tool_slug': toolSlug,
        'success': success.toString(),
      });

  Future<void> favorite(String toolSlug, {required bool added}) =>
      _repo.logEvent('favorite', {
        'tool_slug': toolSlug,
        'action': added ? 'add' : 'remove',
      });

  Future<void> share(String contentType) =>
      _repo.logEvent('share', {'content_type': contentType});

  Future<void> download(String toolSlug) =>
      _repo.logEvent('download', {'tool_slug': toolSlug});

  Future<void> purchase(String itemId) =>
      _repo.logEvent('purchase', {'item_id': itemId});

  Future<void> subscription(String plan) =>
      _repo.logEvent('subscription', {'plan': plan});

  Future<void> premiumUpgrade({String source = 'app'}) =>
      _repo.logEvent('premium_upgrade', {'source': source});

  Future<void> error(String code, {String? message}) =>
      _repo.logEvent('errors', {
        'error_code': code,
        'message': ?message,
      });
}
