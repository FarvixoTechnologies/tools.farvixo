import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_kit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class SettingsV5Header extends StatelessWidget {
  const SettingsV5Header({
    super.key,
    required this.onBack,
    required this.onSearch,
    required this.onThemeToggle,
    required this.themeMode,
    this.wave,
  });

  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onThemeToggle;
  final ThemeMode themeMode;
  final Animation<double>? wave;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      height: 88,
      child: Stack(
        children: [
          if (wave != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: wave!,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _HeaderWavePainter(wave!.value, p.isDark),
                    );
                  },
                ),
              ),
            ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: p.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Settings',
                            style: AppTypography.headlineSmall(context, color: p.textPrimary, weight: FontWeights.extrabold).copyWith(letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage your account & app preferences',
                            style: AppTypography.labelMedium(context, color: p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _HeaderIconButton(
                      icon: Icons.search_rounded,
                      onTap: onSearch,
                    ),
                    const SizedBox(width: 6),
                    _HeaderIconButton(
                      icon: switch (themeMode) {
                        ThemeMode.dark => Icons.dark_mode_rounded,
                        ThemeMode.light => Icons.light_mode_rounded,
                        ThemeMode.system => Icons.brightness_auto_rounded,
                      },
                      onTap: onThemeToggle,
                      accent: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderWavePainter extends CustomPainter {
  _HeaderWavePainter(this.t, this.isDark);
  final double t;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.7);
    for (var x = 0.0; x <= size.width; x += 8) {
      final y =
          size.height * 0.55 +
          10 * math.sin((x / size.width * 4 + t * math.pi * 2));
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.brandPrimary.withValues(alpha: isDark ? 0.18 : 0.10),
          AppColors.brandMagenta.withValues(alpha: isDark ? 0.10 : 0.06),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeaderWavePainter oldDelegate) =>
      oldDelegate.t != t;
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.brButton,
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: Radii.brButton,
            color: accent
                ? AppColors.brandPrimary.withValues(alpha: 0.18)
                : p.surface2.withValues(alpha: 0.7),
            border: Border.all(
              color: accent
                  ? AppColors.brandPrimary.withValues(alpha: 0.35)
                  : p.border,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: accent ? AppColors.brandPrimaryHover : p.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Hero
// ─────────────────────────────────────────────────────────────────────────────

class SettingsProfileHero extends StatelessWidget {
  const SettingsProfileHero({
    super.key,
    required this.name,
    required this.username,
    required this.email,
    required this.initial,
    this.avatarUrl,
    required this.isPro,
    required this.isGuest,
    required this.pulse,
    required this.onCamera,
    required this.onEdit,
    required this.onCopyEmail,
    required this.creditsUsed,
    required this.creditsMax,
    required this.storageUsedGb,
    required this.storageMaxGb,
  });

  final String name;
  final String username;
  final String email;
  final String initial;
  final String? avatarUrl;
  final bool isPro;
  final bool isGuest;
  final Animation<double> pulse;
  final VoidCallback onCamera;
  final VoidCallback onEdit;
  final VoidCallback onCopyEmail;
  final int creditsUsed;
  final int creditsMax;
  final double storageUsedGb;
  final double storageMaxGb;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ClipRRect(
      borderRadius: Radii.brBanner,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            final glow = 0.35 + pulse.value * 0.25;
            return Container(
              constraints: const BoxConstraints(minHeight: 168),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: Radii.brBanner,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.brandPrimary.withValues(alpha: 0.22),
                    AppColors.brandMagenta.withValues(alpha: 0.14),
                    AppColors.accentDev.withValues(alpha: 0.12),
                    p.surface.withValues(alpha: p.isDark ? 0.72 : 0.88),
                  ],
                ),
                border: Border.all(
                  color: Color.lerp(
                    AppColors.brandPrimary.withValues(alpha: 0.25),
                    AppColors.brandMagenta.withValues(alpha: 0.55),
                    glow - 0.35,
                  )!,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(
                      alpha: 0.18 * glow,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.brandPrimary,
                              AppColors.brandMagenta,
                              AppColors.accentDev,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandPrimary.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          backgroundColor: p.surface2,
                          backgroundImage:
                              avatarUrl != null &&
                                  avatarUrl!.isNotEmpty &&
                                  (avatarUrl!.startsWith('http') ||
                                      avatarUrl!.startsWith('https'))
                              ? NetworkImage(avatarUrl!)
                              : null,
                          child: avatarUrl == null || avatarUrl!.isEmpty
                              ? Text(
                                  initial,
                                  style: AppTypography.metric(context, color: p.textPrimary, weight: FontWeights.extrabold),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onCamera,
                            borderRadius: Radii.brPill,
                            child: Ink(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.surface,
                                border: Border.all(color: p.border),
                              ),
                              child: Icon(
                                Icons.photo_camera_rounded,
                                size: 14,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.surface, width: 2),
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
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: AppColors.accentDev,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          username,
                          style: AppTypography.bodyMedium(context, color: p.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: onCopyEmail,
                          child: Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMedium(context, color: p.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: Radii.brPill,
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(
                    'Edit Profile',
                    style: AppTypography.bodyLarge(context, weight: FontWeights.bold),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SettingsAccountStats(
                isPro: isPro,
                creditsUsed: creditsUsed,
                creditsMax: creditsMax,
                storageUsedGb: storageUsedGb,
                storageMaxGb: storageMaxGb,
                embedded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account stats
// ─────────────────────────────────────────────────────────────────────────────

class SettingsAccountStats extends StatelessWidget {
  const SettingsAccountStats({
    super.key,
    required this.isPro,
    required this.creditsUsed,
    required this.creditsMax,
    required this.storageUsedGb,
    required this.storageMaxGb,
    this.embedded = false,
  });

  final bool isPro;
  final int creditsUsed;
  final int creditsMax;
  final double storageUsedGb;
  final double storageMaxGb;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.brandPrimaryHover,
            label: 'Credits',
            value: '$creditsUsed',
            progress: creditsUsed / creditsMax,
            embedded: embedded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.cloud_outlined,
            color: AppColors.accentDev,
            label: 'Storage',
            value: '${storageUsedGb.toStringAsFixed(0)} GB',
            progress: storageUsedGb / storageMaxGb,
            embedded: embedded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.workspace_premium_rounded,
            color: AppColors.goldPremium,
            label: 'Plan',
            value: isPro ? 'Pro' : 'Free',
            embedded: embedded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.verified_user_outlined,
            color: AppColors.success,
            label: 'Status',
            value: 'Active',
            embedded: embedded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.progress,
    this.embedded = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final double? progress;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        if (progress != null)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress!.clamp(0.0, 1.0)),
            duration: Motion.verySlow,
            curve: Motion.easeOut,
            builder: (context, v, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(context, color: p.textPrimary, weight: FontWeights.extrabold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: AppTypography.caption(context, color: p.textMuted),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: Radii.brPill,
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 4,
                      backgroundColor: p.surface2,
                      color: color,
                    ),
                  ),
                ],
              );
            },
          )
        else ...[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium(context, color: p.textPrimary, weight: FontWeights.extrabold),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption(context, color: p.textMuted)),
        ],
      ],
    );

    if (embedded) {
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: p.surface2.withValues(alpha: p.isDark ? 0.55 : 0.7),
          borderRadius: Radii.brPanel,
          border: Border.all(color: p.border.withValues(alpha: 0.7)),
        ),
        child: content,
      );
    }

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick actions
// ─────────────────────────────────────────────────────────────────────────────

class SettingsQuickActions extends StatefulWidget {
  const SettingsQuickActions({super.key, required this.onTap});

  final void Function(String id, String label) onTap;

  @override
  State<SettingsQuickActions> createState() => _SettingsQuickActionsState();
}

class _SettingsQuickActionsState extends State<SettingsQuickActions> {
  final _scroll = ScrollController();
  int _page = 0;

  static const _items = <(String, String, IconData, Color)>[
    ('qr', 'My QR', Icons.qr_code_2_rounded, AppColors.brandPrimaryHover),
    ('share', 'Share Profile', Icons.ios_share_rounded, AppColors.accentDev),
    (
      'invite',
      'Invite Friends',
      Icons.person_add_alt_1_rounded,
      AppColors.accentImage,
    ),
    (
      'achievements',
      'Achievements',
      Icons.emoji_events_rounded,
      AppColors.goldPremium,
    ),
    ('activity', 'Activity', Icons.timeline_rounded, AppColors.accentAi),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final next = (_scroll.offset / 100).round().clamp(0, 2);
      if (next != _page) setState(() => _page = next);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final (id, label, icon, color) = _items[i];
              return PressableScale(
                onTap: () => widget.onTap(id, label),
                child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      borderRadius: Radii.brBanner,
                      color: p.surface.withValues(alpha: p.isDark ? 0.65 : 0.9),
                      border: Border.all(color: p.border),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlowIcon(
                          icon: icon,
                          color: color,
                          size: 40,
                          iconSize: 20,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(context, color: p.textPrimary, weight: FontWeights.bold).copyWith(height: 1.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (i) => AnimatedContainer(
              duration: Motion.base,
              width: i == _page ? 14 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: Radii.brPill,
                color: i == _page
                    ? AppColors.brandPrimaryHover
                    : p.textMuted.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.titleSmall(context, color: p.textPrimary, weight: FontWeights.extrabold),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandPrimaryHover,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '$actionLabel →',
              style: AppTypography.bodySmall(context, weight: FontWeights.bold),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preferences grid
// ─────────────────────────────────────────────────────────────────────────────

class SettingsPreferencesGrid extends StatelessWidget {
  const SettingsPreferencesGrid({
    super.key,
    required this.themeLabel,
    required this.languageLabel,
    required this.animationsOn,
    required this.hapticsOn,
    required this.onOpen,
    required this.onToggleAnimations,
    required this.onToggleHaptics,
  });

  final String themeLabel;
  final String languageLabel;
  final bool animationsOn;
  final bool hapticsOn;
  final void Function(String sectionId) onOpen;
  final ValueChanged<bool> onToggleAnimations;
  final ValueChanged<bool> onToggleHaptics;

  @override
  Widget build(BuildContext context) {
    final cards = <_PrefCardData>[
      _PrefCardData(
        '🎨',
        'Appearance',
        'Theme, colors',
        AppColors.brandMagenta,
        () => onOpen('appearance'),
        trailing: themeLabel,
      ),
      _PrefCardData(
        '🌐',
        'Language',
        languageLabel,
        AppColors.accentDev,
        () => onOpen('language'),
      ),
      _PrefCardData(
        '🔤',
        'Font & Display',
        'Size & density',
        AppColors.accentText,
        () => onOpen('accessibility'),
      ),
      _PrefCardData(
        '✨',
        'Animations',
        animationsOn ? 'On' : 'Off',
        AppColors.goldPremium,
        () => onToggleAnimations(!animationsOn),
      ),
      _PrefCardData(
        '📳',
        'Haptic Feedback',
        hapticsOn ? 'On' : 'Off',
        AppColors.accentImage,
        () => onToggleHaptics(!hapticsOn),
      ),
      _PrefCardData(
        '🔔',
        'Notifications',
        'Push & email',
        AppColors.accentAi,
        () => onOpen('notifications'),
      ),
      _PrefCardData(
        '⚙',
        'More Settings',
        'All sections',
        AppColors.brandPrimaryHover,
        () => onOpen('account'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 88,
      ),
      itemBuilder: (context, i) {
        final c = cards[i];
        final p = AppPalette.of(context);
        return PressableScale(
          onTap: c.onTap,
          child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: Radii.brBanner,
                color: p.surface.withValues(alpha: p.isDark ? 0.7 : 0.92),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: Radii.brButton,
                      color: c.color.withValues(alpha: 0.16),
                    ),
                    child: Text(c.emoji, style: AppTypography.titleLarge(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium(context, color: p.textPrimary, weight: FontWeights.extrabold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall(context, color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: p.textMuted,
                  ),
                ],
              ),
            ),
        );
      },
    );
  }
}

class _PrefCardData {
  const _PrefCardData(
    this.emoji,
    this.title,
    this.subtitle,
    this.color,
    this.onTap, {
    this.trailing,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? trailing;
}

// ─────────────────────────────────────────────────────────────────────────────
// Account & Security split
// ─────────────────────────────────────────────────────────────────────────────

class SettingsAccountSecuritySplit extends StatelessWidget {
  const SettingsAccountSecuritySplit({
    super.key,
    required this.securityScore,
    required this.shine,
    required this.onAccountInfo,
    required this.onSecurity,
    required this.onConnected,
    required this.onImprove,
    required this.onDevices,
    this.emailVerified = true,
    this.phoneVerified = false,
    this.twoFactorEnabled = false,
    this.passkeyEnabled = false,
    this.deviceCount = 1,
  });

  final int securityScore;
  final Animation<double> shine;
  final VoidCallback onAccountInfo;
  final VoidCallback onSecurity;
  final VoidCallback onConnected;
  final VoidCallback onImprove;
  final VoidCallback onDevices;
  final bool emailVerified;
  final bool phoneVerified;
  final bool twoFactorEnabled;
  final bool passkeyEnabled;
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GlassCard(
      radius: Radii.banner,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 11,
                  child: Column(
                    children: [
                      _SecRow(
                        icon: Icons.badge_outlined,
                        color: AppColors.brandPrimaryHover,
                        title: 'Account Information',
                        onTap: onAccountInfo,
                      ),
                      Divider(height: 1, color: p.border),
                      _SecRow(
                        icon: Icons.shield_outlined,
                        color: AppColors.success,
                        title: 'Security Settings',
                        onTap: onSecurity,
                      ),
                      Divider(height: 1, color: p.border),
                      _SecRow(
                        icon: Icons.link_rounded,
                        color: AppColors.accentDev,
                        title: 'Connected Accounts',
                        onTap: onConnected,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 9,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: Radii.brPanel,
                      color: p.surface2.withValues(alpha: 0.65),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 86,
                          height: 86,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: securityScore / 100,
                                ),
                                duration: Motion.shimmer,
                                curve: Motion.easeOut,
                                builder: (context, value, _) {
                                  return AnimatedBuilder(
                                    animation: shine,
                                    builder: (context, _) {
                                      return Transform.rotate(
                                        angle: shine.value * math.pi * 2,
                                        child: CircularProgressIndicator(
                                          value: value,
                                          strokeWidth: 7,
                                          backgroundColor: p.border,
                                          color: AppColors.success,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$securityScore',
                                    style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.black),
                                  ),
                                  Text(
                                    '/ 100',
                                    style: AppTypography.caption(context, color: p.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your account is secure',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall(context, color: p.textSecondary, weight: FontWeights.semibold),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: Radii.brPill,
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.brandPrimary,
                                  AppColors.brandMagenta,
                                ],
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onImprove,
                                borderRadius: Radii.brPill,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 9),
                                  child: Text(
                                    'Improve Security',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.labelSmall(context, color: AppColors.onAccent, weight: FontWeights.extrabold),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: p.border),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Verification',
              style: AppTypography.labelSmall(context, color: p.textMuted, weight: FontWeights.extrabold),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _VerifyChip(label: 'Email', ok: emailVerified, onTap: onImprove),
              _VerifyChip(label: 'Phone', ok: phoneVerified, onTap: onImprove),
              _VerifyChip(label: '2FA', ok: twoFactorEnabled, onTap: onImprove),
              _VerifyChip(
                label: 'Passkey',
                ok: passkeyEnabled,
                onTap: onImprove,
              ),
              InkWell(
                onTap: onDevices,
                borderRadius: Radii.brPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: Radii.brPill,
                    color: AppColors.accentAi.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppColors.accentAi.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '$deviceCount Devices',
                    style: AppTypography.labelSmall(context, color: AppColors.accentAi, weight: FontWeights.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerifyChip extends StatelessWidget {
  const _VerifyChip({
    required this.label,
    required this.ok,
    required this.onTap,
  });

  final String label;
  final bool ok;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.brPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: Radii.brPill,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall(context, color: color, weight: FontWeights.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecRow extends StatelessWidget {
  const _SecRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.brButton,
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, 10, 4, isLast ? 4 : 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                style: AppTypography.labelMedium(context, color: p.textPrimary, weight: FontWeights.bold),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu list
// ─────────────────────────────────────────────────────────────────────────────

class SettingsMenuList extends StatelessWidget {
  const SettingsMenuList({super.key, required this.items, required this.onTap});

  final List<(IconData, Color, String, String, String)> items;
  final void Function(String sectionId) onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GlassCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            PressableScale(
              onTap: () => onTap(items[i].$5),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    GlowIcon(
                      icon: items[i].$1,
                      color: items[i].$2,
                      size: 42,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].$3,
                            style: AppTypography.titleSmall(context, color: p.textPrimary, weight: FontWeights.extrabold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].$4,
                            style: AppTypography.labelSmall(context, color: p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: p.textMuted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            if (i != items.length - 1)
              Divider(height: 1, indent: 68, color: p.border),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sign out + danger
// ─────────────────────────────────────────────────────────────────────────────

class SettingsGradientSignOut extends StatelessWidget {
  const SettingsGradientSignOut({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.brBanner,
        gradient: const LinearGradient(
          colors: [AppColors.destructive, AppColors.accentAudio],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.destructive.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.brBanner,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: AppColors.onAccent),
                SizedBox(width: 10),
                Text(
                  'Sign Out',
                  style: AppTypography.titleMedium(context, color: AppColors.onAccent, weight: FontWeights.extrabold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsDangerZoneCard extends StatelessWidget {
  const SettingsDangerZoneCard({
    super.key,
    required this.onSignOut,
    required this.onReset,
    required this.onDelete,
  });

  final VoidCallback onSignOut;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: Radii.brBanner,
        color: AppColors.destructive.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danger Zone',
            style: AppTypography.bodyMedium(context, color: p.textPrimary, weight: FontWeights.extrabold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: const BorderSide(color: AppColors.destructive),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: const BorderSide(color: AppColors.destructive),
                  ),
                  child: const Text('Reset App'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: const BorderSide(color: AppColors.destructive),
                  ),
                  child: const Text('Delete Account'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
