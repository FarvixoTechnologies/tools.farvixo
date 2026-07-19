import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_details_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import '../../utils/profile_actions.dart';
import '../../widgets/premium_kit.dart';

/// Farvixo Profile — Enterprise Mobile UI v4.0
/// Ultra Premium · Glassmorphism · AI OS · Mobile First
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  // Bespoke, vibrant profile palette (matches the approved hero design).
  // Status hues route through AppColors tokens; the gradient accents below are
  // intentionally distinct from the category tokens for the hero look.
  static const _purple = Color(0xFF7B3FF2);
  static const _blue = Color(0xFF4D8DFF);
  static const _pink = Color(0xFFFF4FD8);
  static const _success = AppColors.success;
  static const _warning = Color(0xFFF59E0B);
  static const _danger = AppColors.error;
  static const _orange = Color(0xFFFF7A3D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final details = ref.watch(profileDetailsProvider);

    final isPro = user?.isPro ?? false;
    final isGuest = user?.isGuest ?? true;
    final displayName = details.displayName.isNotEmpty
        ? details.displayName
        : (user?.displayName ?? 'Guest');
    final email = user?.email ?? 'Not signed in';
    final username =
        '@${details.username.isNotEmpty ? details.username : 'guest'}';
    final planLabel = switch (user?.plan.toLowerCase()) {
      'enterprise' => 'Enterprise',
      'pro' => 'Pro',
      _ => 'Free',
    };
    final avatarUrl = details.avatarUrl ?? user?.avatarUrl;
    final initial = displayName.isNotEmpty
        ? displayName.characters.first.toUpperCase()
        : 'G';
    final creditsUsed = isPro ? 2340 : 40;
    final creditsTotal = isPro ? 10000 : 500;
    final storageUsed = isPro ? 23.6 : 0.8;
    final storageTotal = isPro ? 100.0 : 2.0;
    final referralCode = _referralCode(user);
    final memberSince = isGuest ? '—' : 'Jan 2026';
    final lastLogin = isGuest ? '—' : 'Today';
    final shortId = user == null
        ? '—'
        : user.id.length > 12
            ? '${user.id.substring(0, 8)}…'
            : user.id;
    final emailOk = !isGuest && email.contains('@');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: FadeSlideIn(
                child: _HeroHeader(
                  initial: initial,
                  avatarUrl: avatarUrl,
                  isPro: isPro,
                  isOnline: !isGuest,
                  isVerified: !isGuest,
                  displayName: displayName,
                  username: username,
                  email: email,
                  memberSince: memberSince,
                  planLabel: planLabel,
                  onEdit: () => context.push('/profile/edit'),
                  onEditPhoto: () => pickAndUploadAvatar(context, ref),
                  onQr: () => _snack(context, 'Profile QR coming soon'),
                  onShare: () => _shareProfile(context, displayName),
                ),
              ),
            ),

            // Stats
            SliverToBoxAdapter(
              child: FadeSlideIn(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _StatsRow(
                    creditsUsed: creditsUsed,
                    creditsTotal: creditsTotal,
                    storageUsed: storageUsed,
                    storageTotal: storageTotal,
                    planLabel: planLabel,
                    statusLabel: isGuest ? 'Guest' : 'Active',
                  ),
                ),
              ),
            ),

            // Account Information
            SliverToBoxAdapter(
              child: FadeSlideIn(
                index: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _GlassPanel(
                    title: 'Account Information',
                    icon: Icons.person_rounded,
                    accent: _purple,
                    child: Column(
                      children: [
                        _AccountRow(
                          icon: Icons.key_rounded,
                          iconColor: _purple,
                          label: 'User ID',
                          value: shortId,
                          valueColor: _purple,
                          onCopy: user == null
                              ? null
                              : () => _copy(context, user.id, 'User ID copied'),
                        ),
                        _AccountRow(
                          icon: Icons.shield_outlined,
                          iconColor: _blue,
                          label: 'Role',
                          value: isGuest
                              ? 'Guest'
                              : (isPro ? 'Member · Pro' : 'Member'),
                        ),
                        _AccountRow(
                          icon: Icons.workspace_premium_rounded,
                          iconColor: _warning,
                          label: 'Subscription',
                          value: planLabel,
                          valueColor: _success,
                        ),
                        _AccountRow(
                          icon: Icons.bolt_rounded,
                          iconColor: _pink,
                          label: 'Credits',
                          value: '$creditsUsed / $creditsTotal',
                          valueColor: _purple,
                        ),
                        _AccountRow(
                          icon: Icons.cloud_outlined,
                          iconColor: _blue,
                          label: 'Storage Used',
                          value:
                              '${storageUsed.toStringAsFixed(1)} / ${storageTotal.toStringAsFixed(0)} GB',
                          valueColor: _blue,
                        ),
                        _AccountRow(
                          icon: Icons.card_giftcard_rounded,
                          iconColor: _pink,
                          label: 'Referral Code',
                          value: referralCode,
                          onCopy: isGuest
                              ? null
                              : () => _copy(
                                    context,
                                    referralCode,
                                    'Referral code copied',
                                  ),
                        ),
                        _AccountRow(
                          icon: Icons.calendar_month_rounded,
                          iconColor: _blue,
                          label: 'Member Since',
                          value: memberSince,
                        ),
                        _AccountRow(
                          icon: Icons.event_available_rounded,
                          iconColor: _purple,
                          label: 'Joined Date',
                          value: memberSince,
                        ),
                        _AccountRow(
                          icon: Icons.login_rounded,
                          iconColor: _pink,
                          label: 'Last Login',
                          value: lastLogin,
                        ),
                        _AccountRow(
                          icon: Icons.verified_user_outlined,
                          iconColor: _success,
                          label: 'Account Status',
                          value: isGuest ? 'Guest' : 'Active',
                          valueColor: _success,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Security Status
            SliverToBoxAdapter(
              child: FadeSlideIn(
                index: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _GlassPanel(
                    title: 'Security Status',
                    icon: Icons.verified_user_rounded,
                    accent: _success,
                    trailing: TextButton(
                      onPressed: () => context.push('/settings'),
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _purple,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SecurityTile(
                                icon: Icons.mail_outline_rounded,
                                iconColor: _success,
                                title: 'Email Verified',
                                status: emailOk ? 'Verified' : 'Not verified',
                                ok: emailOk,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SecurityTile(
                                icon: Icons.phone_iphone_rounded,
                                iconColor: _orange,
                                title: 'Phone Verified',
                                status: 'Not verified',
                                ok: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SecurityTile(
                                icon: Icons.lock_outline_rounded,
                                iconColor: _purple,
                                title: '2FA Enabled',
                                status: 'Off',
                                ok: false,
                                neutral: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SecurityTile(
                                icon: Icons.password_rounded,
                                iconColor: _blue,
                                title: 'Password Change',
                                status: '—',
                                ok: false,
                                warn: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _GradientButton(
                          label: 'Manage security in Settings',
                          icon: Icons.security_rounded,
                          colors: const [_purple, _blue],
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sign Out
            SliverToBoxAdapter(
              child: FadeSlideIn(
                index: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 130),
                  child: _GradientButton(
                    label: 'Sign Out',
                    icon: Icons.logout_rounded,
                    colors: const [_pink, _orange],
                    height: 60,
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _referralCode(AppUser? user) {
    if (user == null || user.isGuest) return '—';
    final raw = user.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (raw.length < 6) return 'FARV${raw.padRight(4, 'X')}';
    return 'FARV${raw.substring(0, 6)}';
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

  static Future<void> _copy(
    BuildContext context,
    String text,
    String msg,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _snack(context, msg);
  }

  static Future<void> _shareProfile(BuildContext context, String name) async {
    await Clipboard.setData(
      ClipboardData(
        text: 'Check out $name on Farvixo — https://tools.farvixo.com',
      ),
    );
    if (context.mounted) _snack(context, 'Profile link copied');
  }

  static Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final p = AppPalette.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: Blurs.heavy, sigmaY: Blurs.heavy),
          child: Container(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 14, Insets.gutter, 28),
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: 0.92),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
              border: Border.all(color: p.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: Radii.brPill,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Sign out?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can sign back in anytime with the same account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: BorderSide(color: p.border),
                          shape: const RoundedRectangleBorder(
                            borderRadius: Radii.brCard,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GradientButton(
                        label: 'Sign Out',
                        icon: Icons.logout_rounded,
                        colors: const [_pink, _orange],
                        height: 50,
                        onTap: () => Navigator.pop(ctx, true),
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
    if (ok != true || !context.mounted) return;
    await ref.read(authProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatefulWidget {
  const _HeroHeader({
    required this.initial,
    required this.avatarUrl,
    required this.isPro,
    required this.isOnline,
    required this.isVerified,
    required this.displayName,
    required this.username,
    required this.email,
    required this.memberSince,
    required this.planLabel,
    required this.onEdit,
    required this.onEditPhoto,
    required this.onQr,
    required this.onShare,
  });

  final String initial;
  final String? avatarUrl;
  final bool isPro;
  final bool isOnline;
  final bool isVerified;
  final String displayName;
  final String username;
  final String email;
  final String memberSince;
  final String planLabel;
  final VoidCallback onEdit;
  final VoidCallback onEditPhoto;
  final VoidCallback onQr;
  final VoidCallback onShare;

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return Column(
      children: [
        SizedBox(
          height: 280 + top,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) {
                    final t = _c.value * math.pi * 2;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1 + math.sin(t) * 0.3, -1),
                          end: Alignment(1 + math.cos(t) * 0.3, 1),
                          colors: [
                            Color.lerp(
                              ProfileScreen._purple,
                              ProfileScreen._pink,
                              0.15 + math.sin(t) * 0.1,
                            )!,
                            ProfileScreen._blue.withValues(alpha: 0.85),
                            Color.lerp(
                              ProfileScreen._pink,
                              ProfileScreen._purple,
                              0.35,
                            )!,
                          ],
                        ),
                      ),
                      child: CustomPaint(
                        painter: _MeshPainter(t, p.isDark),
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: p.isDark ? 0.15 : 0.05),
                        p.bg.withValues(alpha: 0.15),
                        p.bg.withValues(alpha: 0.92),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: top + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                    ),
                    const Spacer(),
                    _EditPill(onTap: widget.onEdit),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: -8,
                child: Column(
                  children: [
                    _AvatarRing(
                      initial: widget.initial,
                      avatarUrl: widget.avatarUrl,
                      isPro: widget.isPro,
                      isOnline: widget.isOnline,
                      isVerified: widget.isVerified,
                      onEditPhoto: widget.onEditPhoto,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.displayName,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (widget.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 22,
                            color: ProfileScreen._blue,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.username}  ·  ${widget.email}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: p.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.calendar_today_rounded,
                label: 'Member since ${widget.memberSince}',
              ),
              _InfoChip(
                icon: Icons.diamond_rounded,
                label: '${widget.planLabel} Plan',
                accent: ProfileScreen._purple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.qr_code_2_rounded,
                  label: 'My QR',
                  onTap: widget.onQr,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: widget.onShare,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter(this.t, this.isDark);
  final double t;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 18; i++) {
      final px = (math.sin(t + i * 0.7) * 0.35 + 0.5) * size.width;
      final py = (math.cos(t * 0.8 + i) * 0.3 + 0.4) * size.height;
      final r = 1.2 + (i % 4) * 0.7;
      paint.color = Colors.white.withValues(alpha: isDark ? 0.18 : 0.28);
      canvas.drawCircle(Offset(px, py), r, paint);
    }
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.12);
    final path = Path();
    path.moveTo(0, size.height * 0.72);
    for (var x = 0.0; x <= size.width; x += 8) {
      final y = size.height * 0.72 +
          math.sin(x / 40 + t) * 10 +
          math.cos(x / 28 + t * 1.3) * 6;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(_MeshPainter old) => old.t != t || old.isDark != isDark;
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  static const String tooltip = 'Back';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: ClipRRect(
          borderRadius: Radii.brButton,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: Blurs.glass, sigmaY: Blurs.glass),
            child: PressableScale(
              onTap: onTap,
              child: DecoratedBox(
                decoration:
                    BoxDecoration(color: Colors.white.withValues(alpha: 0.14)),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditPill extends StatelessWidget {
  const _EditPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Edit Profile',
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: Radii.brPill,
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: ProfileScreen._purple.withValues(alpha: 0.35),
                blurRadius: 14,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarRing extends StatefulWidget {
  const _AvatarRing({
    required this.initial,
    required this.avatarUrl,
    required this.isPro,
    required this.isOnline,
    required this.isVerified,
    required this.onEditPhoto,
  });

  final String initial;
  final String? avatarUrl;
  final bool isPro;
  final bool isOnline;
  final bool isVerified;
  final VoidCallback onEditPhoto;

  @override
  State<_AvatarRing> createState() => _AvatarRingState();
}

class _AvatarRingState extends State<_AvatarRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _spin,
            builder: (_, child) => Transform.rotate(
              angle: _spin.value * math.pi * 2,
              child: child,
            ),
            child: Container(
              width: 124,
              height: 124,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    ProfileScreen._purple,
                    ProfileScreen._blue,
                    ProfileScreen._pink,
                    ProfileScreen._purple,
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.surface,
              boxShadow: [
                BoxShadow(
                  color: ProfileScreen._purple.withValues(alpha: 0.45),
                  blurRadius: 24,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _avatarBody(p),
          ),
          if (widget.isOnline)
            Positioned(
              right: 14,
              bottom: 16,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: ProfileScreen._success,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.bg, width: 2.5),
                ),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Semantics(
              button: true,
              label: 'Change profile photo',
              child: Tooltip(
                message: 'Change photo',
                child: Material(
                  color: ProfileScreen._purple,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onEditPhoto,
                    child: const Padding(
                      padding: EdgeInsets.all(Insets.sm),
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarBody(AppPalette p) {
    final url = widget.avatarUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http')) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initial(p),
        );
      }
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initial(p),
      );
    }
    return _initial(p);
  }

  Widget _initial(AppPalette p) => Center(
        child: Text(
          widget.initial,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: ProfileScreen._purple,
          ),
        ),
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = accent ?? p.textSecondary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: p.isDark ? 0.55 : 0.75),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (accent ?? p.border).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent ?? p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: Radii.brPanel,
            color: p.surface.withValues(alpha: p.isDark ? 0.55 : 0.85),
            border: Border.all(color: p.border),
            boxShadow: [
              BoxShadow(
                color: ProfileScreen._purple.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ProfileScreen._purple, size: 20),
              const SizedBox(width: Insets.sm),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.creditsUsed,
    required this.creditsTotal,
    required this.storageUsed,
    required this.storageTotal,
    required this.planLabel,
    required this.statusLabel,
  });

  final int creditsUsed;
  final int creditsTotal;
  final double storageUsed;
  final double storageTotal;
  final String planLabel;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StatCard(
            icon: Icons.bolt_rounded,
            iconColor: ProfileScreen._purple,
            title: 'Credits',
            value: '$creditsUsed / $creditsTotal',
            progress: creditsUsed / creditsTotal,
            progressColor: ProfileScreen._purple,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.cloud_rounded,
            iconColor: ProfileScreen._blue,
            title: 'Storage Used',
            value:
                '${storageUsed.toStringAsFixed(1)} / ${storageTotal.toStringAsFixed(0)} GB',
            progress: storageUsed / storageTotal,
            progressColor: ProfileScreen._blue,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.workspace_premium_rounded,
            iconColor: ProfileScreen._warning,
            title: 'Subscription',
            value: planLabel,
            subtitle: 'Current Plan',
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.verified_user_rounded,
            iconColor: ProfileScreen._success,
            title: 'Status',
            value: statusLabel,
            subtitle: 'Account Type',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.progress,
    this.progressColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;
  final double? progress;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: 148,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            iconColor.withValues(alpha: p.isDark ? 0.22 : 0.12),
            p.surface.withValues(alpha: p.isDark ? 0.7 : 0.95),
          ],
        ),
        border: Border.all(color: iconColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: p.textPrimary,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: p.textMuted),
            ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: p.border.withValues(alpha: 0.5),
                color: progressColor ?? iconColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass panels / rows
// ─────────────────────────────────────────────────────────────────────────────

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: p.isDark ? 0.16 : 0.08),
                p.surface.withValues(alpha: p.isDark ? 0.72 : 0.92),
                Color.lerp(accent, ProfileScreen._blue, 0.4)!
                    .withValues(alpha: p.isDark ? 0.10 : 0.05),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          Color.lerp(accent, ProfileScreen._pink, 0.4)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.onCopy,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onCopy;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.textMuted,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? p.textPrimary,
                  ),
                ),
              ),
              if (onCopy != null) ...[
                const SizedBox(width: Insets.sm),
                Tooltip(
                  message: 'Copy $label',
                  child: Material(
                    color: ProfileScreen._purple.withValues(alpha: 0.12),
                    borderRadius: Radii.brSm,
                    child: InkWell(
                      onTap: onCopy,
                      borderRadius: Radii.brSm,
                      child: Semantics(
                        button: true,
                        label: 'Copy $label',
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: ProfileScreen._purple,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: p.border.withValues(alpha: 0.65)),
      ],
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.status,
    required this.ok,
    this.neutral = false,
    this.warn = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String status;
  final bool ok;
  final bool neutral;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final statusColor = ok
        ? ProfileScreen._success
        : warn
            ? ProfileScreen._warning
            : neutral
                ? p.textMuted
                : ProfileScreen._danger;
    final statusIcon = ok
        ? Icons.check_circle_rounded
        : warn
            ? Icons.remove_circle_outline_rounded
            : neutral
                ? Icons.remove_rounded
                : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: p.surface.withValues(alpha: p.isDark ? 0.45 : 0.7),
        border: Border.all(color: iconColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const Spacer(),
              Icon(statusIcon, size: 18, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.height = 52,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(colors: colors),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: Insets.sm),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
