import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Animated dashboard backdrop: two drifting blurred brand orbs plus a
/// twinkling star field (dark mode only). Painted behind the Home scroll view;
/// drive [t] from a looping controller (0 → 1 over ~30s).
class DashBackgroundPainter extends CustomPainter {
  DashBackgroundPainter(this.t, this.isDark);

  final double t;
  final bool isDark;

  static final _stars = List.generate(50, (i) {
    final rnd = math.Random(i * 13 + 5);
    return (
      rnd.nextDouble(),
      rnd.nextDouble(),
      rnd.nextDouble() * 1.3 + .3,
      rnd.nextDouble() * math.pi * 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final orb = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    final drift = math.sin(t * 2 * math.pi) * 30;
    final base = isDark ? .12 : .06;
    orb.color = AppColors.brandPrimary.withValues(alpha: base);
    canvas.drawCircle(
      Offset(size.width * .1 + drift, size.height * .08),
      120,
      orb,
    );
    orb.color = AppColors.brandMagenta.withValues(alpha: base * .7);
    canvas.drawCircle(
      Offset(size.width * .9 - drift, size.height * .5),
      130,
      orb,
    );

    if (isDark) {
      final p = Paint();
      for (final (x, y, r, phase) in _stars) {
        final tw = .12 + (math.sin(t * 20 + phase) + 1) / 2 * .35;
        p.color = AppColors.brandPrimaryHover.withValues(alpha: tw);
        canvas.drawCircle(Offset(x * size.width, y * size.height), r, p);
      }
    }
  }

  @override
  bool shouldRepaint(DashBackgroundPainter old) =>
      old.t != t || old.isDark != isDark;
}
