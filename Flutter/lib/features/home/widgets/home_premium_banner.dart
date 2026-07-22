import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/category_colors.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/farvixo_logo.dart';

/// "Upgrade to Farvixo Pro" banner — pulsing crown logo, gold-gradient title,
/// gradient CTA and floating feature icons. Hidden for Pro users.
class HomePremiumBanner extends StatelessWidget {
  const HomePremiumBanner({
    super.key,
    required this.pulse,
    required this.isDark,
  });

  final AnimationController pulse;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final titleColor = isDark ? AppColors.textPrimary : p.textPrimary;
    final bodyColor = isDark ? AppColors.lavender300 : p.textSecondary;
    final gold = CategoryColors.premium.accentOf(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: Radii.brBanner,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? AppColors.premiumBannerDark
              : AppColors.premiumBannerLight,
        ),
        border: Border.all(color: gold.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: pulse,
              builder: (context, child) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(
                        alpha: .25 + pulse.value * .25,
                      ),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: child,
              ),
              child: const FarvixoLogo(size: 58),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Upgrade to ',
                          style: AppTypography.titleMedium(
                            context,
                            color: titleColor,
                            weight: FontWeights.extrabold,
                          ),
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.goldPinkGradient.createShader(b),
                        child: Text(
                          'Farvixo Pro 👑',
                          style: AppTypography.titleMedium(
                            context,
                            color: AppColors.onAccent,
                            weight: FontWeights.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Unlock all premium tools, remove limits, ads free experience & much more!',
                    style: AppTypography.labelSmall(
                      context,
                      color: bodyColor,
                      weight: FontWeights.regular,
                    ).copyWith(height: 1.4),
                  ),
                  const SizedBox(height: Space.s10),
                  InkWell(
                    borderRadius: Radii.brPill,
                    onTap: () => context.push('/profile'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.s20,
                        vertical: Space.s10,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: Radii.brPill,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.brandMagenta.withValues(alpha: .5),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Text(
                        'Upgrade Now',
                        style: AppTypography.bodySmall(
                          context,
                          color: AppColors.onAccent,
                          weight: FontWeights.extrabold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            // floating hex feature icons
            AnimatedBuilder(
              animation: pulse,
              builder: (context, _) => Column(
                children: [
                  Transform.translate(
                    offset: Offset(0, pulse.value * -3),
                    child: _HexIcon(icon: Icons.bolt_rounded, isDark: isDark),
                  ),
                  const SizedBox(height: 6),
                  Transform.translate(
                    offset: Offset(0, pulse.value * 3),
                    child:
                        _HexIcon(icon: Icons.shield_outlined, isDark: isDark),
                  ),
                  const SizedBox(height: 6),
                  Transform.translate(
                    offset: Offset(0, pulse.value * -2),
                    child: _HexIcon(
                      icon: Icons.all_inclusive_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HexIcon extends StatelessWidget {
  const _HexIcon({required this.icon, required this.isDark});

  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final brand = CategoryColors.brand;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: Radii.brSm,
        border: Border.all(
          color: brand.accentOf(context).withValues(alpha: isDark ? .55 : .4),
        ),
        color: brand.tint(context),
      ),
      child: Icon(
        icon,
        size: 16,
        color: isDark ? AppColors.lavender200 : brand.accentOf(context),
      ),
    );
  }
}
