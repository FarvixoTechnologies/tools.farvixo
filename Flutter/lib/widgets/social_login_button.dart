import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';

/// Social login card (doc: UI Guidelines — Social Login Cards).
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(
          color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
        ),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 24, height: 24, child: Center(child: leading)),
                const SizedBox(width: Gap.icon),
                Text(
                  label,
                  style: AppTypography.bodyLarge(
                    context,
                    weight: FontWeights.semibold,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Simple "G" mark used until official brand assets are added.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'G',
      style: AppTypography.titleLarge(
        context,
        color: AppColors.socialGoogleBlue,
        weight: FontWeights.extrabold,
      ),
    );
  }
}
