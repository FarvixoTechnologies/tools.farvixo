import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

import '../../config/app_config.dart';
import '../../providers/account_entitlements_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/appearance_layout_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/settings_capabilities_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/cache_cleanup_service.dart';
import '../../services/settings_capability_services.dart';
import '../../services/settings_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_kit.dart';
import 'accent_color_picker_sheet.dart';
import 'settings_capability.dart';
import 'settings_catalog.dart';
import 'settings_widgets.dart';

/// Detail screen for one settings section (`/settings/:section`).
class SettingsSectionScreen extends ConsumerStatefulWidget {
  const SettingsSectionScreen({super.key, required this.sectionId});

  final String sectionId;

  @override
  ConsumerState<SettingsSectionScreen> createState() =>
      _SettingsSectionScreenState();
}

class _SettingsSectionScreenState extends ConsumerState<SettingsSectionScreen> {
  bool? _biometricHardware;

  @override
  void initState() {
    super.initState();
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final available = await ref.read(biometricServiceProvider).isAvailable;
    if (mounted) setState(() => _biometricHardware = available);
  }

  SettingsSection? get _section => settingsSectionById(widget.sectionId);

  void _unavailable(String feature, String reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — $reason'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  SettingsCapabilityResolver get _resolver {
    final caps = watchCapabilities(ref);
    return SettingsCapabilityResolver(
      user: ref.read(authProvider),
      biometricAvailable: _biometricHardware == true,
      backend: SettingsBackendCapabilities(
        billingConfigured: caps.billingConfigured,
        gdprConfigured: caps.gdprConfigured,
        accountLinkingConfigured: caps.accountLinkingConfigured,
        passwordChangeConfigured: caps.passwordChangeConfigured,
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _unavailable('Open link', 'Could not open $url');
      }
    } catch (e) {
      if (mounted) {
        _unavailable('Open link', 'Could not open external URL');
      }
    }
  }

  Future<void> _openPermissionSettings(SettingsItem item) async {
    final opened = await PlatformPermissionService.instance.openAppSettings();
    if (!mounted) return;
    if (!opened) {
      _unavailable(
        item.title,
        'Open system settings to manage this permission',
      );
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _resetAppPreferences() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset app preferences?'),
        content: const Text(
          'This restores default settings. Your account and downloads are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final storage = ref.read(storageServiceProvider);
    await storage.resetAppPreferences();
    if (mounted) {
      ref.invalidate(settingsPrefProvider);
      ref.invalidate(biometricLockProvider);
      ref.invalidate(themeModeProvider);
      ref.invalidate(accentColorProvider);
      ref.invalidate(customAccentPaletteProvider);
      ref.invalidate(appearanceLayoutProvider);
      ref.invalidate(languageProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferences reset to defaults'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _factoryReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory reset?'),
        content: const Text(
          'This erases all local app data including preferences and cached files. '
          'You will be signed out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erase Everything'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final storage = ref.read(storageServiceProvider);
    await storage.factoryResetPreferences();
    await ref.read(authProvider.notifier).signOut();
    if (mounted) {
      ref.invalidate(settingsPrefProvider);
      context.go('/login');
    }
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cache?'),
        content: const Text(
          'This removes temporary files stored on device. '
          'Your account, preferences, and downloads are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final result = await CacheCleanupService.instance.clearTemporaryCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.deletedEntries == 0
              ? 'No temporary cache to clear'
              : 'Cleared ${result.humanSize} (${result.deletedEntries} items)',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _themeSheet() {
    final p = AppPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: Radii.brSheetTop,
      ),
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheet) {
            final current = ref.read(themeModeProvider);
            final accent = ref.read(accentColorProvider);
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.textMuted.withValues(alpha: .5),
                        borderRadius: Radii.brPill,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Theme',
                      style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final mode in ThemeMode.values) ...[
                        Expanded(
                          child: AppearanceModeChip(
                            selected: mode == current,
                            accent: accent,
                            icon: switch (mode) {
                              ThemeMode.system =>
                                Icons.brightness_auto_rounded,
                              ThemeMode.light => Icons.light_mode_rounded,
                              ThemeMode.dark => Icons.dark_mode_rounded,
                            },
                            label: switch (mode) {
                              ThemeMode.system => 'System',
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                            },
                            onTap: () {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setMode(mode);
                              SettingsSyncService.instance
                                  .setThemeMode(mode.name);
                              setSheet(() {});
                            },
                          ),
                        ),
                        if (mode != ThemeMode.values.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _accentSheet() {
    final p = AppPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: Radii.brSheetTop,
      ),
      builder: (context) => const AccentColorPickerSheet(),
    );
  }

  void _homeLayoutSheet() {
    final p = AppPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: Radii.brSheetTop,
      ),
      builder: (context) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(appearanceLayoutProvider).homeLayout;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.textMuted.withValues(alpha: .5),
                        borderRadius: Radii.brPill,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Home layout',
                    style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                  ),
                  const SizedBox(height: 8),
                  for (final mode in HomeLayoutMode.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        mode == HomeLayoutMode.full
                            ? Icons.dashboard_customize_outlined
                            : mode == HomeLayoutMode.compact
                                ? Icons.view_compact_outlined
                                : Icons.view_agenda_outlined,
                        color: mode == current ? p.accent : p.textSecondary,
                      ),
                      title: Text(
                        mode.label,
                        style: AppTypography.bodyLarge(
                          context,
                          color: p.textPrimary,
                          weight: FontWeights.bold,
                        ),
                      ),
                      subtitle: Text(
                        mode.description,
                        style: AppTypography.labelMedium(context, color: p.textSecondary),
                      ),
                      trailing: mode == current
                          ? Icon(Icons.check_circle_rounded, color: p.accent)
                          : null,
                      onTap: () {
                        ref
                            .read(appearanceLayoutProvider.notifier)
                            .setHomeLayout(mode);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _bottomStyleSheet() {
    final p = AppPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: Radii.brSheetTop,
      ),
      builder: (context) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(appearanceLayoutProvider).bottomStyle;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.textMuted.withValues(alpha: .5),
                        borderRadius: Radii.brPill,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bottom bar style',
                    style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                  ),
                  const SizedBox(height: 8),
                  for (final style in BottomNavStyle.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        style == BottomNavStyle.floating
                            ? Icons.rounded_corner
                            : style == BottomNavStyle.docked
                                ? Icons.horizontal_rule_rounded
                                : Icons.more_horiz_rounded,
                        color: style == current ? p.accent : p.textSecondary,
                      ),
                      title: Text(
                        style.label,
                        style: AppTypography.bodyLarge(
                          context,
                          color: p.textPrimary,
                          weight: FontWeights.bold,
                        ),
                      ),
                      subtitle: Text(
                        style.description,
                        style: AppTypography.labelMedium(context, color: p.textSecondary),
                      ),
                      trailing: style == current
                          ? Icon(Icons.check_circle_rounded, color: p.accent)
                          : null,
                      onTap: () {
                        ref
                            .read(appearanceLayoutProvider.notifier)
                            .setBottomStyle(style);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _languageSheet() {
    final current = ref.read(languageProvider);
    final p = AppPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: Radii.brSheetTop,
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text('App Language',
                style: AppTypography.titleMedium(context, color: p.textPrimary, weight: FontWeights.extrabold)),
            const SizedBox(height: 8),
            for (final lang in supportedLanguages)
              ListTile(
                title: Text(lang.name),
                subtitle: Text(lang.nativeName,
                    style: AppTypography.labelMedium(context, color: p.textSecondary)),
                trailing: lang.code == current
                    ? Icon(Icons.check_circle_rounded, color: p.accent)
                    : null,
                onTap: () {
                  ref.read(languageProvider.notifier).setLanguage(lang.code);
                  SettingsSyncService.instance.setLanguage(lang.code);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(SettingsActionId action) async {
    switch (action) {
      case SettingsActionId.signOut:
        await _signOut();
      case SettingsActionId.resetApp:
        await _resetAppPreferences();
      case SettingsActionId.factoryReset:
        await _factoryReset();
      case SettingsActionId.clearCache:
        await _clearCache();
      case SettingsActionId.appearanceTheme:
        _themeSheet();
      case SettingsActionId.appearanceAccent:
        _accentSheet();
      case SettingsActionId.appearanceHomeLayout:
        _homeLayoutSheet();
      case SettingsActionId.appearanceBottomStyle:
        _bottomStyleSheet();
      case SettingsActionId.languagePicker:
        _languageSheet();
      case SettingsActionId.showLicenses:
        showLicensePage(context: context);
    }
  }

  Future<void> _handleItemTap(SettingsItem item) async {
    final availability = _resolver.resolve(item);
    if (!availability.isEnabled) {
      if (item.id.startsWith('perm_')) {
        await _openPermissionSettings(item);
        return;
      }
      _unavailable(item.title, availability.reason ?? 'Unavailable');
      return;
    }

    if (item.url != null && item.url!.isNotEmpty) {
      await _openUrl(item.url!);
      return;
    }

    if (item.route != null && item.route!.isNotEmpty) {
      context.push(item.route!);
      return;
    }

    if (item.actionId != null) {
      _handleAction(item.actionId!);
      return;
    }

    switch (item.id) {
      case 'upgrade_pro':
        await _startUpgradeCheckout();
        return;
      case 'export_data':
        await _exportUserData();
        return;
      case 'delete_account':
        await _deleteAccount();
        return;
      case 'change_password':
        await _changePassword();
        return;
      case 'conn_google':
        await _linkProvider('google');
        return;
      case 'conn_github':
        await _linkProvider('github');
        return;
      case 'conn_apple':
        await _linkProvider('apple');
        return;
    }

    if (item.type == SettingsItemType.navigation) {
      _unavailable(item.title, 'Requires additional service setup');
    }
  }

  Future<void> _startUpgradeCheckout() async {
    try {
      await SettingsCapabilityServices.billing.startCheckout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Stripe Checkout…'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _unavailable('Upgrade', e.toString());
      }
    }
  }

  Future<void> _exportUserData() async {
    final gdpr = SettingsCapabilityServices.gdpr;
    if (gdpr is! ConfiguredGdprCapability) {
      _unavailable('Download Data', gdpr.unavailableReason);
      return;
    }
    try {
      final msg = await gdpr.downloadExport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) _unavailable('Download Data', e.toString());
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text(
          'This cannot be undone. Your profile, jobs, and cloud data will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await SettingsCapabilityServices.gdpr.deleteAccount();
      await ref.read(authProvider.notifier).signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) _unavailable('Delete Account', e.toString());
    }
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (controller.text.length < 8) {
      _unavailable('Change Password', 'Password must be at least 8 characters');
      return;
    }
    if (controller.text != confirm.text) {
      _unavailable('Change Password', 'Passwords do not match');
      return;
    }
    try {
      await PasswordChangeService.instance.changePassword(controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) _unavailable('Change Password', e.toString());
    }
  }

  Future<void> _linkProvider(String provider) async {
    try {
      final linking = SettingsCapabilityServices.accountLinking;
      final linked = await linking.linkedProviders();
      if (!mounted) return;
      if (linked.contains(provider)) {
        final unlink = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Unlink $provider?'),
            content: Text('Remove $provider from this account.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Unlink'),
              ),
            ],
          ),
        );
        if (unlink == true) {
          await linking.unlinkProvider(provider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$provider unlinked'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        return;
      }
      await linking.linkProvider(provider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Continue in browser to link $provider'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) _unavailable('Connect', e.toString());
    }
  }

  String? _infoTrailing(SettingsItem item) {
    final user = ref.watch(authProvider);
    final entitlements = ref.watch(accountEntitlementsProvider);
    switch (item.id) {
      case 'account_status':
        if (user == null) return 'Not signed in';
        if (user.isGuest) return 'Guest mode';
        return user.email;
      case 'current_plan':
        return entitlements.planLabel;
      case 'credits_left':
        return entitlements.creditsLabel;
      case 'renew_date':
        return entitlements.renewDateLabel ??
            (entitlements.billingConfigured ? '—' : 'Not configured');
      case 'cloud_storage':
        return entitlements.storageLabel;
      case 'storage_usage':
        return entitlements.storageLabel;
      case 'version':
        return 'v${AppConfig.version}';
      case 'api_endpoint':
        return AppConfig.apiBaseUrl;
      default:
        return null;
    }
  }

  String? _actionTrailing(SettingsItem item) {
    switch (item.actionId) {
      case SettingsActionId.appearanceTheme:
      case SettingsActionId.appearanceAccent:
      case SettingsActionId.appearanceHomeLayout:
      case SettingsActionId.appearanceBottomStyle:
      case SettingsActionId.languagePicker:
        return _navigationTrailing(item);
      default:
        return null;
    }
  }

  String? _navigationTrailing(SettingsItem item) {
    if (item.comingSoon) return null;
    switch (item.id) {
      case 'theme_mode':
        final mode = ref.watch(themeModeProvider);
        return switch (mode) {
          ThemeMode.system => 'System',
          ThemeMode.light => 'Light',
          ThemeMode.dark => 'Dark',
        };
      case 'accent_color':
        final accent = ref.watch(accentColorProvider);
        final hex = (accent.toARGB32() & 0xFFFFFF)
            .toRadixString(16)
            .padLeft(6, '0')
            .toUpperCase();
        return '#$hex';
      case 'home_layout':
        return ref.watch(appearanceLayoutProvider).homeLayout.label;
      case 'bottom_nav_style':
        return ref.watch(appearanceLayoutProvider).bottomStyle.label;
      case 'app_language':
        final code = ref.watch(languageProvider);
        return supportedLanguages
            .firstWhere((l) => l.code == code,
                orElse: () => supportedLanguages.first)
            .name;
      default:
        return null;
    }
  }

  Widget? _buildTrailing(SettingsItem item) {
    final availability = _resolver.resolve(item);

    if (item.prefKey == 'biometricLock') {
      if (_biometricHardware != true) {
        return SettingsUnavailableBadge(
          reason: availability.reason ?? 'Biometrics unavailable',
        );
      }
      final value = ref.watch(biometricLockProvider);
      return SettingsGlowSwitch(
        value: value,
        onChanged: (v) async {
          if (v) {
            final ok =
                await ref.read(biometricServiceProvider).authenticate(
                      reason: 'Enable biometric lock for Farvixo',
                    );
            if (!ok) return;
            await ref.read(authProvider.notifier).enableBiometricLogin();
          }
          ref.read(biometricLockProvider.notifier).set(v);
        },
      );
    }

    final appearance = ref.watch(appearanceLayoutProvider);
    final appearanceNotifier = ref.read(appearanceLayoutProvider.notifier);
    switch (item.prefKey) {
      case 'homeShowHero':
        return SettingsGlowSwitch(
          value: appearance.homeShowHero,
          onChanged: appearanceNotifier.setHomeShowHero,
        );
      case 'homeShowQuickActions':
        return SettingsGlowSwitch(
          value: appearance.homeShowQuickActions,
          onChanged: appearanceNotifier.setHomeShowQuickActions,
        );
      case 'bottomShowLabels':
        return SettingsGlowSwitch(
          value: appearance.bottomShowLabels,
          onChanged: appearanceNotifier.setBottomShowLabels,
        );
      case 'bottomShowAiOrb':
        return SettingsGlowSwitch(
          value: appearance.bottomShowAiOrb,
          onChanged: appearanceNotifier.setBottomShowAiOrb,
        );
      case 'bottomBlur':
        return SettingsGlowSwitch(
          value: appearance.bottomBlur,
          onChanged: appearanceNotifier.setBottomBlur,
        );
    }

    final pref = prefKeyFromString(item.prefKey);
    if (item.type == SettingsItemType.toggle && pref != null) {
      // Email/marketing prefer backend; keep local persist but mark when unset.
      if ((pref == SettingsPrefKey.emailNotif ||
              pref == SettingsPrefKey.marketing) &&
          !AppConfig.supabaseEnabled) {
        return SettingsUnavailableBadge(
          reason: 'Email preference service not configured',
        );
      }
      final value = ref.watch(settingsPrefProvider(pref));
      return SettingsGlowSwitch(
        value: value,
        onChanged: (v) {
          ref.read(settingsPrefProvider(pref).notifier).set(v);
          _syncToggle(pref, v);
        },
      );
    }

    if (!availability.isEnabled &&
        item.type != SettingsItemType.info &&
        item.type != SettingsItemType.toggle) {
      return SettingsUnavailableBadge(
        reason: availability.reason ?? 'Unavailable',
      );
    }

    return null;
  }

  void _syncToggle(SettingsPrefKey pref, bool value) {
    switch (pref) {
      case SettingsPrefKey.sound:
        SettingsSyncService.instance.setSoundEnabled(value);
      case SettingsPrefKey.animations:
        SettingsSyncService.instance.setAnimationsEnabled(value);
      case SettingsPrefKey.push:
        SettingsSyncService.instance.setNotificationsEnabled(value);
      case SettingsPrefKey.emailNotif:
        SettingsSyncService.instance.setEmailNotifications(value);
      case SettingsPrefKey.marketing:
        SettingsSyncService.instance.setMarketingNotifications(value);
      case SettingsPrefKey.featureAi:
        SettingsSyncService.instance
            .push({'ai_assistant_enabled': value});
      case SettingsPrefKey.analytics:
        AnalyticsService.instance.setCollectionEnabled(value);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when live capability probes finish.
    ref.watch(settingsCapabilitiesProvider);
    ref.watch(accountEntitlementsRemoteProvider);

    final section = _section;
    if (section == null) {
      return Scaffold(
        body: PremiumBackground(
          child: SafeArea(
            child: PremiumEmptyState(
              icon: Icons.settings_outlined,
              title: 'Section not found',
              message: 'Unknown settings section "${widget.sectionId}".',
              actionLabel: 'Back to Settings',
              onAction: () => context.go('/settings'),
            ),
          ),
        ),
      );
    }

    final visibleItems = section.items.where((item) {
      if (item.prefKey == 'biometricLock' && _biometricHardware == false) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: PremiumHeader(
                  title: section.title,
                  subtitle: section.subtitle,
                  emoji: section.emoji,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/settings'),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < visibleItems.length; i++)
                            _buildItemTile(
                              visibleItems[i],
                              isLast: i == visibleItems.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(SettingsItem item, {required bool isLast}) {
    final availability = _resolver.resolve(item);
    final trailing = _buildTrailing(item);
    final infoText = item.type == SettingsItemType.info
        ? _infoTrailing(item)
        : _actionTrailing(item);

    VoidCallback? onTap;
    final isAppearanceToggle = item.prefKey == 'homeShowHero' ||
        item.prefKey == 'homeShowQuickActions' ||
        item.prefKey == 'bottomShowLabels' ||
        item.prefKey == 'bottomShowAiOrb' ||
        item.prefKey == 'bottomBlur';
    final isLocalToggle = item.type == SettingsItemType.toggle &&
        (item.prefKey == 'biometricLock' ||
            isAppearanceToggle ||
            prefKeyFromString(item.prefKey) != null) &&
        availability.isEnabled;

    if (isLocalToggle) {
      onTap = null;
    } else if (item.type == SettingsItemType.info) {
      onTap = null;
    } else {
      onTap = () => _handleItemTap(item);
    }

    final subtitle = !availability.isEnabled &&
            availability.reason != null &&
            item.type != SettingsItemType.toggle
        ? availability.reason
        : item.subtitle;

    return SettingsItemTile(
      icon: item.icon,
      iconColor: item.iconColor,
      title: item.title,
      subtitle: subtitle,
      trailing: trailing,
      trailingText: trailing == null ? infoText : null,
      destructive: item.destructive,
      isLast: isLast,
      enabled: availability.isEnabled || item.type == SettingsItemType.info,
      onTap: onTap,
    );
  }
}
