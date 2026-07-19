import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import 'farvixo_api_client.dart';
import 'supabase_service.dart';

/// Two-way bridge between local preferences and Supabase `user_settings`.
/// Safe no-op when offline / guest.
class SettingsSyncService {
  SettingsSyncService._();
  static final SettingsSyncService instance = SettingsSyncService._();

  static const _table = 'user_settings';

  /// When true, [push] is a no-op — prevents pull→push loops during hydrate.
  bool _hydrating = false;

  bool get isHydrating => _hydrating;

  bool get _ready {
    final client = SupabaseService.client;
    return client != null && client.auth.currentUser != null;
  }

  String? get _uid => SupabaseService.client?.auth.currentUser?.id;

  Future<Map<String, dynamic>?> pull() async {
    if (!_ready) return null;
    try {
      final row = await SupabaseService.client!
          .from(_table)
          .select()
          .eq('user_id', _uid!)
          .maybeSingle();
      return row;
    } catch (e) {
      debugPrint('SettingsSync.pull failed: $e');
      return null;
    }
  }

  Future<void> push(Map<String, dynamic> values) async {
    if (_hydrating || !_ready || values.isEmpty) return;
    try {
      await SupabaseService.client!.from(_table).upsert({
        'user_id': _uid,
        ...values,
      });
    } catch (e) {
      debugPrint('SettingsSync.push failed: $e');
    }
  }

  /// Apply remote `user_settings` to Riverpod providers (no re-push).
  Future<void> hydrate(Ref ref) async {
    if (!_ready) return;
    _hydrating = true;
    try {
      final row = await pull();
      if (row == null) return;

      final mode = (row['theme_mode'] as String?) ?? 'system';
      ref.read(themeModeProvider.notifier).setMode(_themeFromDb(mode));

      final accent = row['accent_color'];
      if (accent is int) {
        ref.read(accentColorProvider.notifier).setColor(Color(accent));
      } else if (accent is num) {
        ref.read(accentColorProvider.notifier).setColor(Color(accent.toInt()));
      }

      final lang = row['language'] as String?;
      if (lang != null && lang.isNotEmpty) {
        ref.read(languageProvider.notifier).setLanguage(lang);
      }

      final sound = row['sound_enabled'];
      if (sound is bool) {
        ref.read(soundEnabledProvider.notifier).set(sound);
      }
      final anim = row['animations_enabled'];
      if (anim is bool) {
        ref.read(animationsEnabledProvider.notifier).set(anim);
      }

      final email = row['email_notifications'];
      if (email is bool) {
        ref.read(settingsPrefProvider(SettingsPrefKey.emailNotif).notifier).set(email);
      }
      final marketing = row['marketing_notifications'];
      if (marketing is bool) {
        ref.read(settingsPrefProvider(SettingsPrefKey.marketing).notifier).set(marketing);
      }
      final ai = row['ai_assistant_enabled'];
      if (ai is bool) {
        ref.read(settingsPrefProvider(SettingsPrefKey.featureAi).notifier).set(ai);
      }
    } catch (e) {
      debugPrint('SettingsSync.hydrate failed: $e');
    } finally {
      _hydrating = false;
    }
  }

  static ThemeMode _themeFromDb(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(String mode) => push({'theme_mode': mode});
  Future<void> setAccentColor(int argb) => push({'accent_color': argb});
  Future<void> setLanguage(String code) => push({'language': code});
  Future<void> setSoundEnabled(bool v) => push({'sound_enabled': v});
  Future<void> setAnimationsEnabled(bool v) => push({'animations_enabled': v});
  Future<void> setNotificationsEnabled(bool v) =>
      push({'notifications_enabled': v});
  Future<void> setEmailNotifications(bool v) async {
    await push({'email_notifications': v});
    await _mirrorEmailPrefsToApi(email: v);
  }

  Future<void> setMarketingNotifications(bool v) async {
    await push({'marketing_notifications': v});
    await _mirrorEmailPrefsToApi(marketing: v);
  }

  /// Mirrors toggles to web `settings` table via PATCH /account/settings.
  Future<void> _mirrorEmailPrefsToApi({bool? email, bool? marketing}) async {
    if (!_ready) return;
    final patch = <String, dynamic>{};
    if (email != null) patch['email_notifications'] = email;
    if (marketing != null) patch['marketing_opt_in'] = marketing;
    if (patch.isEmpty) return;
    try {
      await FarvixoApiClient().patch(
        '/account/settings',
        data: {'settings': patch},
      );
    } catch (e) {
      debugPrint('SettingsSync PATCH email prefs: $e');
    }
  }
}
