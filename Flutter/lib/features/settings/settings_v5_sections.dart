import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_kit.dart';

/// Shared glass section shell used by hub inline cards.
class SettingsHubSection extends StatelessWidget {
  const SettingsHubSection({
    super.key,
    required this.title,
    this.actionLabel = 'View All',
    this.onAction,
    required this.child,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
              ),
              if (onAction != null)
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 12, isLast ? 12 : 12),
        child: Row(
          children: [
            GlowIcon(icon: icon, color: color, size: 40, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11, color: p.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data & Storage
// ─────────────────────────────────────────────────────────────────────────────

class SettingsDataStorageCard extends StatelessWidget {
  const SettingsDataStorageCard({
    super.key,
    required this.usedGb,
    required this.maxGb,
    required this.onOpen,
    required this.onItem,
  });

  final double usedGb;
  final double maxGb;
  final VoidCallback onOpen;
  final void Function(String id) onItem;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final ratio = (usedGb / maxGb).clamp(0.0, 1.0);
    final items = <(IconData, Color, String, String, String)>[
      (Icons.cloud_outlined, AppColors.accentText, 'Cloud Storage',
          '${usedGb.toStringAsFixed(0)} / ${maxGb.toStringAsFixed(0)} GB', 'cloud'),
      (Icons.download_rounded, AppColors.accentDev, 'Downloads', 'Manage files',
          'downloads'),
      (Icons.cleaning_services_outlined, AppColors.accentAudio, 'Cache',
          'Clear temporary data', 'cache'),
      (Icons.offline_bolt_outlined, AppColors.accentImage, 'Offline Files',
          'Available offline', 'offline'),
      (Icons.backup_outlined, AppColors.brandPrimaryHover, 'Backup',
          'Cloud backup', 'backup'),
      (Icons.sync_rounded, AppColors.accentAi, 'Sync', 'Auto sync on', 'sync'),
      (Icons.upload_rounded, AppColors.goldPremium, 'Auto Upload', 'Wi-Fi only',
          'auto_upload'),
      (Icons.analytics_outlined, AppColors.brandMagenta, 'Storage Analyzer',
          'See what’s using space', 'analyzer'),
    ];

    return SettingsHubSection(
      title: 'Data & Storage',
      onAction: onOpen,
      child: GlassCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return CustomPaint(
                          painter: _StorageRingPainter(
                            progress: value,
                            track: p.border,
                            color: AppColors.brandPrimaryHover,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(value * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: p.textPrimary,
                                  ),
                                ),
                                Text(
                                  'used',
                                  style: TextStyle(
                                      fontSize: 10, color: p.textMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storage overview',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${usedGb.toStringAsFixed(1)} GB of ${maxGb.toStringAsFixed(0)} GB used',
                          style:
                              TextStyle(fontSize: 12, color: p.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _LegendDot(
                                color: AppColors.brandPrimaryHover,
                                label: 'Cloud'),
                            _LegendDot(
                                color: AppColors.accentDev, label: 'Local'),
                            _LegendDot(
                                color: AppColors.accentAudio, label: 'Cache'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),
            for (var i = 0; i < items.length; i++) ...[
              _HubRow(
                icon: items[i].$1,
                color: items[i].$2,
                title: items[i].$3,
                subtitle: items[i].$4,
                onTap: () => onItem(items[i].$5),
                isLast: i == items.length - 1,
              ),
              if (i != items.length - 1)
                Divider(height: 1, indent: 66, color: p.border),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: p.textMuted)),
      ],
    );
  }
}

class _StorageRingPainter extends CustomPainter {
  _StorageRingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = SweepGradient(
        colors: [color, AppColors.brandMagenta, color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StorageRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Subscription
// ─────────────────────────────────────────────────────────────────────────────

class SettingsSubscriptionCard extends StatelessWidget {
  const SettingsSubscriptionCard({
    super.key,
    required this.isPro,
    required this.creditsLeft,
    required this.creditsMax,
    required this.shine,
    required this.onUpgrade,
    required this.onOpen,
  });

  final bool isPro;
  final int creditsLeft;
  final int creditsMax;
  final Animation<double> shine;
  final VoidCallback onUpgrade;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final benefits = isPro
        ? const ['Unlimited tools', '100 GB cloud', 'Priority AI', 'No ads']
        : const [
            '5 jobs/day per tool',
            '500 MB cloud',
            '10 AI messages/day',
            'Upgrade for more'
          ];

    return SettingsHubSection(
      title: 'Subscription',
      onAction: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.goldPremium.withValues(alpha: 0.16),
                  AppColors.brandPrimary.withValues(alpha: 0.12),
                  p.surface.withValues(alpha: p.isDark ? 0.75 : 0.92),
                ],
              ),
              border: Border.all(
                color: AppColors.goldPremium.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: Radii.brButton,
                        gradient: const LinearGradient(
                          colors: [AppColors.goldPremium, Color(0xFFF97316)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goldPremium.withValues(alpha: 0.4),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.workspace_premium_rounded,
                          color: Colors.black87, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Plan',
                            style:
                                TextStyle(fontSize: 11, color: p.textMuted),
                          ),
                          Text(
                            isPro ? 'Farvixo Pro' : 'Free',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: p.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Credits left',
                            style:
                                TextStyle(fontSize: 10, color: p.textMuted)),
                        Text(
                          '$creditsLeft / $creditsMax',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isPro ? 'Renews · Auto' : 'Renew date · —',
                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in benefits)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: Radii.brPill,
                          color: p.surface2.withValues(alpha: 0.7),
                          border: Border.all(color: p.border),
                        ),
                        child: Text(
                          b,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!isPro) ...[
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: shine,
                    builder: (context, child) {
                      return ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (bounds) {
                          final x = shine.value * 2 - 0.5;
                          return LinearGradient(
                            begin: Alignment(-1 + x, 0),
                            end: Alignment(x, 0),
                            colors: const [
                              Colors.transparent,
                              Colors.white54,
                              Colors.transparent,
                            ],
                          ).createShader(bounds);
                        },
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: Radii.brCard,
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.goldPremium,
                              Color(0xFFF97316),
                              AppColors.brandMagenta,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.goldPremium.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onUpgrade,
                            borderRadius: Radii.brCard,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.workspace_premium_rounded,
                                    color: Colors.black87, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Upgrade to Pro',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Settings
// ─────────────────────────────────────────────────────────────────────────────

class SettingsAiCard extends StatelessWidget {
  const SettingsAiCard({
    super.key,
    required this.onOpen,
    required this.onItem,
    required this.aiEnabled,
    required this.onToggleAi,
  });

  final VoidCallback onOpen;
  final void Function(String id) onItem;
  final bool aiEnabled;
  final ValueChanged<bool> onToggleAi;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final rows = <(IconData, Color, String, String, String)>[
      (Icons.face_retouching_natural, AppColors.accentAi, 'AI Personality',
          'Helpful & concise', 'personality'),
      (Icons.memory_rounded, AppColors.brandPrimaryHover, 'Default Model',
          'Gemini Flash', 'model'),
      (Icons.style_outlined, AppColors.brandMagenta, 'Response Style',
          'Balanced', 'style'),
      (Icons.record_voice_over_outlined, AppColors.accentAudio, 'Voice',
          'System default', 'voice'),
      (Icons.psychology_outlined, AppColors.accentDev, 'Memory', 'On-device',
          'memory'),
      (Icons.straighten_rounded, AppColors.goldPremium, 'Context Length',
          '8K tokens', 'context'),
      (Icons.stream_rounded, AppColors.accentImage, 'Streaming', 'Enabled',
          'streaming'),
      (Icons.lightbulb_outline_rounded, AppColors.accentText,
          'Smart Suggestions', 'On', 'suggestions'),
      (Icons.privacy_tip_outlined, AppColors.success, 'AI Privacy',
          'No training on chats', 'privacy'),
      (Icons.palette_outlined, AppColors.brandPrimary, 'AI Theme',
          'Neon glass', 'theme'),
    ];

    return SettingsHubSection(
      title: 'AI Settings',
      onAction: onOpen,
      child: GlassCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _HubRow(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.accentAi,
              title: 'AI Assistant',
              subtitle: aiEnabled ? 'Enabled' : 'Disabled',
              trailing: Switch.adaptive(
                value: aiEnabled,
                onChanged: onToggleAi,
                activeThumbColor: AppColors.brandPrimaryHover,
              ),
              isLast: false,
            ),
            Divider(height: 1, indent: 66, color: p.border),
            for (var i = 0; i < rows.length; i++) ...[
              _HubRow(
                icon: rows[i].$1,
                color: rows[i].$2,
                title: rows[i].$3,
                subtitle: rows[i].$4,
                onTap: () => onItem(rows[i].$5),
                isLast: i == rows.length - 1,
              ),
              if (i != rows.length - 1)
                Divider(height: 1, indent: 66, color: p.border),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications
// ─────────────────────────────────────────────────────────────────────────────

class SettingsNotificationsCard extends StatelessWidget {
  const SettingsNotificationsCard({
    super.key,
    required this.onOpen,
    required this.push,
    required this.email,
    required this.sound,
    required this.haptics,
    required this.onToggle,
    required this.onItem,
  });

  final VoidCallback onOpen;
  final bool push;
  final bool email;
  final bool sound;
  final bool haptics;
  final void Function(String key, bool value) onToggle;
  final void Function(String id) onItem;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsHubSection(
      title: 'Notifications',
      onAction: onOpen,
      child: GlassCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _HubRow(
              icon: Icons.notifications_active_outlined,
              color: AppColors.accentAudio,
              title: 'Push',
              subtitle: 'Job & security alerts',
              trailing: Switch.adaptive(
                value: push,
                onChanged: (v) => onToggle('push', v),
              ),
            ),
            Divider(height: 1, indent: 66, color: p.border),
            _HubRow(
              icon: Icons.email_outlined,
              color: AppColors.accentDev,
              title: 'Email',
              subtitle: 'Receipts & updates',
              trailing: Switch.adaptive(
                value: email,
                onChanged: (v) => onToggle('email', v),
              ),
            ),
            Divider(height: 1, indent: 66, color: p.border),
            _HubRow(
              icon: Icons.sms_outlined,
              color: AppColors.accentImage,
              title: 'SMS',
              subtitle: 'Critical alerts only',
              onTap: () => onItem('sms'),
            ),
            Divider(height: 1, indent: 66, color: p.border),
            _HubRow(
              icon: Icons.volume_up_outlined,
              color: AppColors.goldPremium,
              title: 'Sound',
              trailing: Switch.adaptive(
                value: sound,
                onChanged: (v) => onToggle('sound', v),
              ),
            ),
            Divider(height: 1, indent: 66, color: p.border),
            _HubRow(
              icon: Icons.vibration_rounded,
              color: AppColors.brandMagenta,
              title: 'Vibration',
              trailing: Switch.adaptive(
                value: haptics,
                onChanged: (v) => onToggle('haptics', v),
              ),
            ),
            Divider(height: 1, indent: 66, color: p.border),
            _HubRow(
              icon: Icons.bedtime_outlined,
              color: AppColors.accentAi,
              title: 'Quiet Hours',
              subtitle: '22:00 – 07:00',
              onTap: () => onItem('quiet'),
            ),
            Divider(height: 1, indent: 66, color: p.border),
            _HubRow(
              icon: Icons.category_outlined,
              color: AppColors.brandPrimaryHover,
              title: 'Notification Categories',
              subtitle: 'Tools, AI, billing',
              onTap: () => onItem('categories'),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Privacy
// ─────────────────────────────────────────────────────────────────────────────

class SettingsPrivacyCard extends StatelessWidget {
  const SettingsPrivacyCard({
    super.key,
    required this.onOpen,
    required this.onItem,
  });

  final VoidCallback onOpen;
  final void Function(String id) onItem;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final rows = <(IconData, Color, String, String, String)>[
      (Icons.block_rounded, AppColors.error, 'Blocked Users', 'Manage list',
          'blocked'),
      (Icons.visibility_off_outlined, AppColors.accentText, 'Hidden Profile',
          'Appear offline', 'hidden'),
      (Icons.download_outlined, AppColors.accentDev, 'Download Data',
          'Export your data', 'export'),
      (Icons.delete_sweep_outlined, AppColors.accentAudio, 'Delete History',
          'Clear activity', 'delete_history'),
      (Icons.location_on_outlined, AppColors.accentImage, 'Location',
          'Permission', 'location'),
      (Icons.mic_none_rounded, AppColors.brandMagenta, 'Microphone',
          'Permission', 'mic'),
      (Icons.photo_camera_outlined, AppColors.brandPrimaryHover, 'Camera',
          'Permission', 'camera'),
      (Icons.folder_outlined, AppColors.goldPremium, 'Storage', 'Permission',
          'storage_perm'),
    ];

    return SettingsHubSection(
      title: 'Privacy',
      onAction: onOpen,
      child: GlassCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _HubRow(
                icon: rows[i].$1,
                color: rows[i].$2,
                title: rows[i].$3,
                subtitle: rows[i].$4,
                onTap: () => onItem(rows[i].$5),
                isLast: i == rows.length - 1,
              ),
              if (i != rows.length - 1)
                Divider(height: 1, indent: 66, color: p.border),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connected Accounts
// ─────────────────────────────────────────────────────────────────────────────

class SettingsConnectedAccountsCard extends StatelessWidget {
  const SettingsConnectedAccountsCard({
    super.key,
    required this.onOpen,
    required this.onProvider,
  });

  final VoidCallback onOpen;
  final void Function(String id, bool connected) onProvider;

  static const _providers = <(String, String, IconData, Color, bool)>[
    ('google', 'Google', Icons.g_mobiledata_rounded, Color(0xFFEA4335), true),
    ('github', 'GitHub', Icons.code_rounded, Color(0xFF8B5CF6), false),
    ('apple', 'Apple', Icons.apple, Color(0xFFA0A0B8), false),
    ('microsoft', 'Microsoft', Icons.window_rounded, Color(0xFF3B82F6), false),
    ('discord', 'Discord', Icons.forum_outlined, Color(0xFF5865F2), false),
    ('linkedin', 'LinkedIn', Icons.work_outline_rounded, Color(0xFF0A66C2),
        false),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsHubSection(
      title: 'Connected Accounts',
      onAction: onOpen,
      child: GlassCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < _providers.length; i++) ...[
              _HubRow(
                icon: _providers[i].$3,
                color: _providers[i].$4,
                title: _providers[i].$2,
                subtitle: _providers[i].$5 ? 'Connected' : 'Not connected',
                trailing: TextButton(
                  onPressed: () =>
                      onProvider(_providers[i].$1, _providers[i].$5),
                  child: Text(
                    _providers[i].$5 ? 'Disconnect' : 'Connect',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _providers[i].$5
                          ? AppColors.error
                          : AppColors.brandPrimaryHover,
                    ),
                  ),
                ),
                onTap: () => onProvider(_providers[i].$1, _providers[i].$5),
                isLast: i == _providers.length - 1,
              ),
              if (i != _providers.length - 1)
                Divider(height: 1, indent: 66, color: p.border),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity
// ─────────────────────────────────────────────────────────────────────────────

class SettingsActivityCard extends StatelessWidget {
  const SettingsActivityCard({
    super.key,
    required this.onOpen,
    required this.onItem,
  });

  final VoidCallback onOpen;
  final void Function(String id) onItem;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final timeline = const [
      ('Today · 14:22', 'Signed in · Chrome'),
      ('Yesterday', 'Downloaded Image Compressor result'),
      ('2 days ago', 'AI Chat · 12 messages'),
      ('This week', 'Searched “PDF to Word”'),
    ];
    final rows = <(IconData, Color, String, String, String)>[
      (Icons.login_rounded, AppColors.success, 'Login History',
          'Recent sign-ins', 'logins'),
      (Icons.devices_rounded, AppColors.accentDev, 'Recent Devices',
          '2 active devices', 'devices'),
      (Icons.download_rounded, AppColors.accentText, 'Downloads',
          'View files', 'downloads'),
      (Icons.auto_awesome_rounded, AppColors.accentAi, 'AI History',
          'Past chats', 'ai_history'),
      (Icons.search_rounded, AppColors.brandMagenta, 'Search History',
          'Clear anytime', 'search'),
    ];

    return SettingsHubSection(
      title: 'Activity',
      onAction: onOpen,
      child: GlassCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timeline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: p.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final t in timeline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.brandPrimaryHover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.$1,
                                    style: TextStyle(
                                        fontSize: 10, color: p.textMuted)),
                                Text(t.$2,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: p.textPrimary,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),
            for (var i = 0; i < rows.length; i++) ...[
              _HubRow(
                icon: rows[i].$1,
                color: rows[i].$2,
                title: rows[i].$3,
                subtitle: rows[i].$4,
                onTap: () => onItem(rows[i].$5),
                isLast: i == rows.length - 1,
              ),
              if (i != rows.length - 1)
                Divider(height: 1, indent: 66, color: p.border),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Support
// ─────────────────────────────────────────────────────────────────────────────

class SettingsSupportCard extends StatelessWidget {
  const SettingsSupportCard({
    super.key,
    required this.onOpen,
    required this.onItem,
  });

  final VoidCallback onOpen;
  final void Function(String id) onItem;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final rows = <(IconData, Color, String, String, String)>[
      (Icons.help_outline_rounded, AppColors.brandPrimaryHover, 'Help Center',
          'Guides & FAQs', 'help'),
      (Icons.bug_report_outlined, AppColors.error, 'Report Bug',
          'Tell us what broke', 'bug'),
      (Icons.feedback_outlined, AppColors.accentAudio, 'Feedback',
          'Share ideas', 'feedback'),
      (Icons.quiz_outlined, AppColors.accentDev, 'FAQ', 'Common questions',
          'faq'),
      (Icons.groups_outlined, AppColors.accentImage, 'Community',
          'Join Farvixo', 'community'),
      (Icons.privacy_tip_outlined, AppColors.accentText, 'Privacy Policy',
          'How we handle data', 'privacy_policy'),
      (Icons.description_outlined, AppColors.brandMagenta, 'Terms',
          'Terms of service', 'terms'),
      (Icons.info_outline_rounded, AppColors.goldPremium, 'About Farvixo',
          'Version & credits', 'about'),
      (Icons.star_outline_rounded, AppColors.goldPremium, 'Rate App',
          'Love Farvixo? Rate us', 'rate'),
    ];

    return SettingsHubSection(
      title: 'Support',
      onAction: onOpen,
      child: GlassCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _HubRow(
                icon: rows[i].$1,
                color: rows[i].$2,
                title: rows[i].$3,
                subtitle: rows[i].$4,
                onTap: () => onItem(rows[i].$5),
                isLast: i == rows.length - 1,
              ),
              if (i != rows.length - 1)
                Divider(height: 1, indent: 66, color: p.border),
            ],
          ],
        ),
      ),
    );
  }
}
