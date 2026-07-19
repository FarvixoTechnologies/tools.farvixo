import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/settings_capability_services.dart';
import 'auth_provider.dart';

/// Live Settings backend capability flags (billing / GDPR / linking).
final settingsCapabilitiesProvider =
    FutureProvider<SettingsCapabilitySnapshot>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null || user.isGuest) {
    SettingsCapabilityServices.billing = const UnconfiguredBillingCapability();
    SettingsCapabilityServices.gdpr = const UnconfiguredGdprCapability();
    SettingsCapabilityServices.accountLinking =
        const UnconfiguredAccountLinkingCapability();
    SettingsCapabilityServices.snapshot = SettingsCapabilitySnapshot.empty;
    return SettingsCapabilitySnapshot.empty;
  }
  return SettingsCapabilityServices.probe();
});

/// Synchronous view for UI (defaults to empty while loading).
SettingsCapabilitySnapshot watchCapabilities(WidgetRef ref) {
  return ref.watch(settingsCapabilitiesProvider).maybeWhen(
        data: (v) => v,
        orElse: () => SettingsCapabilityServices.snapshot,
      );
}

/// Convenience for non-widget code that already has [AppUser].
SettingsCapabilitySnapshot capabilitiesForUser(AppUser? user) {
  if (user == null || user.isGuest) return SettingsCapabilitySnapshot.empty;
  return SettingsCapabilityServices.snapshot;
}
