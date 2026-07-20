import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../providers/app_providers.dart';
import '../models/qr_settings.dart';

/// Persists [QrSettings] to SharedPreferences under the `qr_` key prefix.
class QrSettingsNotifier extends StateNotifier<QrSettings> {
  QrSettingsNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static const _kSound = 'qr_sound';
  static const _kVibration = 'qr_vibration';
  static const _kAutoOpen = 'qr_auto_open';
  static const _kPrivate = 'qr_private_mode';
  static const _kOffline = 'qr_offline_only';
  static const _kBiometric = 'qr_biometric_lock';
  static const _kRetention = 'qr_retention_days';

  static QrSettings _read(SharedPreferences p) => QrSettings(
        sound: p.getBool(_kSound) ?? true,
        vibration: p.getBool(_kVibration) ?? true,
        autoOpenLinks: p.getBool(_kAutoOpen) ?? false,
        privateMode: p.getBool(_kPrivate) ?? false,
        offlineOnly: p.getBool(_kOffline) ?? false,
        biometricLock: p.getBool(_kBiometric) ?? false,
        retentionDays: p.getInt(_kRetention) ?? 0,
      );

  void setSound(bool v) => _apply(state.copyWith(sound: v), _kSound, v);
  void setVibration(bool v) =>
      _apply(state.copyWith(vibration: v), _kVibration, v);
  void setAutoOpenLinks(bool v) =>
      _apply(state.copyWith(autoOpenLinks: v), _kAutoOpen, v);
  void setPrivateMode(bool v) =>
      _apply(state.copyWith(privateMode: v), _kPrivate, v);
  void setOfflineOnly(bool v) =>
      _apply(state.copyWith(offlineOnly: v), _kOffline, v);
  void setBiometricLock(bool v) =>
      _apply(state.copyWith(biometricLock: v), _kBiometric, v);

  void setRetentionDays(int days) {
    state = state.copyWith(retentionDays: days);
    _prefs.setInt(_kRetention, days);
  }

  void _apply(QrSettings next, String key, bool value) {
    state = next;
    _prefs.setBool(key, value);
  }
}

final qrSettingsProvider =
    StateNotifierProvider<QrSettingsNotifier, QrSettings>(
  (ref) => QrSettingsNotifier(ref.watch(sharedPreferencesProvider)),
);
