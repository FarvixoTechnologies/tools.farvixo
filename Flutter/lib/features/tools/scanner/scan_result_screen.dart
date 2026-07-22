import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium_kit.dart';
import 'models/parsed_qr.dart';
import 'models/qr_type.dart';
import 'services/qr_parser.dart';
import 'services/qr_security.dart';

/// Rich scan-result screen: parses a decoded string into a typed payload, runs
/// the offline security assessment, and offers contextual smart actions.
///
/// Reuses the existing premium kit + design tokens — no new theme surface.
/// High-risk links are gated behind a confirmation interstitial before opening.
class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key, required this.raw, this.source = 'camera'});

  /// Raw decoded string from the camera or a gallery image.
  final String raw;

  /// Where the scan came from — shown in metadata. 'camera' or 'gallery'.
  final String source;

  @override
  Widget build(BuildContext context) {
    final parsed = QrParser.parse(raw);
    final verdict = QrSecurity.assess(parsed);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.md, Insets.sm, Insets.md, 0),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: 'Scan Result',
                    subtitle: parsed.type.label,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.md, Insets.md, Insets.md, Insets.xxl),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    FadeSlideIn(
                      index: 1,
                      child: _HeaderCard(parsed: parsed),
                    ),
                    const SizedBox(height: Insets.md),
                    FadeSlideIn(
                      index: 2,
                      child: _SecurityCard(verdict: verdict),
                    ),
                    if (parsed.fields.isNotEmpty) ...[
                      const SizedBox(height: Insets.md),
                      FadeSlideIn(
                        index: 3,
                        child: _DetailsCard(parsed: parsed),
                      ),
                    ],
                    const SizedBox(height: Insets.md),
                    FadeSlideIn(
                      index: 4,
                      child: _RawCard(raw: parsed.raw, source: source),
                    ),
                    const SizedBox(height: Insets.lg),
                    FadeSlideIn(
                      index: 5,
                      child: _Actions(parsed: parsed, verdict: verdict),
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
}

// ─────────────────────────────────────────────────────────────── header card

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.parsed});
  final ParsedQr parsed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final accent = parsed.type.accentOf(context);
    return GlassCard(
      child: Row(
        children: [
          GlowIcon(icon: parsed.type.icon, color: accent, size: 56, iconSize: 28),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parsed.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                ),
                if (parsed.subtitle != null && parsed.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    parsed.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(context, color: p.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────── security card

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.verdict});
  final SecurityVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final (color, icon, label) = switch (verdict.level) {
      RiskLevel.safe => (AppColors.success, Icons.verified_user_rounded, 'Looks safe'),
      RiskLevel.caution => (AppColors.warning, Icons.warning_amber_rounded, 'Be careful'),
      RiskLevel.danger => (AppColors.error, Icons.gpp_bad_rounded, 'High risk'),
    };
    return GlassCard(
      glowColor: color,
      borderColor: color.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlowIcon(icon: icon, color: color, size: 44, iconSize: 22),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.titleSmall(context, color: color, weight: FontWeights.extrabold),
                    ),
                    Text(
                      'Offline check • '
                      '${(verdict.confidence * 100).round()}% confidence',
                      style: AppTypography.labelSmall(context, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              _RiskMeter(score: verdict.score, color: color),
            ],
          ),
          if (verdict.reasons.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            for (final reason in verdict.reasons)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 5, color: p.textMuted),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        reason,
                        style: AppTypography.bodySmall(context, color: p.textSecondary).copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RiskMeter extends StatelessWidget {
  const _RiskMeter({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 4,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$score',
            style: AppTypography.bodyMedium(context, color: color, weight: FontWeights.black),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── details card

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.parsed});
  final ParsedQr parsed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Hide the Wi-Fi password behind a masked value for shoulder-surfing safety.
    final entries = parsed.fields.entries
        .where((e) => e.value.isNotEmpty)
        .toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(height: Insets.md, color: p.border.withValues(alpha: 0.6)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    _prettyKey(entries[i].key),
                    style: AppTypography.bodySmall(context, color: p.textMuted, weight: FontWeights.bold),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    entries[i].value,
                    style: AppTypography.bodyMedium(context, color: p.textPrimary, weight: FontWeights.semibold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _prettyKey(String key) => switch (key) {
        'ssid' => 'Network',
        'vpa' => 'UPI ID',
        'url' => 'Address',
        _ => key.isEmpty ? key : '${key[0].toUpperCase()}${key.substring(1)}',
      };
}

// ─────────────────────────────────────────────────────────────────── raw card

class _RawCard extends StatelessWidget {
  const _RawCard({required this.raw, required this.source});
  final String raw;
  final String source;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object_rounded, size: 16, color: p.textMuted),
              const SizedBox(width: Insets.sm),
              Text(
                'Raw data • from $source',
                style: AppTypography.labelSmall(context, color: p.textMuted, weight: FontWeights.bold),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          SelectableText(
            raw,
            maxLines: 6,
            style: AppTypography.bodySmall(context, color: p.textSecondary).copyWith(height: 1.4, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────── actions

class _Actions extends StatelessWidget {
  const _Actions({required this.parsed, required this.verdict});
  final ParsedQr parsed;
  final SecurityVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final primary = _primaryAction(context);
    return Column(
      children: [
        if (primary != null) ...[
          primary,
          const SizedBox(height: Insets.sm),
        ],
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: () => _copy(context, parsed.raw),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: _SecondaryButton(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                onTap: () => Share.share(parsed.raw),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _primaryAction(BuildContext context) {
    final (label, icon) = switch (parsed.type) {
      QrType.url => ('Open Link', Icons.open_in_new_rounded),
      QrType.appLink => ('Open in App', Icons.open_in_new_rounded),
      QrType.phone => ('Call', Icons.call_rounded),
      QrType.sms => ('Send SMS', Icons.sms_rounded),
      QrType.email => ('Send Email', Icons.mail_rounded),
      QrType.geo => ('Open in Maps', Icons.map_rounded),
      QrType.upi => ('Open Payment App', Icons.payments_rounded),
      QrType.wifi => ('Copy Password', Icons.key_rounded),
      QrType.contact => ('Copy Contact', Icons.person_add_alt_rounded),
      _ => (null, Icons.open_in_new_rounded),
    };
    if (label == null) return null;

    return _PrimaryButton(
      label: label,
      icon: icon,
      accent: parsed.type.accentOf(context),
      onTap: () => _runPrimary(context),
    );
  }

  Future<void> _runPrimary(BuildContext context) async {
    switch (parsed.type) {
      case QrType.wifi:
        _copy(context, parsed.fields['password'] ?? '', 'Password copied');
      case QrType.contact:
        _copy(
          context,
          parsed.fields.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
          'Contact details copied',
        );
      default:
        final uri = parsed.actionUri;
        if (uri == null) return;
        // Danger interstitial — block auto-open of high-risk links.
        if (verdict.level == RiskLevel.danger) {
          final go = await _confirmDanger(context);
          if (go != true || !context.mounted) return;
        }
        await _launch(context, uri);
    }
  }

  Future<bool?> _confirmDanger(BuildContext context) {
    final p = AppPalette.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brPanel),
        icon: const Icon(Icons.gpp_bad_rounded, color: AppColors.error, size: 34),
        title: Text('Open risky link?',
            style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.extrabold)),
        content: Text(
          verdict.reasons.isNotEmpty
              ? verdict.reasons.first
              : 'This link was flagged as high risk.',
          style: AppTypography.bodyLarge(context, color: p.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.bodyLarge(context, color: p.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(BuildContext context, String uri) async {
    final parsedUri = Uri.tryParse(uri);
    var ok = false;
    if (parsedUri != null) {
      ok = await launchUrl(parsedUri, mode: LaunchMode.externalApplication)
          .catchError((_) => false);
    }
    if (!ok && context.mounted) {
      _snack(context, 'No app found to open this');
    }
  }

  void _copy(BuildContext context, String text, [String msg = 'Copied']) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    _snack(context, msg);
  }

  void _snack(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: Radii.brButton,
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.75)],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.onAccent, size: 20),
              const SizedBox(width: Insets.sm),
              Text(
                label,
                style: AppTypography.titleSmall(context, color: AppColors.onAccent, weight: FontWeights.extrabold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
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
          height: 48,
          decoration: BoxDecoration(
            borderRadius: Radii.brButton,
            color: p.surface.withValues(alpha: 0.7),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: p.textPrimary, size: 18),
              const SizedBox(width: Insets.sm),
              Text(
                label,
                style: AppTypography.bodyMedium(context, color: p.textPrimary, weight: FontWeights.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
