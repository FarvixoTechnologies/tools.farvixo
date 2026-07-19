import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import 'farvixo_api_client.dart';
import 'settings_export_saver_io.dart'
    if (dart.library.html) 'settings_export_saver_web.dart';
import 'supabase_service.dart';

/// Capability probe for billing / upgrade flows.
abstract class BillingCapability {
  bool get isConfigured;
  String get unavailableReason;

  Future<Uri?> startCheckout();
}

class UnconfiguredBillingCapability implements BillingCapability {
  const UnconfiguredBillingCapability();

  @override
  bool get isConfigured => false;

  @override
  String get unavailableReason => 'Billing service not configured';

  @override
  Future<Uri?> startCheckout() async => null;
}

class ConfiguredBillingCapability implements BillingCapability {
  ConfiguredBillingCapability({FarvixoApiClient? client})
      : _client = client ?? FarvixoApiClient();

  final FarvixoApiClient _client;

  @override
  bool get isConfigured => true;

  @override
  String get unavailableReason => '';

  @override
  Future<Uri?> startCheckout() async {
    final res = await _client.post('/billing/checkout', data: {
      'successUrl': 'https://tools.farvixo.com/dashboard/billing?checkout=success',
      'cancelUrl': 'https://tools.farvixo.com/dashboard/billing?checkout=cancelled',
    });
    if (!res.ok || res.data == null) {
      throw StateError(res.message ?? 'Checkout failed');
    }
    final url = res.data!['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('Checkout URL missing');
    }
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) throw StateError('Could not open checkout');
    return uri;
  }
}

/// Capability probe for GDPR data export / account delete.
abstract class GdprCapability {
  bool get isConfigured;
  String get unavailableReason;

  Future<String> exportDataJson();
  Future<void> deleteAccount();
}

class UnconfiguredGdprCapability implements GdprCapability {
  const UnconfiguredGdprCapability();

  @override
  bool get isConfigured => false;

  @override
  String get unavailableReason => 'GDPR export/delete service not configured';

  @override
  Future<String> exportDataJson() async {
    throw StateError(unavailableReason);
  }

  @override
  Future<void> deleteAccount() async {
    throw StateError(unavailableReason);
  }
}

class ConfiguredGdprCapability implements GdprCapability {
  ConfiguredGdprCapability({FarvixoApiClient? client})
      : _client = client ?? FarvixoApiClient();

  final FarvixoApiClient _client;

  @override
  bool get isConfigured => true;

  @override
  String get unavailableReason => '';

  @override
  Future<String> exportDataJson() async {
    final res = await _client.getRaw('/account/export');
    if (!res.ok || res.data == null) {
      throw StateError(res.message ?? 'Export failed');
    }
    return res.data!;
  }

  /// Saves export JSON and returns a user-facing path / message.
  Future<String> downloadExport() async {
    final json = await exportDataJson();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final filename = 'farvixo-data-$day.json';
    return saveSettingsExportFile(json, filename);
  }

  @override
  Future<void> deleteAccount() async {
    final res = await _client.post('/account/delete');
    if (!res.ok) {
      throw StateError(res.message ?? 'Delete failed');
    }
  }
}

/// Capability probe for linked OAuth providers (beyond login).
abstract class AccountLinkingCapability {
  bool get isConfigured;
  String get unavailableReason;

  Future<List<String>> linkedProviders();
  Future<void> linkProvider(String provider);
  Future<void> unlinkProvider(String provider);
}

class UnconfiguredAccountLinkingCapability
    implements AccountLinkingCapability {
  const UnconfiguredAccountLinkingCapability();

  @override
  bool get isConfigured => false;

  @override
  String get unavailableReason => 'Account linking not configured';

  @override
  Future<List<String>> linkedProviders() async => const [];

  @override
  Future<void> linkProvider(String provider) async {
    throw StateError(unavailableReason);
  }

  @override
  Future<void> unlinkProvider(String provider) async {
    throw StateError(unavailableReason);
  }
}

class ConfiguredAccountLinkingCapability implements AccountLinkingCapability {
  ConfiguredAccountLinkingCapability({FarvixoApiClient? client})
      : _client = client ?? FarvixoApiClient();

  final FarvixoApiClient _client;

  static const linkable = {'google', 'github', 'apple'};

  @override
  bool get isConfigured => true;

  @override
  String get unavailableReason => '';

  OAuthProvider _oauth(String provider) => switch (provider) {
        'google' => OAuthProvider.google,
        'github' => OAuthProvider.github,
        'apple' => OAuthProvider.apple,
        _ => throw StateError('Provider not enabled: $provider'),
      };

  @override
  Future<List<String>> linkedProviders() async {
    final res = await _client.get('/account/identities');
    if (!res.ok || res.data == null) return const [];
    final list = res.data!['identities'];
    if (list is! List) return const [];
    return list
        .map((e) => (e as Map)['provider']?.toString() ?? '')
        .where((p) => p.isNotEmpty)
        .toList();
  }

  @override
  Future<void> linkProvider(String provider) async {
    if (!linkable.contains(provider)) {
      throw StateError('Provider not enabled');
    }
    final client = SupabaseService.client;
    if (client == null) throw StateError('Auth not configured');
    await client.auth.linkIdentity(
      _oauth(provider),
      redirectTo: kIsWeb ? null : AppConfig.authRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> unlinkProvider(String provider) async {
    if (!linkable.contains(provider)) {
      throw StateError('Provider not enabled');
    }
    final client = SupabaseService.client;
    if (client == null) throw StateError('Auth not configured');
    final identities = client.auth.currentUser?.identities ?? [];
    final match = identities.where((i) => i.provider == provider).toList();
    if (match.isEmpty) throw StateError('Provider not linked');
    await client.auth.unlinkIdentity(match.first);
  }
}

/// Password change via Supabase Auth (no extra API).
class PasswordChangeService {
  PasswordChangeService._();
  static final PasswordChangeService instance = PasswordChangeService._();

  bool get isConfigured =>
      AppConfig.supabaseEnabled &&
      SupabaseService.client?.auth.currentUser != null;

  Future<void> changePassword(String newPassword) async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Sign in required');
    }
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }
}

/// Opens OS app-settings / permission screens where possible.
class PlatformPermissionService {
  PlatformPermissionService._();
  static final PlatformPermissionService instance =
      PlatformPermissionService._();

  Future<bool> openAppSettings() async {
    final uris = <Uri>[
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        Uri.parse('app-settings:'),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        Uri.parse('app-settings:'),
    ];

    for (final uri in uris) {
      try {
        if (await canLaunchUrl(uri)) {
          return launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('PlatformPermissionService.openAppSettings: $e');
      }
    }
    return false;
  }
}

/// Live capability snapshot after probing the Farvixo API.
class SettingsCapabilitySnapshot {
  const SettingsCapabilitySnapshot({
    this.billingConfigured = false,
    this.gdprConfigured = false,
    this.accountLinkingConfigured = false,
    this.passwordChangeConfigured = false,
  });

  final bool billingConfigured;
  final bool gdprConfigured;
  final bool accountLinkingConfigured;
  final bool passwordChangeConfigured;

  static const empty = SettingsCapabilitySnapshot();
}

/// Singleton accessors used by Settings.
class SettingsCapabilityServices {
  SettingsCapabilityServices._();

  static BillingCapability billing = const UnconfiguredBillingCapability();
  static GdprCapability gdpr = const UnconfiguredGdprCapability();
  static AccountLinkingCapability accountLinking =
      const UnconfiguredAccountLinkingCapability();

  static SettingsCapabilitySnapshot snapshot = SettingsCapabilitySnapshot.empty;

  /// Probe APIs and flip configured implementations when live.
  static Future<SettingsCapabilitySnapshot> probe() async {
    final client = FarvixoApiClient();
    var billingOk = false;
    var gdprOk = false;
    var linkingOk = false;

    if (client.hasSession) {
      try {
        final status = await client.get('/billing/status');
        if (status.ok && status.data != null) {
          billingOk = status.data!['billingConfigured'] == true;
          // Same auth stack as GDPR endpoints.
          gdprOk = true;
        } else if (!status.unauthorized && !status.notConfigured) {
          // API reachable with auth errors other than 503 → still try GDPR.
          gdprOk = status.statusCode != null && status.statusCode! < 500;
        }
      } catch (e) {
        debugPrint('SettingsCapabilityServices.probe billing: $e');
      }

      try {
        final ids = await client.get('/account/identities');
        linkingOk = ids.ok;
      } catch (e) {
        debugPrint('SettingsCapabilityServices.probe identities: $e');
      }
    }

    billing = billingOk
        ? ConfiguredBillingCapability(client: client)
        : const UnconfiguredBillingCapability();
    gdpr = gdprOk
        ? ConfiguredGdprCapability(client: client)
        : const UnconfiguredGdprCapability();
    accountLinking = linkingOk
        ? ConfiguredAccountLinkingCapability(client: client)
        : const UnconfiguredAccountLinkingCapability();

    snapshot = SettingsCapabilitySnapshot(
      billingConfigured: billingOk,
      gdprConfigured: gdprOk,
      accountLinkingConfigured: linkingOk,
      passwordChangeConfigured: PasswordChangeService.instance.isConfigured,
    );
    return snapshot;
  }
}

/// Pretty-print helper kept for tests that parse API JSON envelopes.
Map<String, dynamic>? tryDecodeJsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}
