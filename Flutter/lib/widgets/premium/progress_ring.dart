/// Circular progress ring with rolling percent, gradient sweep and milestone
/// haptics — the centerpiece of every tool's processing state.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import 'animated_count.dart';
import 'app_haptics.dart';
import '../../theme/app_typography.dart';

class PremiumProgressRing extends StatefulWidget {
  const PremiumProgressRing({
    super.key,
    required this.progress,
    this.size = 96,
    this.strokeWidth = 8,
    this.color,
    this.label,
    this.milestoneHaptics = true,
  });

  /// 0.0 → 1.0. Animates smoothly between updates.
  final double progress;

  final double size;
  final double strokeWidth;

  /// Ring color; defaults to the theme accent.
  final Color? color;

  /// Small caption under the percent (e.g. "Page 12 of 18").
  final String? label;

  /// Fire a subtle haptic tick at 25 / 50 / 75 / 100 percent.
  final bool milestoneHaptics;

  @override
  State<PremiumProgressRing> createState() => _PremiumProgressRingState();
}

class _PremiumProgressRingState extends State<PremiumProgressRing> {
  int _lastMilestone = 0;

  @override
  void didUpdateWidget(PremiumProgressRing old) {
    super.didUpdateWidget(old);
    if (!widget.milestoneHaptics) return;
    final milestone = (widget.progress.clamp(0.0, 1.0) * 4).floor();
    if (milestone > _lastMilestone) {
      _lastMilestone = milestone;
      AppHaptics.milestone();
    } else if (widget.progress < old.progress) {
      _lastMilestone = milestone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = widget.color ?? p.accent;
    final clamped = widget.progress.clamp(0.0, 1.0);

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: clamped),
        duration: Motion.of(context, Motion.slow),
        curve: Motion.easeOut,
        builder: (context, value, _) => SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: color,
              track: p.border,
              strokeWidth: widget.strokeWidth,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCount(
                    value: clamped * 100,
                    suffix: '%',
                    style: AppTypography.metricStyle.copyWith(
                      fontSize: widget.size * 0.2,
                      fontWeight: FontWeights.bold,
                      color: p.textPrimary,
                    ),
                  ),
                  if (widget.label != null)
                    Text(
                      widget.label!,
                      style: AppTypography.captionStyle.copyWith(
                        fontSize: widget.size * 0.1,
                        color: p.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    const start = -math.pi / 2;
    final sweep = progress * math.pi * 2;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: const GradientRotation(start),
        colors: [
          color.withValues(alpha: 0.55),
          color,
        ],
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, progressPaint);

    // Glowing head dot at the tip of the arc.
    final head = Offset(
      center.dx + radius * math.cos(start + sweep),
      center.dy + radius * math.sin(start + sweep),
    );
    canvas.drawCircle(
      head,
      strokeWidth * 0.9,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(head, strokeWidth / 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
