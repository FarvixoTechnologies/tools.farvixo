import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/user_model.dart';
import 'settings_catalog.dart';

/// Why a settings row may be unavailable.
enum SettingsAvailabilityKind {
  available,
  requiresSignIn,
  requiresService,
  unsupportedPlatform,
  notConfigured,
}

/// Resolved availability for a single settings row.
class SettingsItemAvailability {
  const SettingsItemAvailability({
    required this.kind,
    this.reason,
  });

  final SettingsAvailabilityKind kind;
  final String? reason;

  bool get isEnabled => kind == SettingsAvailabilityKind.available;

  static const available = SettingsItemAvailability(
    kind: SettingsAvailabilityKind.available,
  );

  factory SettingsItemAvailability.disabled({
    required SettingsAvailabilityKind kind,
    required String reason,
  }) {
    return SettingsItemAvailability(kind: kind, reason: reason);
  }
}

/// Hub grouping used by the Settings home screen — derived from catalog IDs.
class SettingsHubGroup {
  const SettingsHubGroup({
    required this.title,
    this.actionLabel,
    this.actionSectionId,
    required this.sectionIds,
    this.extraRoutes = const {},
  });

  final String title;
  final String? actionLabel;
  final String? actionSectionId;
  final List<String> sectionIds;

  /// Optional overrides: hub row id → absolute route (e.g. devices → /devices).
  final Map<String, String> extraRoutes;
}

/// Menu row model for the Settings hub lists.
typedef SettingsHubMenuRow = (
  IconData icon,
  Color color,
  String title,
  String subtitle,
  String id,
);

List<SettingsHubMenuRow> hubMenuRowsFor(SettingsHubGroup group) {
  final rows = <SettingsHubMenuRow>[];
  for (final id in group.sectionIds) {
    final section = settingsSectionById(id);
    if (section == null) continue;
    rows.add((
      section.icon,
      section.iconColor,
      _hubTitle(section),
      section.subtitle ?? section.title,
      section.id,
    ));
  }
  return rows;
}

String _hubTitle(SettingsSection section) {
  final raw = section.title.trim();
  if (raw.isEmpty) return section.id;
  return raw
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Canonical hub groups so every catalog section is reachable.
const kSettingsHubGroups = <SettingsHubGroup>[
  SettingsHubGroup(
    title: 'Account & Security',
    actionLabel: 'Security',
    actionSectionId: 'security',
    sectionIds: ['account', 'security', 'connected'],
    extraRoutes: {'devices': '/devices'},
  ),
  SettingsHubGroup(
    title: 'Advanced Settings',
    sectionIds: [
      'appearance',
      'storage',
      'subscription',
      'ai',
      'notifications',
      'privacy',
      'tools',
      'downloads',
      'language',
      'accessibility',
    ],
  ),
  SettingsHubGroup(
    title: 'Activity & Support',
    sectionIds: [
      'activity',
      'support',
      'about',
      'developer',
      'legal',
      'danger-zone',
    ],
    extraRoutes: {'downloads': '/downloads'},
  ),
];

/// Live backend flags (billing / GDPR / linking / password).
class SettingsBackendCapabilities {
  const SettingsBackendCapabilities({
    this.billingConfigured = false,
    this.gdprConfigured = false,
    this.accountLinkingConfigured = false,
    this.passwordChangeConfigured = false,
  });

  final bool billingConfigured;
  final bool gdprConfigured;
  final bool accountLinkingConfigured;
  final bool passwordChangeConfigured;

  static const none = SettingsBackendCapabilities();
}

/// Resolves whether a settings item can run on this device/session/config.
class SettingsCapabilityResolver {
  const SettingsCapabilityResolver({
    required this.user,
    this.biometricAvailable = false,
    this.backend = SettingsBackendCapabilities.none,
  });

  final AppUser? user;
  final bool biometricAvailable;
  final SettingsBackendCapabilities backend;

  bool get _signedIn => user != null && !(user!.isGuest);

  SettingsItemAvailability resolve(SettingsItem item) {
    // Fully wired interactive rows stay available.
    if (_isLocallyAvailable(item)) {
      return SettingsItemAvailability.available;
    }

    if (item.prefKey == 'biometricLock' && !biometricAvailable) {
      return SettingsItemAvailability.disabled(
        kind: SettingsAvailabilityKind.unsupportedPlatform,
        reason: 'Biometrics not available on this device',
      );
    }

    if (_requiresSignIn(item.id) && !_signedIn) {
      return SettingsItemAvailability.disabled(
        kind: SettingsAvailabilityKind.requiresSignIn,
        reason: 'Sign in required',
      );
    }

    final serviceReason = _serviceReason(item);
    if (serviceReason != null) {
      return SettingsItemAvailability.disabled(
        kind: SettingsAvailabilityKind.notConfigured,
        reason: serviceReason,
      );
    }

    if (item.comingSoon) {
      return SettingsItemAvailability.disabled(
        kind: SettingsAvailabilityKind.notConfigured,
        reason: _defaultComingSoonReason(item.id),
      );
    }

    return SettingsItemAvailability.available;
  }

  bool _isLocallyAvailable(SettingsItem item) {
    if (item.type == SettingsItemType.toggle) {
      // Biometric gated separately.
      if (item.prefKey == 'biometricLock') return biometricAvailable;
      return true;
    }

    if (item.actionId != null) {
      return switch (item.actionId!) {
        SettingsActionId.signOut ||
        SettingsActionId.resetApp ||
        SettingsActionId.factoryReset ||
        SettingsActionId.clearCache ||
        SettingsActionId.appearanceTheme ||
        SettingsActionId.appearanceAccent ||
        SettingsActionId.appearanceHomeLayout ||
        SettingsActionId.appearanceBottomStyle ||
        SettingsActionId.languagePicker ||
        SettingsActionId.showLicenses =>
          true,
      };
    }

    if (item.route != null && item.route!.isNotEmpty && !item.comingSoon) {
      return true;
    }

    if (item.url != null && item.url!.isNotEmpty && !item.comingSoon) {
      return true;
    }

    if (item.type == SettingsItemType.info && !item.comingSoon) {
      return true;
    }

    return false;
  }

  bool _requiresSignIn(String id) {
    const ids = {
      'sessions_devices',
      'security_sessions',
      'recent_devices',
      'export_data',
      'delete_history',
      'change_password',
      'two_factor',
      'conn_google',
      'conn_github',
      'conn_apple',
      'conn_microsoft',
      'conn_discord',
      'conn_linkedin',
      'login_history',
      'upgrade_pro',
      'renew_date',
      'delete_account',
      'blocked_users',
      'hidden_profile',
    };
    return ids.contains(id);
  }

  String? _serviceReason(SettingsItem item) {
    switch (item.id) {
      case 'upgrade_pro':
        if (backend.billingConfigured) return null;
        return 'Billing service not configured';
      case 'renew_date':
        // Informational — always show; trailing handles empty renew date.
        return null;
      case 'conn_google':
      case 'conn_github':
      case 'conn_apple':
        if (backend.accountLinkingConfigured) return null;
        return 'Account linking not configured';
      case 'conn_microsoft':
      case 'conn_discord':
      case 'conn_linkedin':
        return 'Provider not enabled';
      case 'export_data':
      case 'delete_account':
        if (backend.gdprConfigured) return null;
        return 'GDPR export/delete service not configured';
      case 'delete_history':
        return 'GDPR export/delete service not configured';
      case 'two_factor':
        return 'Account security service not configured';
      case 'change_password':
        if (backend.passwordChangeConfigured ||
            (AppConfig.supabaseEnabled && _signedIn)) {
          return null;
        }
        return 'Account security service not configured';
      case 'ai_personality':
      case 'default_model':
      case 'response_style':
      case 'ai_voice':
      case 'ai_memory':
      case 'context_length':
      case 'smart_suggestions':
      case 'ai_privacy':
      case 'ai_theme':
        return 'AI preference service not configured';
      case 'streaming':
      case 'chat_history':
        // Local toggles — always available.
        return null;
      case 'quiet_hours':
      case 'sms_alerts':
        return 'Notification delivery service not configured';
      case 'perm_location':
      case 'perm_mic':
      case 'perm_camera':
      case 'perm_storage':
        return 'Open system settings to manage this permission';
      case 'email_notif':
      case 'marketing':
        // Local toggle still persists; cloud delivery needs backend.
        if (!AppConfig.supabaseEnabled) {
          return 'Email preference service not configured';
        }
        return null;
      default:
        return null;
    }
  }

  String _defaultComingSoonReason(String id) {
    if (id.startsWith('perm_')) {
      return 'Open system settings to manage this permission';
    }
    if (id.startsWith('conn_')) {
      return 'Account linking not configured';
    }
    if (id.startsWith('ai_') ||
        id == 'default_model' ||
        id == 'response_style' ||
        id == 'streaming' ||
        id == 'smart_suggestions' ||
        id == 'context_length' ||
        id == 'chat_history') {
      return 'AI preference service not configured';
    }
    return 'Requires additional service setup';
  }
}
