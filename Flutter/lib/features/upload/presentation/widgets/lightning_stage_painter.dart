import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../theme/design_tokens.dart';
import '../../../../theme/upload_theme.dart';
import '../../domain/upload_status.dart';

/// Paints the Lightning Upload key art.
///
/// Layer order, back to front:
///   1. night sky + vignette
///   2. ground glow pooling under the platform
///   3. storm cloud (stacked lobes, rim-lit from the strike)
///   4. lightning bolt (glow pass, then hot core)
///   5. energy arcs crawling around the platform
///   6. folder — body, gold edge, gloss sweep
///   7. upload arrow (gradient + inner light)
///   8. gold ring (spins while transferring)
///   9. metal platform with slot detail
///  10. floating spark particles
///
/// Everything is laid out in fractions of [size] (see [UploadStage]) so the
/// composition is pixel-identical from a 320 px phone to an ultrawide panel.
class LightningStagePainter extends CustomPainter {
  const LightningStagePainter({
    required this.phase,
    required this.accent,
    required this.float,
    required this.strike,
    required this.spin,
    required this.progress,
    required this.burst,
  });

  /// How the stage should behave.
  final StagePhase phase;

  /// Stage accent — gold normally, green on success, rose on failure.
  final Color accent;

  /// 0–1 folder float loop.
  final double float;

  /// 0–1 lightning strike envelope; 0 = dark, 1 = peak flash.
  final double strike;

  /// 0–1 ring rotation.
  final double spin;

  /// 0–1 transfer progress; fills the ring.
  final double progress;

  /// 0–1 completion burst.
  final double burst;

  bool get _faulted => phase == StagePhase.faulted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Folder bobs on the float loop; a sine gives an ease at both extremes.
    final bob = math.sin(float * 2 * math.pi) * UploadStage.floatTravel;

    _paintSky(canvas, size);
    _paintGroundGlow(canvas, size);
    _paintCloud(canvas, size);
    if (!_faulted && strike > 0.01) _paintBolt(canvas, size);
    _paintPlatform(canvas, size);
    _paintRing(canvas, size);
    _paintFolder(canvas, size, bob);
    _paintArrow(canvas, size, bob);
    _paintParticles(canvas, size);
    if (burst > 0.01) _paintBurst(canvas, size);

    // Keep the analyzer honest about unused locals in future edits.
    assert(w > 0 && h > 0);
  }

  // -------------------------------------------------------------------
  // 1. Sky
  // -------------------------------------------------------------------

  void _paintSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = UploadPalette.sky.createShader(rect));

    // Corner vignette so the art reads as a lit stage, not a flat panel.
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: const [UploadPalette.clear, UploadPalette.vignette],
        stops: const [0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  // -------------------------------------------------------------------
  // 2. Ground glow
  // -------------------------------------------------------------------

  void _paintGroundGlow(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * UploadStage.ringCenter);
    final intensity = _faulted ? 0.10 : 0.22 + strike * 0.30;
    final radius = size.width * (0.44 + strike * 0.06);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: intensity),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  // -------------------------------------------------------------------
  // 3. Storm cloud
  // -------------------------------------------------------------------

  void _paintCloud(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h * (UploadStage.cloudTop + UploadStage.cloudHeight * 0.55);
    final cx = w / 2;
    final unit = w * 0.13;

    // Lobe layout: (dx, dy, radius) in units — a wide base with a taller
    // stack right of centre, matching the key art silhouette.
    const lobes = <(double, double, double)>[
      (-1.55, 0.28, 0.86),
      (-0.90, -0.20, 1.05),
      (-0.10, -0.52, 1.18),
      (0.78, -0.24, 1.06),
      (1.52, 0.24, 0.88),
      (-0.55, 0.52, 0.80),
      (0.42, 0.56, 0.84),
    ];

    final saturation = _faulted ? 0.35 : 1.0;
    Color lerp(Color a, Color b, double t) => Color.lerp(a, b, t)!;

    // Body — back lobes darker, front lobes lighter.
    for (var i = 0; i < lobes.length; i++) {
      final (dx, dy, r) = lobes[i];
      final centre = Offset(cx + dx * unit, cy + dy * unit);
      final radius = r * unit;
      final depth = i / (lobes.length - 1);
      final base = lerp(
        UploadPalette.cloudMid,
        UploadPalette.cloudDark,
        depth * 0.7,
      );
      final tinted = _faulted
          ? lerp(base, UploadPalette.paused, 1 - saturation)
          : base;

      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.5),
            colors: [
              lerp(tinted, UploadPalette.cloudLight, 0.55),
              tinted,
              lerp(tinted, UploadPalette.cloudShadow, 0.6),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    // Under-lighting from the strike — the cloud's belly catches the bolt.
    if (!_faulted && strike > 0.01) {
      final rimRect = Rect.fromCenter(
        center: Offset(cx, cy + unit * 0.7),
        width: unit * 3.6,
        height: unit * 1.6,
      );
      canvas.drawOval(
        rimRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: 0.55 * strike),
              accent.withValues(alpha: 0),
            ],
          ).createShader(rimRect)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  // -------------------------------------------------------------------
  // 4. Lightning
  // -------------------------------------------------------------------

  /// Deterministic jagged bolt — same shape every strike so it reads as one
  /// consistent piece of art rather than random noise.
  Path _boltPath(Size size) {
    final w = size.width;
    final h = size.height;
    final top = h * UploadStage.boltTop;
    final bottom = h * UploadStage.boltBottom;
    final cx = w / 2;
    final span = w * 0.10;

    // (t along the strike, lateral offset in span units)
    const nodes = <(double, double)>[
      (0.00, 0.10),
      (0.16, -0.42),
      (0.31, 0.28),
      (0.47, -0.30),
      (0.63, 0.34),
      (0.79, -0.18),
      (1.00, 0.06),
    ];

    final path = Path();
    for (var i = 0; i < nodes.length; i++) {
      final (t, off) = nodes[i];
      final p = Offset(cx + off * span, top + (bottom - top) * t);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    // Two short forks branching off the main channel.
    final forkA = Offset(cx + 0.28 * span, top + (bottom - top) * 0.31);
    path
      ..moveTo(forkA.dx, forkA.dy)
      ..lineTo(forkA.dx + span * 0.55, forkA.dy + (bottom - top) * 0.14)
      ..lineTo(forkA.dx + span * 0.30, forkA.dy + (bottom - top) * 0.26);

    final forkB = Offset(cx - 0.30 * span, top + (bottom - top) * 0.47);
    path
      ..moveTo(forkB.dx, forkB.dy)
      ..lineTo(forkB.dx - span * 0.60, forkB.dy + (bottom - top) * 0.16)
      ..lineTo(forkB.dx - span * 0.34, forkB.dy + (bottom - top) * 0.30);

    return path;
  }

  void _paintBolt(Canvas canvas, Size size) {
    final path = _boltPath(size);
    final unit = size.width;

    // Outer glow — wide, soft, additive.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.055 * strike
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent.withValues(alpha: 0.30 * strike)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.045)
        ..blendMode = BlendMode.plus,
    );

    // Mid body — the gold channel.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.020 * strike
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent.withValues(alpha: 0.95 * strike)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.010),
    );

    // Hot core — near-white centre line.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.007 * strike
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = UploadPalette.boltCore.withValues(alpha: strike),
    );
  }

  // -------------------------------------------------------------------
  // 5. Platform
  // -------------------------------------------------------------------

  void _paintPlatform(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final left = w * UploadStage.platformInset;
    final right = w * (1 - UploadStage.platformInset);
    final top = h * UploadStage.platformTop;
    final height = h * 0.13;

    final body = RRect.fromLTRBR(
      left,
      top,
      right,
      top + height,
      Radius.circular(height * 0.42),
    );

    canvas.drawRRect(
      body,
      Paint()
        ..shader = UploadPalette.platform.createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004
        ..color = UploadPalette.platformEdge,
    );

    // Vent slots along the front face.
    final slotY = top + height * 0.62;
    final slotW = w * 0.030;
    final slotH = height * 0.16;
    for (var i = -3; i <= 3; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2 + i * slotW * 1.9, slotY),
          width: slotW,
          height: slotH,
        ),
        Radius.circular(slotH / 2),
        // (radius derives from geometry, not a token scale)
      );
      canvas.drawRRect(rect, Paint()..color = UploadPalette.platformSlot);
    }

    // Accent strip catching the ring light.
    final strip = RRect.fromLTRBR(
      left + w * 0.06,
      top + height * 0.26,
      right - w * 0.06,
      top + height * 0.32,
      Radii.rPill,
    );
    canvas.drawRRect(
      strip,
      Paint()..color = accent.withValues(alpha: _faulted ? 0.12 : 0.35),
    );
  }

  // -------------------------------------------------------------------
  // 6. Ring
  // -------------------------------------------------------------------

  void _paintRing(Canvas canvas, Size size) {
    final w = size.width;
    final centre = Offset(w / 2, size.height * UploadStage.ringCenter);
    final rect = Rect.fromCenter(
      center: centre,
      width: w * 0.74,
      height: w * 0.74 * 0.30,
    );
    final stroke = w * UploadStage.ringStroke;

    // Ambient track.
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = accent.withValues(alpha: _faulted ? 0.14 : 0.28),
    );

    if (_faulted) return;

    // Glow bloom behind the ring.
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 2.6
        ..color = accent.withValues(alpha: 0.22 + strike * 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.035)
        ..blendMode = BlendMode.plus,
    );

    // Progress arc — sweeps clockwise from the left.
    if (progress > 0) {
      canvas.drawArc(
        rect,
        math.pi,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.5
          ..strokeCap = StrokeCap.round
          ..color = UploadPalette.boltCore,
      );
    }

    // Chasing highlight while energy is flowing.
    if (phase == StagePhase.working || phase == StagePhase.striking) {
      final sweep = math.pi * 0.42;
      canvas.drawArc(
        rect,
        spin * 2 * math.pi,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.8
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(
            rect.topLeft,
            rect.bottomRight,
            [accent.withValues(alpha: 0), UploadPalette.boltCore],
          )
          ..blendMode = BlendMode.plus,
      );
    }
  }

  // -------------------------------------------------------------------
  // 7. Folder
  // -------------------------------------------------------------------

  void _paintFolder(Canvas canvas, Size size, double bob) {
    final w = size.width;
    final h = size.height;
    final left = w * UploadStage.folderInset;
    final right = w * (1 - UploadStage.folderInset);
    final top = h * UploadStage.folderTop + bob;
    final bottom = top + h * UploadStage.folderHeight;
    final radius = Radius.circular(w * 0.055);

    // Tab on the back panel.
    final tabW = (right - left) * 0.42;
    final tab = RRect.fromLTRBAndCorners(
      left,
      top - h * 0.045,
      left + tabW,
      top + h * 0.03,
      topLeft: radius,
      topRight: radius,
    );
    canvas.drawRRect(
      tab,
      Paint()
        ..shader = UploadPalette.folder.createShader(tab.outerRect),
    );
    canvas.drawRRect(
      tab,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.005
        ..color = UploadPalette.folderEdge.withValues(alpha: 0.65),
    );

    // Drop shadow onto the platform.
    final body = RRect.fromLTRBR(left, top, right, bottom, radius);
    canvas.drawRRect(
      body.shift(Offset(0, h * 0.02)),
      Paint()
        ..color = UploadPalette.contactShadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );

    // Body.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = UploadPalette.folder.createShader(body.outerRect),
    );

    // Gold edge — hotter while charging or striking.
    final edgeHeat = _faulted ? 0.0 : strike;
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.008
        ..shader = ui.Gradient.linear(
          body.outerRect.topCenter,
          body.outerRect.bottomCenter,
          [
            Color.lerp(
              UploadPalette.folderEdge,
              UploadPalette.folderEdgeHot,
              edgeHeat,
            )!,
            UploadPalette.folderEdge.withValues(alpha: 0.45),
          ],
        ),
    );

    // Gloss sweep across the upper face.
    final gloss = Path()
      ..moveTo(left, top + (bottom - top) * 0.10)
      ..lineTo(right, top + (bottom - top) * 0.02)
      ..lineTo(right, top + (bottom - top) * 0.34)
      ..lineTo(left, top + (bottom - top) * 0.52)
      ..close();
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawPath(gloss, Paint()..color = UploadPalette.folderGloss);
    canvas.restore();
  }

  // -------------------------------------------------------------------
  // 8. Arrow
  // -------------------------------------------------------------------

  void _paintArrow(Canvas canvas, Size size, double bob) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final top = h * (UploadStage.folderTop + 0.055) + bob;
    final bottomY = h * (UploadStage.folderTop + UploadStage.folderHeight - 0.06) + bob;

    final headW = w * 0.30;
    final shaftW = w * 0.115;
    final headH = (bottomY - top) * 0.52;

    final path = Path()
      ..moveTo(cx, top)
      ..lineTo(cx + headW / 2, top + headH)
      ..lineTo(cx + shaftW / 2, top + headH)
      ..lineTo(cx + shaftW / 2, bottomY)
      ..lineTo(cx - shaftW / 2, bottomY)
      ..lineTo(cx - shaftW / 2, top + headH)
      ..lineTo(cx - headW / 2, top + headH)
      ..close();

    final bounds = path.getBounds();

    // Glow behind the arrow.
    if (!_faulted) {
      canvas.drawPath(
        path,
        Paint()
          ..color = accent.withValues(alpha: 0.35 + strike * 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05)
          ..blendMode = BlendMode.plus,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = _faulted
            ? ui.Gradient.linear(
                bounds.topCenter,
                bounds.bottomCenter,
                [UploadPalette.paused, UploadPalette.cloudDark],
              )
            : UploadPalette.arrow.createShader(bounds),
    );

    // Inner highlight down the left facet, for the 3D read.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTRB(bounds.left, bounds.top, cx, bounds.bottom),
      Paint()..color = UploadPalette.boltCore.withValues(alpha: 0.16),
    );
    canvas.restore();
  }

  // -------------------------------------------------------------------
  // 9. Particles
  // -------------------------------------------------------------------

  static final List<(double, double, double, double)> _sparks =
      List.generate(22, (i) {
    final rnd = math.Random(i * 977 + 13);
    return (
      rnd.nextDouble(), // x fraction
      rnd.nextDouble(), // y seed
      rnd.nextDouble() * 1.6 + 0.6, // radius
      rnd.nextDouble() * 0.6 + 0.4, // speed
    );
  });

  void _paintParticles(Canvas canvas, Size size) {
    if (_faulted) return;
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final (fx, seed, r, speed) in _sparks) {
      // Sparks drift upward and wrap.
      final y = (seed - float * speed) % 1.0;
      final alpha = (math.sin(y * math.pi)) * (0.35 + strike * 0.4);
      if (alpha <= 0.02) continue;
      paint.color = accent.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(fx * size.width, size.height * (0.30 + y * 0.55)),
        r,
        paint,
      );
    }
  }

  // -------------------------------------------------------------------
  // 10. Completion burst
  // -------------------------------------------------------------------

  void _paintBurst(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * UploadStage.ringCenter);
    final t = Motion.easeOut.transform(burst.clamp(0.0, 1.0));
    final radius = size.width * (0.20 + t * 0.42);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.014 * (1 - t)
        ..color = accent.withValues(alpha: (1 - t) * 0.9)
        ..blendMode = BlendMode.plus,
    );

    // Radiating spokes.
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final inner = radius * 0.72;
      final outer = radius * (0.92 + t * 0.2);
      canvas.drawLine(
        centre + Offset(math.cos(angle) * inner, math.sin(angle) * inner * 0.35),
        centre + Offset(math.cos(angle) * outer, math.sin(angle) * outer * 0.35),
        Paint()
          ..strokeWidth = size.width * 0.006 * (1 - t)
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: (1 - t) * 0.75)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  @override
  bool shouldRepaint(LightningStagePainter old) =>
      old.phase != phase ||
      old.accent != accent ||
      old.float != float ||
      old.strike != strike ||
      old.spin != spin ||
      old.progress != progress ||
      old.burst != burst;
}
