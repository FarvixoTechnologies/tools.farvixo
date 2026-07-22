import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';

/// Violet→magenta gradient CTA used across splash/onboarding mockups.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 54,
    this.width,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double? width;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: Radii.brCard,
        child: Ink(
          width: width ?? double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.ctaGradient : null,
            color: enabled ? null : p.surface2,
            borderRadius: Radii.brCard,
            boxShadow:
                enabled ? Elevations.accentGlow(AppColors.brandPrimary) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.onAccent, size: 20),
                const SizedBox(width: Gap.icon),
              ],
              Text(
                label,
                style: AppTypography.bodyLarge(
                  context,
                  color: enabled ? AppColors.onAccent : p.textMuted,
                  weight: FontWeights.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
