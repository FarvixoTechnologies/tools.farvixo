import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/design_tokens.dart';

/// Reusable loading-placeholder primitives that mirror the real card
/// dimensions so switching from skeleton → content causes no layout shift.
///
/// A smooth, token-driven gradient shimmer sweeps across placeholders (no extra
/// dependency). The sweep is disabled under reduce-motion, falling back to a
/// static tinted block so the layout is identical either way.

/// Wraps [child] with an animated left→right sheen. Any opaque shape used as a
/// placeholder can be wrapped to get a consistent shimmer.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.shimmer,
  );

  bool _repeating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (reduceMotion) {
      _c.stop();
      _c.value = 0;
      _repeating = false;
    } else if (!_repeating) {
      _repeating = true;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (reduceMotion) return widget.child;

    final base = Colors.transparent;
    // The shimmer sweep is a light wash in both themes — only its opacity
    // changes, so it reads on dark surfaces without blowing out light ones.
    final highlight =
        AppColors.onAccent.withValues(alpha: p.isDark ? 0.06 : 0.55);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = _c.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final dx = bounds.width * (t * 2 - 1);
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [base, highlight, base],
                stops: const [0.35, 0.5, 0.65],
                transform: _SlideGradient(dx),
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}

/// Horizontally slides a gradient by [dx] logical pixels.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// A single shimmering block used as a placeholder for a card or bar.
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({
    super.key,
    this.width,
    this.height,
    this.radius = Radii.card,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ExcludeSemantics(
      child: Shimmer(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: p.surface2.withValues(alpha: p.isDark ? 0.6 : 0.9),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: p.border),
          ),
        ),
      ),
    );
  }
}

/// Placeholder matching a [ToolCard] (icon tile + two text lines + footer).
class ToolCardSkeleton extends StatelessWidget {
  const ToolCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: p.surface2.withValues(alpha: p.isDark ? 0.7 : 0.95),
            borderRadius: Radii.brXs,
          ),
        );
    return ExcludeSemantics(
      child: Shimmer(
        child: Container(
          padding: const EdgeInsets.all(Insets.sm + 4),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: p.isDark ? 0.72 : 0.95),
            borderRadius: Radii.brPanel,
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(36, 36),
              Gaps.h12,
              bar(double.infinity, 11),
              const SizedBox(height: Insets.sm - 2),
              bar(90, 9),
              const Spacer(),
              bar(48, 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of category placeholders (matches the home explore row).
class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key, this.count = 4, this.height = 112});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            const Expanded(child: AppSkeletonCard()),
          ],
        ],
      ),
    );
  }
}

/// A grid of [ToolCardSkeleton]s for a loading section body.
class SectionSkeleton extends StatelessWidget {
  const SectionSkeleton({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.35,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => const ToolCardSkeleton(),
    );
  }
}
