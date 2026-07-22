import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/launch/models/splash_config.dart';
import '../../../theme/app_colors.dart';

/// Animated splash background — deep gradient + floating particle orbs
/// (LAUNCH & SPLASH SYSTEM v2.0.0, section 7: Particle Systems, Gradient
/// Mesh, Floating Orbs, Neon Accents). Respects reduced motion.
class BackgroundEffect extends StatelessWidget {
  const BackgroundEffect({
    super.key,
    required this.config,
    required this.animation,
  });

  final SplashConfig config;

  /// Continuous 0→1 loop driving particle drift (paused when reduced
  /// motion is enabled — particles render statically).
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final base = config.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: config.backgroundType == 'gradient'
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(base, AppColors.violetNight, 0.35)!,
                  base,
                  Color.lerp(base, AppColors.scrim, 0.35)!,
                ],
              )
            : null,
        color: config.backgroundType == 'gradient' ? null : base,
      ),
      child: config.enableParticles
          ? AnimatedBuilder(
              animation: animation,
              builder: (context, _) => CustomPaint(
                painter: _ParticlePainter(
                  t: animation.value,
                  colors: config.particleColors,
                ),
                size: Size.infinite,
              ),
            )
          : const SizedBox.expand(),
    );
  }
}

class _Particle {
  _Particle(Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        radius = 1.5 + rng.nextDouble() * 3.5,
        speed = 0.2 + rng.nextDouble() * 0.8,
        phase = rng.nextDouble() * 2 * pi,
        colorIndex = rng.nextInt(2);

  final double x, y, radius, speed, phase;
  final int colorIndex;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.t, required this.colors});

  final double t;
  final List<Color> colors;

  // Deterministic field so repaints are stable and cheap.
  static final List<_Particle> _particles =
      List.generate(24, (i) => _Particle(Random(42 + i)));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in _particles) {
      final drift = sin(2 * pi * (t * p.speed) + p.phase);
      final dx = p.x * size.width + drift * 14;
      final dy =
          (p.y * size.height - t * p.speed * 40) % (size.height + 40) - 20;
      final color = colors[p.colorIndex % colors.length];
      final pulse = 0.35 + 0.3 * (0.5 + 0.5 * drift);
      paint.color = color.withValues(alpha: 0.12 * pulse * 4);
      canvas.drawCircle(Offset(dx, dy), p.radius * (0.8 + 0.4 * pulse), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.colors != colors;
}
