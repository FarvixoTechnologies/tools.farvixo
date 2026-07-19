import 'package:farvixo_all/features/settings/settings_capability.dart';
import 'package:farvixo_all/features/settings/settings_catalog.dart';
import 'package:farvixo_all/models/user_model.dart';
import 'package:farvixo_all/providers/account_entitlements_provider.dart';
import 'package:farvixo_all/services/farvixo_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FarvixoApiResult', () {
    test('fail marks 503 as notConfigured', () {
      final r = FarvixoApiResult<Map<String, dynamic>>.fail(
        statusCode: 503,
        message: 'Billing is not configured',
        notConfigured: true,
      );
      expect(r.ok, isFalse);
      expect(r.notConfigured, isTrue);
      expect(r.unauthorized, isFalse);
    });

    test('fail marks 401 as unauthorized', () {
      final r = FarvixoApiResult<Map<String, dynamic>>.fail(
        statusCode: 401,
        message: 'Unauthorized',
        unauthorized: true,
      );
      expect(r.unauthorized, isTrue);
      expect(r.notConfigured, isFalse);
    });

    test('success carries data', () {
      final r = FarvixoApiResult.success({'billingConfigured': true});
      expect(r.ok, isTrue);
      expect(r.data!['billingConfigured'], isTrue);
    });
  });

  group('SettingsCapabilityResolver with live backend flags', () {
    final user = const AppUser(id: 'u1', email: 'a@b.com', plan: 'free');

    test('upgrade enabled when billing configured', () {
      final item = kSettingsSections
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'upgrade_pro');
      final availability = SettingsCapabilityResolver(
        user: user,
        backend: const SettingsBackendCapabilities(billingConfigured: true),
      ).resolve(item);
      expect(availability.isEnabled, isTrue);
    });

    test('upgrade disabled when billing not configured', () {
      final item = kSettingsSections
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'upgrade_pro');
      final availability = SettingsCapabilityResolver(user: user).resolve(item);
      expect(availability.isEnabled, isFalse);
      expect(availability.reason, contains('Billing'));
    });

    test('export enabled when GDPR configured', () {
      final item = kSettingsSections
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'export_data');
      final availability = SettingsCapabilityResolver(
        user: user,
        backend: const SettingsBackendCapabilities(gdprConfigured: true),
      ).resolve(item);
      expect(availability.isEnabled, isTrue);
    });

    test('google link enabled when linking configured', () {
      final item = kSettingsSections
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'conn_google');
      final availability = SettingsCapabilityResolver(
        user: user,
        backend:
            const SettingsBackendCapabilities(accountLinkingConfigured: true),
      ).resolve(item);
      expect(availability.isEnabled, isTrue);
    });

    test('microsoft stays provider-not-enabled', () {
      final item = kSettingsSections
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'conn_microsoft');
      final availability = SettingsCapabilityResolver(
        user: user,
        backend:
            const SettingsBackendCapabilities(accountLinkingConfigured: true),
      ).resolve(item);
      expect(availability.isEnabled, isFalse);
      expect(availability.reason, contains('Provider'));
    });

    test('quiet hours remain delivery-not-configured', () {
      final item = kSettingsSections
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'quiet_hours');
      final availability = SettingsCapabilityResolver(user: user).resolve(item);
      expect(availability.isEnabled, isFalse);
      expect(availability.reason, contains('delivery'));
    });
  });

  group('AccountEntitlements.fromBillingStatus', () {
    test('maps API payload', () {
      final e = AccountEntitlements.fromBillingStatus(
        {
          'plan': 'pro',
          'planLabel': 'Pro',
          'credits': 8000,
          'creditsMax': 10000,
          'storageUsedGb': 1.5,
          'storageMaxGb': 100,
          'renewDate': '2026-08-01T00:00:00.000Z',
          'billingConfigured': true,
        },
        user: const AppUser(id: '1', email: 'a@b.com', plan: 'free'),
      );
      expect(e.plan, 'pro');
      expect(e.creditsLeft, 8000);
      expect(e.billingConfigured, isTrue);
      expect(e.renewDateLabel, '2026-08-01');
      expect(e.storageMaxGb, 100);
    });
  });
}
