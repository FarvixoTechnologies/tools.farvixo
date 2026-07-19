import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import '../services/secure_storage_service.dart';

/// Keys for persisted boolean settings (SharedPreferences unless noted).
enum SettingsPrefKey {
  push,
  emailNotif,
  marketing,
  toolUpdates,
  aiUpdates,
  downloadsNotif,
  analytics,
  personalization,
  wifiOnlyDownloads,
  autoDeleteDownloads,
  reduceMotion,
  boldText,
  highContrast,
  haptics,
  sound,
  animations,
  featureAi,
  aiStreaming,
  aiSaveHistory,
  featureNotifications,
  featureOffline,
  featureCloudSync,
}

extension SettingsPrefKeyX on SettingsPrefKey {
  bool read(dynamic storage) {
    return switch (this) {
      SettingsPrefKey.push => storage.pushNotifications as bool,
      SettingsPrefKey.emailNotif => storage.emailNotifications as bool,
      SettingsPrefKey.marketing => storage.marketingNotifications as bool,
      SettingsPrefKey.toolUpdates => storage.toolUpdates as bool,
      SettingsPrefKey.aiUpdates => storage.aiUpdates as bool,
      SettingsPrefKey.downloadsNotif => storage.downloadsNotifications as bool,
      SettingsPrefKey.analytics => storage.analyticsEnabled as bool,
      SettingsPrefKey.personalization =>
        storage.personalizationEnabled as bool,
      SettingsPrefKey.wifiOnlyDownloads => storage.wifiOnlyDownloads as bool,
      SettingsPrefKey.autoDeleteDownloads =>
        storage.autoDeleteDownloads as bool,
      SettingsPrefKey.reduceMotion => storage.reduceMotion as bool,
      SettingsPrefKey.boldText => storage.boldText as bool,
      SettingsPrefKey.highContrast => storage.highContrast as bool,
      SettingsPrefKey.haptics => storage.hapticsEnabled as bool,
      SettingsPrefKey.sound => storage.soundEnabled as bool,
      SettingsPrefKey.animations => storage.animationsEnabled as bool,
      SettingsPrefKey.featureAi => storage.featureAiAssistant as bool,
      SettingsPrefKey.aiStreaming => storage.aiStreamingEnabled as bool,
      SettingsPrefKey.aiSaveHistory => storage.aiSaveHistoryEnabled as bool,
      SettingsPrefKey.featureNotifications =>
        storage.featureNotifications as bool,
      SettingsPrefKey.featureOffline => storage.featureOffline as bool,
      SettingsPrefKey.featureCloudSync => storage.featureCloudSync as bool,
    };
  }

  Future<void> write(dynamic storage, bool value) {
    return switch (this) {
      SettingsPrefKey.push => storage.setPushNotifications(value),
      SettingsPrefKey.emailNotif => storage.setEmailNotifications(value),
      SettingsPrefKey.marketing => storage.setMarketingNotifications(value),
      SettingsPrefKey.toolUpdates => storage.setToolUpdates(value),
      SettingsPrefKey.aiUpdates => storage.setAiUpdates(value),
      SettingsPrefKey.downloadsNotif =>
        storage.setDownloadsNotifications(value),
      SettingsPrefKey.analytics => storage.setAnalyticsEnabled(value),
      SettingsPrefKey.personalization =>
        storage.setPersonalizationEnabled(value),
      SettingsPrefKey.wifiOnlyDownloads =>
        storage.setWifiOnlyDownloads(value),
      SettingsPrefKey.autoDeleteDownloads =>
        storage.setAutoDeleteDownloads(value),
      SettingsPrefKey.reduceMotion => storage.setReduceMotion(value),
      SettingsPrefKey.boldText => storage.setBoldText(value),
      SettingsPrefKey.highContrast => storage.setHighContrast(value),
      SettingsPrefKey.haptics => storage.setHapticsEnabled(value),
      SettingsPrefKey.sound => storage.setSoundEnabled(value),
      SettingsPrefKey.animations => storage.setAnimationsEnabled(value),
      SettingsPrefKey.featureAi => storage.setFeatureAiAssistant(value),
      SettingsPrefKey.aiStreaming => storage.setAiStreamingEnabled(value),
      SettingsPrefKey.aiSaveHistory => storage.setAiSaveHistoryEnabled(value),
      SettingsPrefKey.featureNotifications =>
        storage.setFeatureNotifications(value),
      SettingsPrefKey.featureOffline => storage.setFeatureOffline(value),
      SettingsPrefKey.featureCloudSync => storage.setFeatureCloudSync(value),
    };
  }
}

/// Persisted app-preference toggles shown across Settings sections.
final settingsPrefProvider =
    StateNotifierProvider.family<_BoolPrefNotifier, bool, SettingsPrefKey>(
        (ref, key) {
  final storage = ref.watch(storageServiceProvider);
  return _BoolPrefNotifier(key.read(storage), (v) => key.write(storage, v));
});

/// Back-compat aliases used elsewhere in the app.
final soundEnabledProvider = settingsPrefProvider(SettingsPrefKey.sound);
final animationsEnabledProvider =
    settingsPrefProvider(SettingsPrefKey.animations);

/// Biometric app lock (secure storage — separate from login quick-unlock).
final biometricLockProvider =
    StateNotifierProvider<BiometricLockNotifier, bool>((ref) {
  return BiometricLockNotifier(ref.watch(secureStorageProvider));
});

class BiometricLockNotifier extends StateNotifier<bool> {
  BiometricLockNotifier(this._secure) : super(false) {
    _load();
  }

  final SecureStorageService _secure;

  Future<void> _load() async {
    state = await _secure.biometricEnabled;
  }

  Future<void> set(bool value) async {
    state = value;
    await _secure.setBiometricEnabled(value);
  }

  void toggle() => set(!state);
}

class _BoolPrefNotifier extends StateNotifier<bool> {
  _BoolPrefNotifier(super.initial, this._persist);

  final Future<void> Function(bool) _persist;

  void set(bool value) {
    state = value;
    _persist(value);
  }

  void toggle() => set(!state);
}
