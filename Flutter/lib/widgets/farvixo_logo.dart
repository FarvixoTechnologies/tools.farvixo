import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';

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
                  color: AppColors.goldSoft.withValues(alpha: 0.18),
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
        const SizedBox(width: Gap.item),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lockup type scales with the mark, so the size is proportional
            // rather than a fixed role — weight and family still come from
            // the type scale.
            Text(
              'Farvixo',
              style: AppTypography.wordmarkStyle.copyWith(
                fontSize: size * 0.42,
                letterSpacing: 0,
                fontWeight: FontWeights.extrabold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'BUILD BEYOND.',
              style: AppTypography.overlineStyle.copyWith(
                fontSize: size * 0.18,
                letterSpacing: 2,
                fontWeight: FontWeights.semibold,
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
        style: AppTypography.wordmarkStyle.copyWith(
          color: AppColors.onAccent,
          fontSize: size * 0.48,
          letterSpacing: 0,
          fontWeight: FontWeights.black,
        ),
      ),
    );
  }
}
