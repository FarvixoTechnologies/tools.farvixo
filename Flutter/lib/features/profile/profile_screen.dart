import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/tools_data.dart';
import '../../models/tool_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tool_activity_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/farvixo_logo.dart';
import '../../widgets/premium_kit.dart';

/// Profile — FARVIXO PROFILE_PAGE.md 2026 Enterprise Edition.
/// Identity · Premium · Stats · AI · Quick access · Settings · Support · Logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final p = AppPalette.of(context);
    final isPro = user?.isPro ?? false;
    final planLabel = switch (user?.plan.toLowerCase()) {
      'enterprise' => 'Enterprise',
      'pro' => 'Pro Plan',
      _ => 'Free Plan',
    };
    final favIds = ref.watch(favoriteToolsProvider);
    final recentIds = ref.watch(recentToolsProvider);
    final toolsUsed = recentIds.length;
    final favCount = favIds.length;
    // Local heuristic stats until backend analytics are wired.
    final aiChats = (toolsUsed * 3 + favCount).clamp(0, 9999);
    final filesProcessed = (toolsUsed * 12 + 40).clamp(0, 99999);
    final downloads = (toolsUsed * 4).clamp(0, 9999);
    final usagePct = isPro ? 0.78 : (toolsUsed / 20).clamp(0.05, 0.92);
    final creditsUsed = (usagePct * (isPro ? 10000 : 500)).round();
    final creditsTotal = isPro ? 10000 : 500;
    final storageUsed = isPro ? 23.6 : 0.8;
    final storageTotal = isPro ? 100.0 : 2.0;
    final displayName = user?.displayName ?? 'Guest';
    final email = user?.email ?? 'Not signed in';
    final username = _usernameOf(user);
    final initial = displayName.isNotEmpty
        ? displayName.characters.first.toUpperCase()
        : 'G';

    final recentTools = recentIds
        .map(ToolsData.toolById)
        .whereType<Tool>()
        .take(5)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  child: _ProfileTopBar(
                    onNotifications: () => context.push('/notifications'),
                    onSettings: () => context.push('/settings'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _ProfileHeader(
                      initial: initial,
                      displayName: displayName,
                      username: username,
                      email: email,
                      isPro: isPro,
                      isGuest: user?.isGuest ?? true,
                      onEdit: () => _snack(context, 'Edit profile coming soon'),
                      onQr: () => _snack(context, 'Profile QR coming soon'),
                      onShare: () => _shareProfile(context, displayName),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _PremiumCard(
                      isPro: isPro,
                      planLabel: planLabel,
                      usagePct: usagePct,
                      creditsUsed: creditsUsed,
                      creditsTotal: creditsTotal,
                      onUpgrade: () =>
                          _snack(context, 'Billing coming soon — stay tuned!'),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _StatsSection(
                      toolsUsed: toolsUsed,
                      aiChats: aiChats,
                      filesProcessed: filesProcessed,
                      downloads: downloads,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _AiAssistantCard(
                      usagePct: usagePct,
                      onNewChat: () => context.go('/ai'),
                      onManage: () => context.go('/ai'),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _QuickAccessRow(
                      onFavorites: () => context.go('/favorites'),
                      onHistory: () => context.push('/downloads'),
                      onDownloads: () => context.push('/downloads'),
                      onRecent: () => context.go('/tools'),
                      onCloud: () =>
                          _snack(context, 'Cloud storage coming soon'),
                    ),
                  ),
                ),
              ),
              if (recentTools.isNotEmpty)
                ..._activitySection(context, p, recentTools),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 7,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _StorageCard(
                      usedGb: storageUsed,
                      totalGb: storageTotal,
                      onManage: () =>
                          _snack(context, 'Manage storage coming soon'),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 8,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _MenuSection(
                      title: 'Account & Settings',
                      items: [
                        _MenuItemData(
                          icon: Icons.person_outline_rounded,
                          color: p.accent,
                          title: 'Account Settings',
                          subtitle: 'Personal info, email, phone',
                          onTap: () =>
                              _snack(context, 'Account settings coming soon'),
                        ),
                        _MenuItemData(
                          icon: Icons.tune_rounded,
                          color: AppColors.accentVideo,
                          title: 'App Preferences',
                          subtitle: 'Theme, language, notifications',
                          onTap: () => context.push('/settings'),
                        ),
                        _MenuItemData(
                          icon: Icons.shield_outlined,
                          color: AppColors.success,
                          title: 'Security & Privacy',
                          subtitle: 'Password, 2FA, active sessions',
                          onTap: () => context.push('/settings'),
                        ),
                        _MenuItemData(
                          icon: Icons.credit_card_rounded,
                          color: AppColors.goldPremium,
                          title: 'Subscription & Billing',
                          subtitle: 'Manage plan, payment methods',
                          onTap: () =>
                              _snack(context, 'Billing coming soon'),
                        ),
                        _MenuItemData(
                          icon: Icons.link_rounded,
                          color: AppColors.accentDev,
                          title: 'Linked Accounts',
                          subtitle: 'Google Drive, Dropbox, OneDrive',
                          onTap: () =>
                              _snack(context, 'Linked accounts coming soon'),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 9,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _ShortcutsGrid(
                      onHelp: () => _snack(context, 'Help Center coming soon'),
                      onCommunity: () =>
                          _snack(context, 'Community coming soon'),
                      onContact: () =>
                          _snack(context, 'Contact support coming soon'),
                      onFeature: () =>
                          _snack(context, 'Feature request coming soon'),
                      onRate: () => _snack(context, 'Thanks for supporting Farvixo!'),
                      onShare: () => _shareProfile(context, displayName),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 10,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _SupportCard(
                      onContact: () =>
                          _snack(context, 'Contact support coming soon'),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 11,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _MenuSection(
                      title: 'About',
                      items: [
                        _MenuItemData(
                          icon: Icons.info_outline_rounded,
                          color: p.textSecondary,
                          title: 'App Version',
                          subtitle: 'Farvixo 2026 · 1.0.0',
                          onTap: () {},
                        ),
                        _MenuItemData(
                          icon: Icons.privacy_tip_outlined,
                          color: p.textSecondary,
                          title: 'Privacy Policy',
                          subtitle: 'How we protect your data',
                          onTap: () =>
                              _snack(context, 'Privacy policy coming soon'),
                        ),
                        _MenuItemData(
                          icon: Icons.description_outlined,
                          color: p.textSecondary,
                          title: 'Terms of Service',
                          subtitle: 'Legal terms & conditions',
                          onTap: () =>
                              _snack(context, 'Terms coming soon'),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 12,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _LogoutButton(
                      onLogout: () => _confirmLogout(context, ref),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _activitySection(
    BuildContext context,
    AppPalette p,
    List<Tool> tools,
  ) {
    return [
      SliverToBoxAdapter(
        child: FadeSlideIn(
          index: 6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/tools'),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ...tools.asMap().entries.map((e) {
        final tool = e.value;
        final cat = ToolsData.categoryOf(tool);
        return SliverToBoxAdapter(
          child: FadeSlideIn(
            index: 6 + e.key,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/tool/${tool.id}'),
                  child: Ink(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(tool.icon, color: cat.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tool.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary,
                                ),
                              ),
                              Text(
                                'Used recently',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ];
  }

  static String _usernameOf(AppUser? user) {
    if (user == null || user.isGuest) return '@guest';
    final base = (user.fullName ?? user.email.split('@').first)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '@${base.isEmpty ? 'user' : base}';
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<void> _shareProfile(
      BuildContext context, String name) async {
    await Clipboard.setData(
      ClipboardData(text: 'Check out $name on Farvixo — https://tools.farvixo.com'),
    );
    if (context.mounted) {
      _snack(context, 'Profile link copied');
    }
  }

  static Future<void> _confirmLogout(
      BuildContext context, WidgetRef ref) async {
    final p = AppPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign out?',
          style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'You can sign back in anytime with the same account.',
          style: TextStyle(color: p.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: p.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(authProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({
    required this.onNotifications,
    required this.onSettings,
  });

  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
      child: Row(
        children: [
          const FarvixoLogo(size: 30, glow: true),
          const SizedBox(width: 8),
          Text(
            'Farvixo',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _RoundIcon(icon: Icons.notifications_none_rounded, onTap: onNotifications),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          _RoundIcon(icon: Icons.settings_outlined, onTap: onSettings),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, size: 20, color: p.textPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initial,
    required this.displayName,
    required this.username,
    required this.email,
    required this.isPro,
    required this.isGuest,
    required this.onEdit,
    required this.onQr,
    required this.onShare,
  });

  final String initial;
  final String displayName;
  final String username;
  final String email;
  final bool isPro;
  final bool isGuest;
  final VoidCallback onEdit;
  final VoidCallback onQr;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        p.accent,
                        Color.lerp(p.accent, AppColors.brandMagenta, 0.55)!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.45),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.surface,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: p.accent,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.bg, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      if (!isGuest) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: p.accent,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isGuest ? 'Guest session' : 'Member since 2026',
                    style: TextStyle(fontSize: 11.5, color: p.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.textPrimary,
                  side: BorderSide(color: p.border),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SquareAction(icon: Icons.qr_code_2_rounded, onTap: onQr),
            const SizedBox(width: 8),
            _SquareAction(icon: Icons.ios_share_rounded, onTap: onShare),
          ],
        ),
      ],
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, size: 20, color: p.textPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({
    required this.isPro,
    required this.planLabel,
    required this.usagePct,
    required this.creditsUsed,
    required this.creditsTotal,
    required this.onUpgrade,
  });

  final bool isPro;
  final String planLabel;
  final double usagePct;
  final int creditsUsed;
  final int creditsTotal;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E1065), Color(0xFF4C1D95), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Farvixo Premium',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.goldPremium.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.goldPremium.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  planLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.goldPremium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isPro
                ? 'Renews on the 1st of next month'
                : 'Unlock unlimited tools & AI power',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final item in const [
                (Icons.all_inclusive_rounded, 'Unlimited'),
                (Icons.auto_awesome_rounded, 'Premium AI'),
                (Icons.block_rounded, 'No Ads'),
                (Icons.support_agent_rounded, 'Priority'),
              ]) ...[
                Expanded(
                  child: Column(
                    children: [
                      Icon(item.$1,
                          size: 18, color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Usage This Month',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Text(
                '${(usagePct * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: usagePct,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              color: const Color(0xFFA78BFA),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(creditsUsed)} / ${_fmt(creditsTotal)} Credits',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onUpgrade,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4C1D95),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isPro ? 'Manage Plan' : 'Upgrade Plan',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats
// ─────────────────────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.toolsUsed,
    required this.aiChats,
    required this.filesProcessed,
    required this.downloads,
  });

  final int toolsUsed;
  final int aiChats;
  final int filesProcessed;
  final int downloads;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Your Statistics',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: p.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              'View All',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: p.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.handyman_rounded,
                color: p.accent,
                value: '$toolsUsed',
                label: 'Tools Used',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.chat_bubble_rounded,
                color: AppColors.success,
                value: '$aiChats',
                label: 'AI Chats',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.folder_rounded,
                color: AppColors.accentDev,
                value: filesProcessed >= 1000
                    ? '${(filesProcessed / 1000).toStringAsFixed(1)}K'
                    : '$filesProcessed',
                label: 'Files Processed',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.download_rounded,
                color: AppColors.accentAudio,
                value: '$downloads',
                label: 'Downloads',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI card
// ─────────────────────────────────────────────────────────────────────────────

class _AiAssistantCard extends StatelessWidget {
  const _AiAssistantCard({
    required this.usagePct,
    required this.onNewChat,
    required this.onManage,
  });

  final double usagePct;
  final VoidCallback onNewChat;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI Assistant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'BETA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: p.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Gemini 1.5 Pro',
                      style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: onNewChat,
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'New Chat',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Memory',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${(usagePct * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: usagePct,
              minHeight: 6,
              backgroundColor: p.surface2,
              color: p.accent,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onManage,
              child: Text(
                'Manage AI ›',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: p.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick access
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow({
    required this.onFavorites,
    required this.onHistory,
    required this.onDownloads,
    required this.onRecent,
    required this.onCloud,
  });

  final VoidCallback onFavorites;
  final VoidCallback onHistory;
  final VoidCallback onDownloads;
  final VoidCallback onRecent;
  final VoidCallback onCloud;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.favorite_rounded, AppColors.brandMagenta, 'Favorites', onFavorites),
      (Icons.history_rounded, AppColors.accentVideo, 'History', onHistory),
      (Icons.download_rounded, AppColors.accentDev, 'Downloads', onDownloads),
      (Icons.folder_open_rounded, AppColors.accentAudio, 'Recent', onRecent),
      (Icons.cloud_rounded, AppColors.accentAi, 'Cloud', onCloud),
    ];
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          final p = AppPalette.of(context);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: item.$4,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.$2.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.$1, color: item.$2, size: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Storage
// ─────────────────────────────────────────────────────────────────────────────

class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.usedGb,
    required this.totalGb,
    required this.onManage,
  });

  final double usedGb;
  final double totalGb;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pct = (usedGb / totalGb).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_rounded, color: p.accent, size: 22),
              const SizedBox(width: 8),
              Text(
                'Cloud Storage',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${usedGb.toStringAsFixed(1)} / ${totalGb.toStringAsFixed(0)} GB',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: p.surface2,
              color: p.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(pct * 100).round()}% used',
            style: TextStyle(fontSize: 11.5, color: p.textMuted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onManage,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.accent,
                side: BorderSide(color: p.accent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Manage Storage',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menus / shortcuts / support / logout
// ─────────────────────────────────────────────────────────────────────────────

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<_MenuItemData> items;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              for (final item in items) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.circular(
                      item.isLast && items.first == item
                          ? 18
                          : item.isLast
                              ? 18
                              : items.first == item
                                  ? 18
                                  : 0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.icon, color: item.color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: p.textPrimary,
                                  ),
                                ),
                                Text(
                                  item.subtitle,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: p.textMuted, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!item.isLast)
                  Divider(height: 1, color: p.border, indent: 66),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShortcutsGrid extends StatelessWidget {
  const _ShortcutsGrid({
    required this.onHelp,
    required this.onCommunity,
    required this.onContact,
    required this.onFeature,
    required this.onRate,
    required this.onShare,
  });

  final VoidCallback onHelp;
  final VoidCallback onCommunity;
  final VoidCallback onContact;
  final VoidCallback onFeature;
  final VoidCallback onRate;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final items = [
      (Icons.help_outline_rounded, 'Help', onHelp),
      (Icons.groups_rounded, 'Community', onCommunity),
      (Icons.mail_outline_rounded, 'Contact', onContact),
      (Icons.lightbulb_outline_rounded, 'Request', onFeature),
      (Icons.star_outline_rounded, 'Rate', onRate),
      (Icons.share_outlined, 'Share', onShare),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: item.$3,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                color: p.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.$1, color: p.accent, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onContact});
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.headset_mic_rounded, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need Help?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  'Our team is here for you 24/7',
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onContact,
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Contact',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
              SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
