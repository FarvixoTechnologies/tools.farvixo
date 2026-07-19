import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/account_entitlements_provider.dart';
import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_capabilities_provider.dart';
import '../providers/tool_activity_provider.dart';
import 'device_service.dart';
import 'settings_capability_services.dart';
import 'settings_sync_service.dart';
import 'supabase_service.dart';

/// Runs once after a non-guest login / session restore.
class UserSyncCoordinator {
  UserSyncCoordinator._();

  static String? _lastSyncedUserId;

  static Future<void> onLogin(Ref ref, AppUser user) async {
    if (user.isGuest) return;
    if (SupabaseService.client == null) return;
    if (_lastSyncedUserId == user.id) return;
    _lastSyncedUserId = user.id;

    try {
      await SettingsSyncService.instance.hydrate(ref);
    } catch (e) {
      debugPrint('UserSync settings hydrate: $e');
    }
    try {
      await SettingsCapabilityServices.probe();
      ref.invalidate(settingsCapabilitiesProvider);
      ref.invalidate(accountEntitlementsRemoteProvider);
    } catch (e) {
      debugPrint('UserSync capability probe: $e');
    }
    try {
      await ref.read(favoriteToolsProvider.notifier).hydrateFromRemote();
    } catch (e) {
      debugPrint('UserSync favorites hydrate: $e');
    }
    try {
      await ref.read(recentToolsProvider.notifier).hydrateFromRemote();
    } catch (e) {
      debugPrint('UserSync recent hydrate: $e');
    }
    try {
      final storage = ref.read(storageServiceProvider);
      await DeviceService.instance.registerCurrentDevice(storage: storage);
    } catch (e) {
      debugPrint('UserSync device register: $e');
    }
  }

  static void onLogout() {
    _lastSyncedUserId = null;
  }
}

/// Watch this from [FarvixoApp] so login sync runs app-wide.
final supabaseLoginSyncProvider = Provider<void>((ref) {
  ref.listen<AppUser?>(authProvider, (prev, next) {
    if (next == null || next.isGuest) {
      if (prev != null && !prev.isGuest) UserSyncCoordinator.onLogout();
      return;
    }
    final becameSignedIn = prev == null || prev.isGuest || prev.id != next.id;
    if (becameSignedIn) {
      // ignore: discarded_futures
      UserSyncCoordinator.onLogin(ref, next);
    }
  }, fireImmediately: true);
});
