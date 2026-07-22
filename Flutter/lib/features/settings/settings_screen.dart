import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/account_entitlements_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/profile_details_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/design_tokens.dart';
import '../../utils/profile_actions.dart';
import '../../utils/profile_link.dart';
import '../../widgets/premium_kit.dart';
import '../profile/my_qr_screen.dart';
import 'settings_capability.dart';
import 'settings_v5_widgets.dart';

/// Farvixo Settings — Enterprise Mobile UI v5.0
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: Motion.verySlow,
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Motion.breathe,
  )..repeat(reverse: true);

  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: Motion.ambient,
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    _wave.dispose();
    super.dispose();
  }

  Widget _enter(int i, Widget child) {
    final start = (i * 0.045).clamp(0.0, 0.7);
    final curved = CurvedAnimation(
      parent: _intro,
      curve: Interval(
        start,
        (start + 0.28).clamp(0.0, 1.0),
        curve: Motion.easeOut,
      ),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  void _haptic() {
    final on = ref.read(settingsPrefProvider(SettingsPrefKey.haptics));
    if (on) HapticFeedback.selectionClick();
  }

  void _soon(String label, {String reason = 'Requires additional service setup'}) {
    _haptic();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — $reason'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openHubSection(String id) {
    if (id == 'devices' || id == 'sessions_devices') {
      context.push('/devices');
      return;
    }
    if (id == 'downloads' || id == 'manage_downloads') {
      context.push('/downloads');
      return;
    }
    context.push('/settings/$id');
  }

  Future<void> _shareProfileFromSettings() async {
    _haptic();
    final user = ref.read(authProvider);
    final details = ref.read(profileDetailsProvider);
    final name = details.displayName.isNotEmpty
        ? details.displayName
        : (user?.displayName ?? 'Farvixo');
    final url = ProfileLink.forUser(user: user, details: details);
    await Share.share(
      ProfileLink.shareText(displayName: name, url: url),
      subject: '$name · Farvixo',
    );
  }

  List<(IconData, Color, String, String, String)> _hubRows(
    SettingsHubGroup group, {
    String? subscriptionSubtitle,
  }) {
    final rows = <(IconData, Color, String, String, String)>[];
    for (final row in hubMenuRowsFor(group)) {
      var subtitle = row.$4;
      if (row.$5 == 'subscription' && subscriptionSubtitle != null) {
        subtitle = subscriptionSubtitle;
      }
      rows.add((row.$1, row.$2, row.$3, subtitle, row.$5));
    }
    if (group.title == 'Account & Security') {
      rows.add((
        Icons.devices_outlined,
        AppColors.accentAi,
        'Devices & Sessions',
        'Active sessions on your account',
        'devices',
      ));
    }
    return rows;
  }

  Future<bool?> _confirmSheet({
    required String title,
    required String body,
    required String confirmLabel,
    Color? confirmColor,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final p = AppPalette.of(ctx);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: Radii.brBanner,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.92),
                  borderRadius: Radii.brBanner,
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: Radii.brPill,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.black),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium(context, color: p.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  confirmColor ?? AppColors.brandPrimary,
                            ),
                            child: Text(confirmLabel),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut() async {
    final ok = await _confirmSheet(
      title: 'Sign Out?',
      body: 'You will need to sign in again to sync cloud files and credits.',
      confirmLabel: 'Sign Out',
      confirmColor: AppColors.destructive,
    );
    if (ok == true && mounted) {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  void _toggleTheme() {
    final mode = ref.read(themeModeProvider);
    final next = switch (mode) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
      ThemeMode.system => ThemeMode.dark,
    };
    ref.read(themeModeProvider.notifier).setMode(next);
    final hapticsOn = ref.read(settingsPrefProvider(SettingsPrefKey.haptics));
    if (hapticsOn) HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final user = ref.watch(authProvider);
    final entitlements = ref.watch(accountEntitlementsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final lang = ref.watch(languageProvider);
    final animationsOn = ref.watch(animationsEnabledProvider);
    final hapticsOn = ref.watch(settingsPrefProvider(SettingsPrefKey.haptics));
    final accountGroup = kSettingsHubGroups[0];
    final advancedGroup = kSettingsHubGroups[1];
    final activityGroup = kSettingsHubGroups[2];

    final name = user?.displayName ?? 'Guest';
    final email = user?.email ?? 'guest@farvixo.com';
    final username =
        '@${(user?.isGuest ?? true) ? 'guest' : email.split('@').first}';
    final isPro = user?.isPro ?? false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';
    final creditsUsed = entitlements.creditsUsed;
    final creditsMax = entitlements.creditsMax;
    final storageUsed = entitlements.storageUsedGb;
    final storageMax = entitlements.storageMaxGb;

    return Scaffold(
      backgroundColor: p.bg,
      body: PremiumBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _wave,
                  builder: (context, _) =>
                      CustomPaint(painter: SettingsMeshPainter(_wave.value)),
                ),
              ),
            ),
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _enter(
                      0,
                      SettingsV5Header(
                        onBack: () => context.canPop()
                            ? context.pop()
                            : context.go('/home'),
                        onSearch: () => _soon('Search settings'),
                        onThemeToggle: _toggleTheme,
                        themeMode: themeMode,
                        wave: _wave,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _enter(
                          1,
                          SettingsProfileHero(
                            name: name,
                            username: username,
                            email: email,
                            initial: initial,
                            avatarUrl: user?.avatarUrl,
                            isPro: isPro,
                            isGuest: user?.isGuest ?? true,
                            pulse: _pulse,
                            onCamera: () => pickAndUploadAvatar(context, ref),
                            onEdit: () => showEditProfileDialog(context, ref),
                            onCopyEmail: () {
                              Clipboard.setData(ClipboardData(text: email));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Email copied'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            creditsUsed: creditsUsed,
                            creditsMax: creditsMax,
                            storageUsedGb: storageUsed,
                            storageMaxGb: storageMax,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _enter(
                          2,
                          SettingsQuickActions(
                            onTap: (id, label) {
                              switch (id) {
                                case 'qr':
                                  openMyQr(context);
                                case 'share':
                                  _shareProfileFromSettings();
                                case 'downloads':
                                  context.push('/downloads');
                                case 'activity':
                                  context.push('/settings/activity');
                                case 'favorites':
                                  context.push('/favorites');
                                case 'saved_ai':
                                  context.push('/ai');
                                default:
                                  _soon(label);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 22),
                        _enter(
                          4,
                          SettingsSectionLabel(
                            title: 'Preferences',
                            actionLabel: 'View All',
                            onAction: () =>
                                context.push('/settings/appearance'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _enter(
                          5,
                          SettingsPreferencesGrid(
                            themeLabel: switch (themeMode) {
                              ThemeMode.system => 'System',
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                            },
                            languageLabel: languageLabel(lang),
                            animationsOn: animationsOn,
                            hapticsOn: hapticsOn,
                            onOpen: (sectionId) =>
                                context.push('/settings/$sectionId'),
                            onToggleAnimations: (v) => ref
                                .read(animationsEnabledProvider.notifier)
                                .set(v),
                            onToggleHaptics: (v) => ref
                                .read(
                                  settingsPrefProvider(
                                    SettingsPrefKey.haptics,
                                  ).notifier,
                                )
                                .set(v),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _enter(
                          6,
                          SettingsSectionLabel(
                            title: accountGroup.title,
                            actionLabel: accountGroup.actionLabel,
                            onAction: accountGroup.actionSectionId == null
                                ? null
                                : () => context.push(
                                      '/settings/${accountGroup.actionSectionId}',
                                    ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _enter(
                          7,
                          SettingsMenuList(
                            items: _hubRows(accountGroup),
                            onTap: _openHubSection,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _enter(
                          8,
                          SettingsSectionLabel(title: advancedGroup.title),
                        ),
                        const SizedBox(height: 10),
                        _enter(
                          9,
                          SettingsMenuList(
                            items: _hubRows(
                              advancedGroup,
                              subscriptionSubtitle:
                                  entitlements.hubSubscriptionSubtitle,
                            ),
                            onTap: _openHubSection,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _enter(
                          10,
                          SettingsSectionLabel(title: activityGroup.title),
                        ),
                        const SizedBox(height: 10),
                        _enter(
                          11,
                          SettingsMenuList(
                            items: _hubRows(activityGroup),
                            onTap: _openHubSection,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _enter(
                          12,
                          SettingsGradientSignOut(onTap: _confirmSignOut),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String languageLabel(String code) {
  switch (code) {
    case 'bn':
      return 'বাংলা';
    case 'hi':
      return 'हिन्दी';
    case 'es':
      return 'Español';
    case 'ar':
      return 'العربية';
    case 'zh':
      return '中文';
    default:
      return 'English';
  }
}

/// Soft mesh orbs + particles behind the Settings scroll.
class SettingsMeshPainter extends CustomPainter {
  SettingsMeshPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    paint.color = AppColors.brandPrimary.withValues(alpha: 0.16);
    canvas.drawCircle(
      Offset(
        size.width * 0.18,
        size.height * (0.08 + 0.02 * math.sin(t * math.pi * 2)),
      ),
      90,
      paint,
    );
    paint.color = AppColors.brandMagenta.withValues(alpha: 0.12);
    canvas.drawCircle(
      Offset(
        size.width * 0.88,
        size.height * (0.18 + 0.03 * math.cos(t * math.pi * 2)),
      ),
      70,
      paint,
    );
    paint.color = AppColors.accentDev.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(
        size.width * 0.55,
        size.height * (0.42 + 0.02 * math.sin(t * math.pi * 2 + 1)),
      ),
      110,
      paint,
    );

    final particle = Paint()..color = AppColors.onAccent.withValues(alpha: 0.08);
    for (var i = 0; i < 18; i++) {
      final x =
          (size.width * ((i * 37) % 100) / 100) +
          8 * math.sin(t * math.pi * 2 + i);
      final y =
          (size.height * ((i * 53) % 100) / 100) * 0.55 +
          6 * math.cos(t * math.pi * 2 + i * 0.7);
      canvas.drawCircle(Offset(x, y), 1.6 + (i % 3) * 0.4, particle);
    }
  }

  @override
  bool shouldRepaint(covariant SettingsMeshPainter oldDelegate) =>
      oldDelegate.t != t;
}
