import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Reusable loading-placeholder primitives that mirror the real card
/// dimensions so switching from skeleton → content causes no layout shift.
///
/// A subtle looping opacity pulse stands in for shimmer (no extra dependency).
class AppSkeletonCard extends StatefulWidget {
  const AppSkeletonCard({
    super.key,
    this.width,
    this.height,
    this.radius = 16,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  State<AppSkeletonCard> createState() => _AppSkeletonCardState();
}

class _AppSkeletonCardState extends State<AppSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_c),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: p.surface2.withValues(alpha: p.isDark ? 0.6 : 0.9),
            borderRadius: BorderRadius.circular(widget.radius),
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
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: p.isDark ? 0.72 : 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(36, 36),
            const SizedBox(height: 12),
            bar(double.infinity, 11),
            const SizedBox(height: 6),
            bar(90, 9),
            const Spacer(),
            bar(48, 14),
          ],
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
