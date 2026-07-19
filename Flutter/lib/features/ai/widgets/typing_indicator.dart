import 'package:flutter/material.dart';

import '../../../theme/app_palette.dart';

/// Three-dot "AI is thinking" indicator with a soft staggered bounce.
/// Collapses to a static row of dots when reduce-motion is enabled.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) == true;
    return SizedBox(
      height: 14,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  _Dot(
                    color: p.accent,
                    t: reduceMotion ? 0.5 : _phase(_c.value, i),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  double _phase(double v, int i) {
    final shifted = (v + i * 0.18) % 1.0;
    // Smooth up-down curve in [0,1].
    return shifted < 0.5 ? shifted * 2 : (1 - shifted) * 2;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.t});
  final Color color;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -3 * t),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.45 + 0.55 * t),
        ),
      ),
    );
  }
}
