import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';

/// Settings — "Customize your experience ✨"
/// Premium glass design: glowing profile card with stats, grouped sections
/// (Preferences / Account & Security / Data & Storage / General), logout.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..forward();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);

  // local demo toggles (no persisted keys yet)
  bool _sound = true;
  bool _animations = true;

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Widget _entrance(int index, Widget child) {
    final start = (index * 0.09).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .1), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }

  void _soon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ------------------------------------------------------------- sheets

  void _themeSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.bgSurface : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF1A1330);
    final mutedColor =
        isDark ? AppColors.textMuted : const Color(0xFF8A88A3);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        // StatefulBuilder so swatch/mode selection updates the sheet live.
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
                        color: mutedColor.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('🎨 Appearance',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textColor)),
                  const SizedBox(height: 4),
                  Text('Base mode',
                      style: TextStyle(fontSize: 12.5, color: mutedColor)),
                  const SizedBox(height: 10),
                  // -------- base mode selector --------
                  Row(
                    children: [
                      for (final mode in ThemeMode.values) ...[
                        Expanded(
                          child: _ModeChip(
                            selected: mode == current,
                            accent: accent,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            isDark: isDark,
                            icon: switch (mode) {
                              ThemeMode.system => Icons.brightness_auto_rounded,
                              ThemeMode.light => Icons.light_mode_rounded,
                              ThemeMode.dark => Icons.dark_mode_rounded,
                            },
                            label: switch (mode) {
                              ThemeMode.system => 'System',
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                            },
                            onTap: () {
                              ref.read(themeModeProvider.notifier).setMode(mode);
                              setSheet(() {});
                            },
                          ),
                        ),
                        if (mode != ThemeMode.values.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Accent color',
                      style: TextStyle(fontSize: 12.5, color: mutedColor)),
                  const SizedBox(height: 12),
                  // -------- accent swatch grid --------
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final color in AccentPresets.all)
                        _Swatch(
                          color: color,
                          selected: color.toARGB32() == accent.toARGB32(),
                          onTap: () {
                            ref
                                .read(accentColorProvider.notifier)
                                .setColor(color);
                            setSheet(() {});
                          },
                        ),
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

  void _languageSheet() {
    final current = ref.read(languageProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            const Text('🌐 Language',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final lang in supportedLanguages)
              ListTile(
                title: Text(lang.name),
                subtitle: Text(lang.nativeName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                trailing: lang.code == current
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.brandPrimaryHover)
                    : null,
                onTap: () {
                  ref.read(languageProvider.notifier).setLanguage(lang.code);
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

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cache?'),
        content: const Text('This will free up 256 MB of space.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Cache cleared — 256 MB freed'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final langCode = ref.watch(languageProvider);
    final langName = supportedLanguages
        .firstWhere((l) => l.code == langCode,
            orElse: () => supportedLanguages.first)
        .name;

    return Scaffold(
      backgroundColor: AppPalette.of(context).bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                // ================= header =================
                _entrance(
                  0,
                  Row(
                    children: [
                      _CircleBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/home'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Settings',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800)),
                            Text('Customize your experience ✨',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppPalette.of(context).textSecondary)),
                          ],
                        ),
                      ),
                      _CircleBtn(
                          icon: Icons.search_rounded,
                          onTap: () => context.push('/search')),
                      const SizedBox(width: 8),
                      _CircleBtn(
                        icon: Icons.notifications_outlined,
                        badge: '7',
                        onTap: () => context.push('/notifications'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ================= profile card =================
                _entrance(
                  1,
                  _GlassCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // glowing avatar + camera badge
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (context, child) => Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.brandGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.brandPrimary
                                          .withValues(
                                              alpha:
                                                  .3 + _pulse.value * .3),
                                      blurRadius: 18 + _pulse.value * 8,
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: AppPalette.of(context).surface2,
                                    child: Text(
                                      (user?.displayName.isNotEmpty ?? false)
                                          ? user!.displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              AppColors.brandPrimaryHover),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppPalette.of(context).surface2,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppPalette.of(context).border),
                                      ),
                                      child: const Icon(
                                          Icons.photo_camera_outlined,
                                          size: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user?.displayName ?? 'Guest',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified_rounded,
                                          size: 17,
                                          color:
                                              AppColors.brandPrimaryHover),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(
                                          text: user?.email ?? ''));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text('📋 Email copied'),
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                    },
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user?.email ?? '—',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors
                                                    .textSecondary),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        const Icon(Icons.copy_rounded,
                                            size: 12,
                                            color: AppColors.textMuted),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (user?.isPro ?? false)
                                          ? AppColors.goldPremium
                                              .withValues(alpha: .14)
                                          : AppColors.brandPrimary
                                              .withValues(alpha: .14),
                                      borderRadius:
                                          BorderRadius.circular(99),
                                      border: Border.all(
                                        color: (user?.isPro ?? false)
                                            ? AppColors.goldPremium
                                                .withValues(alpha: .4)
                                            : AppColors.brandPrimaryHover
                                                .withValues(alpha: .4),
                                      ),
                                    ),
                                    child: Text(
                                      (user?.isPro ?? false)
                                          ? '👑 Pro Member'
                                          : '⭐ Free Plan',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: (user?.isPro ?? false)
                                            ? AppColors.goldPremium
                                            : AppColors.brandPrimaryHover,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => context.push('/profile'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: AppColors.brandPrimaryHover
                                        .withValues(alpha: .5)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                // The global theme sets minimumSize to
                                // Size.fromHeight(52) = infinite width, which
                                // made this button eat the whole row and
                                // collapse the name/email column. Pin it to
                                // wrap its content instead.
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Edit Profile',
                                  style: TextStyle(fontSize: 12.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        // stats row
                        Row(
                          children: [
                            _ProfileStat(
                              icon: Icons.calendar_month_rounded,
                              color: AppColors.brandPrimaryHover,
                              label: 'Member Since',
                              value: 'Apr 2024',
                            ),
                            _ProfileStat(
                              icon: Icons.workspace_premium_rounded,
                              color: AppColors.goldPremium,
                              label: 'Plan',
                              value: (user?.isPro ?? false) ? 'Pro' : 'Free',
                            ),
                            _ProfileStat(
                              icon: Icons.auto_awesome_rounded,
                              color: AppColors.accentDev,
                              label: 'AI Credits',
                              value: '1,250',
                            ),
                            _ProfileStat(
                              icon: Icons.cloud_outlined,
                              color: AppColors.accentText,
                              label: 'Cloud Storage',
                              value: '100 GB',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ================= preferences =================
                _entrance(2, const _SectionLabel('Preferences')),
                _entrance(
                  2,
                  _GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingTile(
                          icon: Icons.palette_outlined,
                          color: AppColors.brandMagenta,
                          title: 'Appearance',
                          subtitle: 'Theme, colors, dark mode',
                          trailingText: switch (themeMode) {
                            ThemeMode.system => 'System',
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                          },
                          onTap: _themeSheet,
                        ),
                        _SettingTile(
                          icon: Icons.language_rounded,
                          color: AppColors.accentDev,
                          title: 'Language',
                          subtitle: 'Change app language',
                          trailingText: langName,
                          onTap: _languageSheet,
                        ),
                        _SettingTile(
                          icon: Icons.dashboard_customize_outlined,
                          color: AppColors.accentImage,
                          title: 'Home Customization',
                          subtitle: 'Customize your home dashboard',
                          onTap: () => _soon('Home Customization'),
                        ),
                        _SettingTile(
                          icon: Icons.volume_up_outlined,
                          color: AppColors.accentAudio,
                          title: 'Sound & Haptics',
                          subtitle: 'Manage sounds and vibration',
                          trailing: _GlowSwitch(
                            value: _sound,
                            onChanged: (v) => setState(() => _sound = v),
                          ),
                        ),
                        _SettingTile(
                          icon: Icons.auto_fix_high_rounded,
                          color: AppColors.accentAi,
                          title: 'Animations',
                          subtitle: 'Enable or disable animations',
                          trailing: _GlowSwitch(
                            value: _animations,
                            onChanged: (v) =>
                                setState(() => _animations = v),
                          ),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ================= account & security =================
                _entrance(3, const _SectionLabel('Account & Security')),
                _entrance(
                  3,
                  _GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingTile(
                          icon: Icons.shield_outlined,
                          color: AppColors.success,
                          title: 'Security',
                          subtitle: 'Password, 2FA, biometric & more',
                          onTap: () => _soon('Security center'),
                        ),
                        _SettingTile(
                          icon: Icons.lock_outline_rounded,
                          color: AppColors.accentText,
                          title: 'Privacy',
                          subtitle: 'Manage your privacy settings',
                          onTap: () => _soon('Privacy'),
                        ),
                        _SettingTile(
                          icon: Icons.devices_rounded,
                          color: AppColors.brandPrimaryHover,
                          title: 'Devices',
                          subtitle: 'Manage your connected devices',
                          onTap: () => _soon('Devices'),
                        ),
                        _SettingTile(
                          icon: Icons.person_pin_circle_outlined,
                          color: AppColors.accentDev,
                          title: 'Active Sessions',
                          subtitle: 'View and manage active sessions',
                          onTap: () => _soon('Active Sessions'),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ================= data & storage =================
                _entrance(4, const _SectionLabel('Data & Storage')),
                _entrance(
                  4,
                  _GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingTile(
                          icon: Icons.cloud_upload_outlined,
                          color: AppColors.accentText,
                          title: 'Storage Management',
                          subtitle: 'Manage cloud and local storage',
                          trailingText: '100 GB Used',
                          onTap: () => _soon('Storage Management'),
                        ),
                        _SettingTile(
                          icon: Icons.settings_backup_restore_rounded,
                          color: AppColors.success,
                          title: 'Backup & Restore',
                          subtitle: 'Backup your data and restore',
                          onTap: () => _soon('Backup & Restore'),
                        ),
                        _SettingTile(
                          icon: Icons.cleaning_services_outlined,
                          color: AppColors.error,
                          title: 'Clear Cache',
                          subtitle: 'Free up space by clearing cache',
                          trailingText: '256 MB',
                          trailingColor: AppColors.brandMagenta,
                          onTap: _clearCache,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ================= general (2-column) =================
                _entrance(5, const _SectionLabel('General')),
                _entrance(
                  5,
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoCol = constraints.maxWidth > 430;
                      final items = [
                        _GeneralItem(
                          icon: Icons.notifications_none_rounded,
                          color: AppColors.accentAudio,
                          title: 'Notifications',
                          subtitle: 'Manage notification preferences',
                          onTap: () => context.push('/notifications'),
                        ),
                        _GeneralItem(
                          icon: Icons.star_border_rounded,
                          color: AppColors.goldPremium,
                          title: 'Rate Farvixo',
                          subtitle: 'Rate us on Play Store',
                          onTap: () => _soon('Rate Farvixo'),
                        ),
                        _GeneralItem(
                          icon: Icons.system_update_alt_rounded,
                          color: AppColors.accentText,
                          title: 'App Updates',
                          subtitle: 'Check for updates',
                          trailingText: 'v${AppConfig.version}',
                          onTap: () => _soon('App Updates'),
                        ),
                        _GeneralItem(
                          icon: Icons.share_outlined,
                          color: AppColors.accentImage,
                          title: 'Share Farvixo',
                          subtitle: 'Invite your friends',
                          onTap: () => _soon('Share Farvixo'),
                        ),
                        _GeneralItem(
                          icon: Icons.headset_mic_outlined,
                          color: AppColors.brandPrimaryHover,
                          title: 'Help & Support',
                          subtitle: 'Get help and contact support',
                          onTap: () => _soon('Help & Support'),
                        ),
                        _GeneralItem(
                          icon: Icons.info_outline_rounded,
                          color: AppColors.accentDev,
                          title: 'About Farvixo',
                          subtitle: 'App info, terms & policies',
                          onTap: () => showAboutDialog(
                            context: context,
                            applicationName: 'Farvixo',
                            applicationVersion: 'v${AppConfig.version}',
                            applicationLegalese:
                                'Smart Tools. AI Power. Limitless Possibilities.',
                          ),
                        ),
                      ];
                      if (!twoCol) {
                        return Column(children: [
                          for (final it in items)
                            Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: it),
                        ]);
                      }
                      return Column(children: [
                        for (var i = 0; i < items.length; i += 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(children: [
                              Expanded(child: items[i]),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: i + 1 < items.length
                                      ? items[i + 1]
                                      : const SizedBox()),
                            ]),
                          ),
                      ]);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ================= logout =================
                _entrance(
                  6,
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _logout,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: .35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: AppColors.error, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Logout',
                                    style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error)),
                                Text('Sign out from your account',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.error),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// building blocks
// =============================================================================

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap, this.badge});
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppPalette.of(context).surface.withValues(alpha: .8),
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.of(context).border),
            ),
            child: Icon(icon, size: 20),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4.5),
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.of(context).surface.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.of(context).border),
      ),
      child: child,
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9.5, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingText,
    this.trailingColor,
    this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? trailingText;
  final Color? trailingColor;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: .18),
                          blurRadius: 10),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else ...[
                  if (trailingText != null)
                    Text(trailingText!,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: trailingColor ??
                                AppColors.brandPrimaryHover)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.textMuted),
                ],
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 68, endIndent: 14),
      ],
    );
  }
}

class _GeneralItem extends StatelessWidget {
  const _GeneralItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppPalette.of(context).surface.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.of(context).border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (trailingText != null)
              Text(trailingText!,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentText)),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Gradient animated switch (design: violet glow pill).
class _GlowSwitch extends StatelessWidget {
  const _GlowSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 27,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: value ? AppColors.brandGradient : null,
          color: value ? null : AppColors.bgSurface2,
          border: Border.all(
              color: value
                  ? Colors.transparent
                  : AppColors.borderSubtle),
          boxShadow: value
              ? [
                  BoxShadow(
                      color:
                          AppColors.brandPrimary.withValues(alpha: .45),
                      blurRadius: 10),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              color: value ? Colors.white : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Base-mode chip (System / Light / Dark) in the appearance sheet.
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.selected,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final Color accent;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: .14)
              : (isDark ? AppColors.bgSurface2 : const Color(0xFFF1F1F8)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: .7)
                : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22, color: selected ? accent : mutedColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? accent : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular accent swatch with a check when selected.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? .55 : .3),
              blurRadius: selected ? 14 : 8,
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? .9 : 0),
            width: 2.5,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}
