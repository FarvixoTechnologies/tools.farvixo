import 'package:farvixo_all/features/settings/settings_capability.dart';
import 'package:farvixo_all/features/settings/settings_catalog.dart';
import 'package:farvixo_all/models/user_model.dart';
import 'package:farvixo_all/providers/account_entitlements_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings catalog inventory', () {
    test('every section has unique id and at least one item', () {
      final ids = <String>{};
      for (final section in kSettingsSections) {
        expect(ids.add(section.id), isTrue, reason: 'duplicate ${section.id}');
        expect(section.items, isNotEmpty);
      }
    });

    test('every item has unique id across catalog', () {
      final ids = <String>{};
      for (final section in kSettingsSections) {
        for (final item in section.items) {
          expect(ids.add(item.id), isTrue, reason: 'duplicate item ${item.id}');
        }
      }
    });

    test('hub groups cover all catalog sections', () {
      final hubIds = <String>{
        for (final group in kSettingsHubGroups) ...group.sectionIds,
      };
      for (final section in kSettingsSections) {
        expect(
          hubIds.contains(section.id),
          isTrue,
          reason: 'hub missing section ${section.id}',
        );
      }
    });

    test('every item is navigable, toggleable, actionable, info, or capability-gated',
        () {
      final guestResolver = SettingsCapabilityResolver(user: null);
      final signedIn = SettingsCapabilityResolver(
        user: const AppUser(
          id: 'u1',
          email: 'a@b.com',
          plan: 'free',
        ),
      );

      for (final section in kSettingsSections) {
        for (final item in section.items) {
          final availability = signedIn.resolve(item);
          final hasBehavior = item.type == SettingsItemType.toggle ||
              item.type == SettingsItemType.info ||
              item.actionId != null ||
              (item.route != null && item.route!.isNotEmpty) ||
              (item.url != null && item.url!.isNotEmpty) ||
              item.comingSoon ||
              !availability.isEnabled ||
              !guestResolver.resolve(item).isEnabled;
          expect(
            hasBehavior,
            isTrue,
            reason: 'item ${item.id} has no behavior',
          );
        }
      }
    });
  });

  group('SettingsCapabilityResolver', () {
    test('clear cache action is available', () {
      final item = kSettingsSections
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'clear_cache');
      final availability =
          const SettingsCapabilityResolver(user: null).resolve(item);
      expect(availability.isEnabled, isTrue);
    });

    test('upgrade requires billing service', () {
      final item = kSettingsSections
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'upgrade_pro');
      final availability = SettingsCapabilityResolver(
        user: const AppUser(id: 'u1', email: 'a@b.com'),
      ).resolve(item);
      expect(availability.isEnabled, isFalse);
      expect(availability.reason, contains('Billing'));
    });

    test('devices route available when signed in path exists', () {
      final item = kSettingsSections
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'sessions_devices');
      final availability = SettingsCapabilityResolver(
        user: const AppUser(id: 'u1', email: 'a@b.com'),
      ).resolve(item);
      expect(availability.isEnabled, isTrue);
    });
  });

  group('AccountEntitlements', () {
    test('guest defaults are honest and non-hardcoded marketing numbers', () {
      final e = AccountEntitlements.fromUser(null);
      expect(e.isGuest, isTrue);
      expect(e.planLabel, 'Guest');
      expect(e.creditsUsed, 0);
      expect(e.storageUsedGb, 0);
      expect(e.billingConfigured, isFalse);
      expect(e.hubSubscriptionSubtitle, contains('sign in'));
    });

    test('free and pro plans use product limits', () {
      final free = AccountEntitlements.fromUser(
        const AppUser(id: '1', email: 'a@b.com', plan: 'free'),
      );
      final pro = AccountEntitlements.fromUser(
        const AppUser(id: '1', email: 'a@b.com', plan: 'pro'),
      );
      expect(free.creditsMax, 500);
      expect(free.storageMaxGb, 0.5);
      expect(pro.creditsMax, 10000);
      expect(pro.storageMaxGb, 100);
    });
  });
}
