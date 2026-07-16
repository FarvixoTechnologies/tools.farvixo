import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Farvixo brand mark — single final logo for dark & light.
class FarvixoLogo extends StatelessWidget {
  const FarvixoLogo({
    super.key,
    this.size = 48,
    this.showWordmark = false,
    this.glow = true,
  });

  final double size;
  final bool showWordmark;
  final bool glow;

  static const asset = 'assets/logo/farvixo_logo.png';

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: glow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldPremium.withValues(alpha: 0.4),
                  blurRadius: size * 0.4,
                  spreadRadius: size * 0.015,
                ),
                BoxShadow(
                  color: const Color(0xFFFDE68A).withValues(alpha: 0.18),
                  blurRadius: size * 0.25,
                ),
              ],
            )
          : null,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) =>
            _FallbackMark(size: size),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Farvixo',
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'BUILD BEYOND.',
              style: TextStyle(
                fontSize: size * 0.18,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.goldPremium.withValues(alpha: 0.85),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'F',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.48,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
