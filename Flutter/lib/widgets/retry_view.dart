import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';

/// Reusable full-area error state with a Retry action. Used wherever an
/// [AsyncValue.error] would otherwise leave the screen blank.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.onRetry,
    this.title = 'Something went wrong',
    this.message = 'We couldn\'t load this right now.',
    this.icon = Icons.error_outline_rounded,
    this.offline = false,
  });

  /// Convenience for the offline variant (friendly copy + wifi icon).
  const ErrorRetryView.offline({super.key, required this.onRetry})
      : title = 'Offline mode',
        message = 'You\'re offline — showing saved tools. '
            'Pull to refresh when you\'re back online.',
        icon = Icons.wifi_off_rounded,
        offline = true;

  final VoidCallback onRetry;
  final String title;
  final String message;
  final IconData icon;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s32,
          vertical: Space.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: p.textMuted),
            const SizedBox(height: Space.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium(
                context,
                color: p.textPrimary,
                weight: FontWeights.extrabold,
              ),
            ),
            const SizedBox(height: Space.s6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(
                context,
                color: p.textSecondary,
              ).copyWith(height: 1.35),
            ),
            const SizedBox(height: Space.s20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: AppColors.onAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s20,
                  vertical: Space.s12,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: Radii.brButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim inline "Offline mode" pill shown above content that is being served
/// from the bundled catalog. Tapping it retries.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Offline is a warning state, not an Audio-category surface — this used to
    // borrow `accentAudio` purely because it was orange.
    const warn = AppColors.warning;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.s16,
        Space.s8,
        Space.s16,
        Space.s0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: Radii.brPill,
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s12,
              vertical: Space.s8,
            ),
            decoration: BoxDecoration(
              color: warn.withValues(alpha: 0.12),
              borderRadius: Radii.brPill,
              border: Border.all(color: warn.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 14, color: warn),
                const SizedBox(width: Space.s6),
                Text(
                  'Offline mode',
                  style: AppTypography.labelSmall(
                    context,
                    color: p.textPrimary,
                    weight: FontWeights.bold,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: Space.s6),
                  Text(
                    '· Retry',
                    style: AppTypography.labelSmall(
                      context,
                      color: warn,
                      weight: FontWeights.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
