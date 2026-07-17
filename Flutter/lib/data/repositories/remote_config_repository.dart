import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigRepository {
  final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;

  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ),
    );
    await _rc.setDefaults(defaults);
  }

  Future<void> fetchAndActivate() async {
    try {
      await _rc.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteConfigRepository.fetchAndActivate: $e');
    }
  }

  bool getBool(String key) => _rc.getBool(key);
  String getString(String key) => _rc.getString(key);
  int getInt(String key) => _rc.getInt(key);
}
