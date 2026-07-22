/// Tilt-on-touch — the card leans toward the finger/pointer in subtle 3D,
/// then springs back on release. Works with touch and mouse hover.
library;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class TiltCard extends StatefulWidget {
  const TiltCard({
    super.key,
    required this.child,
    this.maxTilt = 0.045,
    this.scale = 1.015,
    this.enabled = true,
    this.onTap,
  });

  final Widget child;

  /// Max rotation in radians on each axis.
  final double maxTilt;

  /// Slight lift while tilted.
  final double scale;

  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  Alignment _pointer = Alignment.center;
  bool _active = false;

  bool get _on => widget.enabled && !Motion.reduced(context);

  void _update(Offset local, Size size) {
    if (!_on) return;
    setState(() {
      _active = true;
      _pointer = Alignment(
        (local.dx / size.width) * 2 - 1,
        (local.dy / size.height) * 2 - 1,
      );
    });
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _active = false;
      _pointer = Alignment.center;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return MouseRegion(
          onHover: (e) => _update(e.localPosition, size),
          onExit: (_) => _reset(),
          child: GestureDetector(
            // Press + hover only — no pan handlers, so the card never steals
            // vertical drags from an enclosing scroll view.
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: (d) => _update(d.localPosition, size),
            onTapUp: (_) => _reset(),
            onTapCancel: _reset,
            child: TweenAnimationBuilder<Alignment>(
              tween: AlignmentTween(
                  end: _active ? _pointer : Alignment.center),
              duration:
                  Motion.of(context, _active ? Motion.instant : Motion.slow),
              curve: _active ? Motion.easeOut : Motion.spring,
              builder: (context, align, child) {
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateX(-align.y * widget.maxTilt)
                  ..rotateY(align.x * widget.maxTilt);
                if (_active) {
                  transform.scaleByDouble(
                      widget.scale, widget.scale, 1, 1);
                }
                return Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
