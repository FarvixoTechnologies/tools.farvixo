import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// Persisted app-preference toggles shown on the Settings › Preferences card.
/// These survive restarts (SharedPreferences) and are pushed to Supabase
/// `user_settings` by [SettingsSyncService] when the user is signed in.

final soundEnabledProvider =
    StateNotifierProvider<_BoolPrefNotifier, bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return _BoolPrefNotifier(storage.soundEnabled, storage.setSoundEnabled);
});

final animationsEnabledProvider =
    StateNotifierProvider<_BoolPrefNotifier, bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return _BoolPrefNotifier(
      storage.animationsEnabled, storage.setAnimationsEnabled);
});

class _BoolPrefNotifier extends StateNotifier<bool> {
  _BoolPrefNotifier(super.initial, this._persist);

  final Future<void> Function(bool) _persist;

  void set(bool value) {
    state = value;
    _persist(value);
  }

  void toggle() => set(!state);
}
