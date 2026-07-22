/// Animated equalizer bars — the processing signature for video and audio
/// tools. Pure CustomPainter (no package), tool-accent colored, freezes to a
/// static waveform under reduce-motion.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class WaveformBars extends StatefulWidget {
  const WaveformBars({
    super.key,
    required this.color,
    this.barCount = 24,
    this.height = 56,
    this.width = 180,
  });

  final Color color;
  final int barCount;
  final double height;
  final double width;

  @override
  State<WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<WaveformBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: Motion.pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      if (_anim.isAnimating) _anim.stop();
    } else if (!_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => CustomPaint(
            painter: _WaveformPainter(
              t: _anim.value,
              color: widget.color,
              barCount: widget.barCount,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.t,
    required this.color,
    required this.barCount,
  });

  final double t;
  final Color color;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (barCount * 1.6);
    final gap = (size.width - barWidth * barCount) / (barCount - 1);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < barCount; i++) {
      final phase = i / barCount * math.pi * 2;
      // Two overlapping waves + per-bar offset gives an organic bounce.
      final wave = math.sin(t * math.pi * 2 * 2 + phase * 3) * 0.5 +
          math.sin(t * math.pi * 2 * 3 + phase * 5) * 0.5;
      final norm = (wave + 1) / 2;
      final h = size.height * (0.18 + norm * 0.72);
      final x = i * (barWidth + gap) + barWidth / 2;
      final centerY = size.height / 2;

      paint
        ..shader = null
        ..color = color.withValues(alpha: 0.35 + norm * 0.65)
        ..strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x, centerY - h / 2),
        Offset(x, centerY + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.t != t || old.color != color || old.barCount != barCount;
}
