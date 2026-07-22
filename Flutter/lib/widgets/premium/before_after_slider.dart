/// Interactive before/after comparison — drag the divider to reveal the
/// processed result over the original. Used by image tools (compress,
/// enhance, background remover) and any tool with a visual result.
library;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import 'app_haptics.dart';
import '../../theme/app_typography.dart';

class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.beforeLabel = 'Before',
    this.afterLabel = 'After',
    this.borderRadius,
    this.aspectRatio = 4 / 3,
  });

  final Widget before;
  final Widget after;
  final String beforeLabel;
  final String afterLabel;
  final BorderRadius? borderRadius;
  final double aspectRatio;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _position = 0.5;
  bool _snapped = false;

  void _drag(double dx, double width) {
    final next = (dx / width).clamp(0.0, 1.0);
    // Haptic detent at center.
    final nearCenter = (next - 0.5).abs() < 0.02;
    if (nearCenter && !_snapped) {
      _snapped = true;
      AppHaptics.tick();
    } else if (!nearCenter) {
      _snapped = false;
    }
    setState(() => _position = next);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = widget.borderRadius ?? Radii.brCard;

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            onHorizontalDragStart: (d) => _drag(d.localPosition.dx, width),
            onHorizontalDragUpdate: (d) => _drag(d.localPosition.dx, width),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.before,
                  ClipRect(
                    clipper: _RevealClipper(_position),
                    child: widget.after,
                  ),
                  // Divider line + handle.
                  Align(
                    alignment: Alignment(_position * 2 - 1, 0),
                    child: _DividerHandle(palette: p),
                  ),
                  Positioned(
                    left: Insets.smd,
                    top: Insets.smd,
                    child: _Tag(text: widget.beforeLabel, palette: p),
                  ),
                  Positioned(
                    right: Insets.smd,
                    top: Insets.smd,
                    child: _Tag(text: widget.afterLabel, palette: p),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.position);
  final double position;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * position, 0, size.width, size.height);

  @override
  bool shouldReclip(_RevealClipper old) => old.position != position;
}

class _DividerHandle extends StatelessWidget {
  const _DividerHandle({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Column(
        children: [
          Expanded(child: Center(child: _line())),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(color: palette.border),
              boxShadow: Elevations.card(palette),
            ),
            child: Icon(
              Icons.unfold_more_rounded,
              size: 20,
              color: palette.textPrimary,
            ),
          ),
          Expanded(child: Center(child: _line())),
        ],
      ),
    );
  }

  Widget _line() => Container(
        width: 2.5,
        color: palette.surface.withValues(alpha: 0.9),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.palette});
  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.smd, vertical: Insets.xs),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.85),
        borderRadius: Radii.brPill,
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: AppTypography.labelMedium(context, color: palette.textPrimary, weight: FontWeights.semibold),
      ),
    );
  }
}
