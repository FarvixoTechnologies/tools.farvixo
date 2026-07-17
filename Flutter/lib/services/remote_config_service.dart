import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/repositories/remote_config_repository.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final RemoteConfigRepository _repo = RemoteConfigRepository();

  bool get maintenanceMode => _repo.getBool('maintenance_mode');
  String get minAppVersion => _repo.getString('min_app_version');
  bool get premiumFeaturesEnabled =>
      _repo.getBool('premium_features_enabled');
  String get announcementBanner => _repo.getString('announcement_banner');
  String get themeOverrides => _repo.getString('theme_overrides');

  Future<void> init() async {
    try {
      await _repo.setDefaults({
        'maintenance_mode': false,
        'min_app_version': '1.0.0',
        'premium_features_enabled': true,
        'announcement_banner': '',
        'theme_overrides': '',
      });
      await _repo.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteConfigService.init: $e');
    }
  }

  Future<void> refresh() => _repo.fetchAndActivate();

  /// Returns true when installed version is below Remote Config minimum.
  Future<bool> isForceUpdateRequired() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return _isLower(info.version, minAppVersion);
    } catch (_) {
      return false;
    }
  }

  static bool _isLower(String current, String minimum) {
    List<int> parts(String v) =>
        v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final a = parts(current);
    final b = parts(minimum);
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x < y) return true;
      if (x > y) return false;
    }
    return false;
  }
}

/// Convenience for callers that need the raw Firebase instance.
FirebaseRemoteConfig get remoteConfig => FirebaseRemoteConfig.instance;
