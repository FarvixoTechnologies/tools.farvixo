import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium_kit.dart';
import '../../../widgets/skeletons.dart';
import 'data/scan_history_repository.dart';
import 'models/qr_type.dart';
import 'providers/scan_history_providers.dart';
import 'services/qr_analytics.dart';

/// On-device usage analytics for the scan history: totals, a 7-day activity
/// chart, per-type breakdown and a security summary. Everything is computed
/// locally from Hive — no tracking. Reuses the Farvixo premium kit.
class QrAnalyticsScreen extends ConsumerWidget {
  const QrAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(scanHistoryRepositoryProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          child: repoAsync.when(
            loading: () => const _Skeleton(),
            error: (e, _) => const Center(child: Text('Analytics unavailable')),
            data: (repo) => _Body(repo: repo),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.repo});
  final ScanHistoryRepository repo;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo.listenable,
      builder: (context, _) {
        final stats =
            QrAnalytics.compute(repo.query(const HistoryQuery(), pageSize: 0));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.md, Insets.sm, Insets.md, 0),
              child: FadeSlideIn(
                child: PremiumHeader(
                  title: 'Analytics',
                  subtitle: 'On-device • no tracking',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            Expanded(
              child: stats.isEmpty
                  ? const PremiumEmptyState(
                      icon: Icons.insights_rounded,
                      title: 'Nothing to chart yet',
                      message: 'Scan a few codes and your usage insights will '
                          'appear here.',
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                          Insets.md, Insets.md, Insets.md, Insets.xxl),
                      children: [
                        FadeSlideIn(index: 1, child: _TotalsGrid(stats: stats)),
                        const SizedBox(height: Insets.md),
                        FadeSlideIn(index: 2, child: _ActivityChart(stats: stats)),
                        const SizedBox(height: Insets.md),
                        FadeSlideIn(index: 3, child: _TypeBreakdown(stats: stats)),
                        const SizedBox(height: Insets.md),
                        FadeSlideIn(index: 4, child: _SecurityCard(stats: stats)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────── totals

class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({required this.stats});
  final QrStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatTile(
                label: 'Total', value: stats.total, icon: Icons.qr_code_rounded,
                color: AppColors.brandPrimaryHover)),
        const SizedBox(width: Insets.sm),
        Expanded(
            child: _StatTile(
                label: 'Today', value: stats.today, icon: Icons.today_rounded,
                color: AppColors.accentImage)),
        const SizedBox(width: Insets.sm),
        Expanded(
            child: _StatTile(
                label: 'Week', value: stats.week,
                icon: Icons.date_range_rounded, color: AppColors.accentDev)),
        const SizedBox(width: Insets.sm),
        Expanded(
            child: _StatTile(
                label: 'Month', value: stats.month,
                icon: Icons.calendar_month_rounded,
                color: AppColors.accentAudio)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Insets.md, horizontal: Insets.sm),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? 0.6 : 0.9),
        borderRadius: Radii.brCard,
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text('$value',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: p.textPrimary)),
          Text(label,
              style: TextStyle(fontSize: 11, color: p.textMuted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── activity chart

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.stats});
  final QrStats stats;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final max = stats.busiestDayCount;
    final now = DateTime.now();
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 days',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: p.textPrimary)),
          const SizedBox(height: Insets.md),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _Bar(
                      value: stats.dailyCounts[i],
                      max: max,
                      label: dayLabels[
                          now.subtract(Duration(days: 6 - i)).weekday % 7],
                      accent: p.accent,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.max,
    required this.label,
    required this.accent,
  });
  final int value;
  final int max;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final frac = max == 0 ? 0.0 : value / max;
    return Semantics(
      label: '$label: $value scans',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: p.textMuted)),
          const SizedBox(height: 4),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: frac.clamp(0.03, 1.0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent, accent.withValues(alpha: 0.5)],
                  ),
                  borderRadius: Radii.brSm,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(fontSize: 11, color: p.textMuted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── type breakdown

class _TypeBreakdown extends StatelessWidget {
  const _TypeBreakdown({required this.stats});
  final QrStats stats;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final top = stats.topTypes;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By type',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: p.textPrimary)),
          const SizedBox(height: Insets.sm),
          for (final entry in top) ...[
            const SizedBox(height: Insets.sm),
            _TypeRow(
              type: entry.key,
              count: entry.value,
              fraction: stats.total == 0 ? 0 : entry.value / stats.total,
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.type,
    required this.count,
    required this.fraction,
  });
  final QrType type;
  final int count;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      label: '${type.label}: $count scans, ${(fraction * 100).round()} percent',
      child: Row(
        children: [
          Icon(type.icon, size: 16, color: type.accent),
          const SizedBox(width: Insets.sm),
          SizedBox(
            width: 64,
            child: Text(type.label,
                style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: Radii.brPill,
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: p.border.withValues(alpha: 0.4),
                color: type.accent,
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Text('$count',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: p.textPrimary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── security card

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.stats});
  final QrStats stats;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final clean = stats.threats == 0;
    final color = clean ? AppColors.success : AppColors.warning;
    return GlassCard(
      glowColor: color,
      child: Row(
        children: [
          GlowIcon(
            icon: clean ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clean
                      ? 'No risky links found'
                      : '${stats.threats} link${stats.threats == 1 ? '' : 's'} flagged',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary),
                ),
                Text(
                  'Offline security checks across your scanned links.',
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSkeletonCard(height: 40),
          const SizedBox(height: Insets.md),
          const AppSkeletonCard(height: 80),
          const SizedBox(height: Insets.md),
          const AppSkeletonCard(height: 160),
          const SizedBox(height: Insets.md),
          const AppSkeletonCard(height: 180),
        ],
      ),
    );
  }
}
