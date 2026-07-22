/// Rolling number display — values never jump, they roll. Used for file
/// sizes, progress percents, stat cards and result reveals.
library;

import 'package:flutter/widgets.dart';

import '../../theme/design_tokens.dart';

/// Animates between numeric values with a count-up/-down roll.
///
/// ```dart
/// AnimatedCount(value: 68, suffix: '%', style: ...)
/// AnimatedCount(value: 2.4, decimals: 1, suffix: ' MB', style: ...)
/// ```
class AnimatedCount extends ImplicitlyAnimatedWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.textAlign,
    super.duration = Motion.slow,
    super.curve = Motion.easeOut,
  });

  /// Target value; changing it rolls the display from the previous value.
  final double value;

  /// Fraction digits to render.
  final int decimals;

  final String prefix;
  final String suffix;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  AnimatedWidgetBaseState<AnimatedCount> createState() =>
      _AnimatedCountState();
}

class _AnimatedCountState extends AnimatedWidgetBaseState<AnimatedCount> {
  Tween<double>? _tween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _tween = visitor(
      _tween,
      widget.value,
      (v) => Tween<double>(begin: v as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final v = _tween?.evaluate(animation) ?? widget.value;
    return Text(
      '${widget.prefix}${v.toStringAsFixed(widget.decimals)}${widget.suffix}',
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
