/// Success confetti — a physics-driven burst rendered with a single
/// CustomPainter (no package, no jank). Colors come from the tool's own
/// identity so every tool celebrates in its own palette.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Overlay a confetti burst on any subtree. Fire it via [ConfettiController].
///
/// ```dart
/// final confetti = ConfettiController();
/// ...
/// ConfettiBurst(
///   controller: confetti,
///   colors: identity.confettiColors,
///   child: resultView,
/// )
/// ...
/// confetti.fire(); // on success
/// ```
class ConfettiController extends ChangeNotifier {
  int _generation = 0;
  int get generation => _generation;

  /// Triggers a new burst.
  void fire() {
    _generation++;
    notifyListeners();
  }
}

class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    required this.controller,
    required this.colors,
    this.particleCount = 90,
    this.origin = const Alignment(0, -0.2),
    required this.child,
  });

  final ConfettiController controller;
  final List<Color> colors;
  final int particleCount;

  /// Where the burst originates within the child's bounds.
  final Alignment origin;

  final Widget child;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: Motion.verySlow,
  );
  List<_Particle> _particles = const [];
  int _seenGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onFire);
  }

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onFire);
      widget.controller.addListener(_onFire);
    }
  }

  void _onFire() {
    if (widget.controller.generation == _seenGeneration) return;
    _seenGeneration = widget.controller.generation;
    if (Motion.reduced(context)) return;
    final rnd = math.Random();
    _particles = List.generate(widget.particleCount, (i) {
      final angle = rnd.nextDouble() * math.pi * 2;
      final speed = 0.35 + rnd.nextDouble() * 0.85;
      return _Particle(
        color: widget.colors[i % widget.colors.length],
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 0.9,
        size: 3.5 + rnd.nextDouble() * 4.5,
        spin: (rnd.nextDouble() - 0.5) * 14,
        drift: (rnd.nextDouble() - 0.5) * 0.25,
        shape: i % 3,
      );
    });
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFire);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  if (!_anim.isAnimating) return const SizedBox.shrink();
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      _particles,
                      _anim.value,
                      widget.origin,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Particle {
  const _Particle({
    required this.color,
    required this.vx,
    required this.vy,
    required this.size,
    required this.spin,
    required this.drift,
    required this.shape,
  });

  final Color color;
  final double vx;
  final double vy;
  final double size;
  final double spin;
  final double drift;
  final int shape;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t, this.origin);

  final List<_Particle> particles;
  final double t;
  final Alignment origin;

  static const double _gravity = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final ox = size.width * (origin.x + 1) / 2;
    final oy = size.height * (origin.y + 1) / 2;
    final fade = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
    final paint = Paint();

    for (final p in particles) {
      final x = ox +
          (p.vx * t + p.drift * t * t) * size.width;
      final y = oy +
          (p.vy * t + _gravity * t * t / 2) * size.height;
      if (y > size.height + 20) continue;

      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        default:
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 2, p.size / 2)
            ..lineTo(-p.size / 2, p.size / 2)
            ..close();
          canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
