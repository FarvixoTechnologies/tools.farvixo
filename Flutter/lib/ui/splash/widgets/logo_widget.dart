import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/launch/models/splash_config.dart';
import '../../../widgets/farvixo_logo.dart';
import '../../../theme/design_tokens.dart';

/// Splash brand mark — logo with 'scale_fade_rotate' reveal inside a
/// rotating AI orbit ring with neon glow (LAUNCH & SPLASH SYSTEM v2.0.0,
/// sections 2 & 7: AI Orbit, Logo Reveal, Neon Accents).
class LogoWidget extends StatelessWidget {
  const LogoWidget({
    super.key,
    required this.config,
    required this.reveal,
    required this.orbit,
    this.size = 96,
  });

  final SplashConfig config;

  /// One-shot 0→1 intro (scale + fade + rotate).
  final Animation<double> reveal;

  /// Continuous 0→1 loop rotating the orbit ring (static when reduced
  /// motion is on).
  final Animation<double> orbit;

  final double size;

  @override
  Widget build(BuildContext context) {
    final ringSize = size * 1.9;
    final colors = config.particleColors;
    final glowColor = config.progressColor;

    return AnimatedBuilder(
      animation: Listenable.merge([reveal, orbit]),
      builder: (context, _) {
        final t = Motion.emphasized.transform(reveal.value.clamp(0.0, 1.0));
        final fade = Motion.easeOut.transform(reveal.value.clamp(0.0, 1.0));
        final rotate =
            config.logoAnimation == 'scale_fade_rotate' ? (1 - t) * 0.35 : 0.0;

        return Opacity(
          opacity: fade,
          child: SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Orbit ring (rotating gradient arc + orbiting dot).
                Transform.rotate(
                  angle: orbit.value * 2 * pi,
                  child: CustomPaint(
                    size: Size.square(ringSize),
                    painter: _OrbitRingPainter(colors: colors),
                  ),
                ),
                // Neon glow + logo reveal.
                Transform.rotate(
                  angle: rotate,
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.45 * fade),
                            blurRadius: 56,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: FarvixoLogo(size: size),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  _OrbitRingPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          colors.first.withValues(alpha: 0),
          colors.first,
          colors.length > 1 ? colors[1] : colors.first,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

    // 300° arc leaves a gap that reads as motion while rotating.
    canvas.drawArc(rect, 0, 2 * pi * 0.83, false, ring);

    // Orbiting dot at the arc head.
    final head = 2 * pi * 0.83;
    final dot = Paint()
      ..color = colors.length > 1 ? colors[1] : colors.first
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      center + Offset(cos(head), sin(head)) * radius,
      5,
      dot,
    );
  }

  @override
  bool shouldRepaint(_OrbitRingPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
