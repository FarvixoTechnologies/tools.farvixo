import 'package:flutter/material.dart';

import '../../../../theme/app_palette.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../widgets/premium/premium.dart';
import '../../../../widgets/premium_kit.dart';
import '../../engine/engines/engine_util.dart';
import '../models/conversion_result.dart';
import '../models/target_format.dart';

class ConvertProgressCard extends StatelessWidget {
  const ConvertProgressCard({
    super.key,
    required this.fraction,
    required this.stage,
    required this.onCancel,
    this.accentColor,
  });

  final double? fraction;
  final String? stage;
  final VoidCallback onCancel;

  /// Overrides the theme accent (e.g. the tool's own identity color).
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final accent = accentColor ?? p.accent;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (fraction != null)
            PremiumProgressRing(
              progress: fraction!,
              size: 104,
              color: accent,
            )
          else
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                color: accent,
              ),
            ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: Motion.base,
            child: Text(
              stage ?? 'Working…',
              key: ValueKey(stage),
              style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.bold),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class ConversionResultCard extends StatelessWidget {
  const ConversionResultCard({
    super.key,
    required this.result,
    required this.onDownload,
    required this.onShare,
    required this.onAnother,
    required this.onChangeFormat,
  });

  final ConversionResult result;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onAnother;
  final VoidCallback onChangeFormat;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final f = result.format;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            index: 0,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: Radii.brTile,
                    color: f.accentOf(context).withValues(alpha: 0.15),
                    boxShadow: Elevations.accentGlow(f.accentOf(context)),
                  ),
                  child: Icon(f.icon, color: f.accentOf(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.fileName,
                        style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                      ),
                      Text(
                        '${formatBytes(result.outputSize)} · ${result.confidence}% · ${result.durationMs} ms',
                        style: AppTypography.labelMedium(context, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (result.previewBytes != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: Radii.brTile,
              child: Image.memory(
                result.previewBytes!,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
          ] else if (result.previewText != null) ...[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: Radii.brTile,
              ),
              child: SingleChildScrollView(
                child: Text(
                  result.previewText!,
                  style: AppTypography.bodySmall(context, color: p.textSecondary),
                ),
              ),
            ),
          ],
          if (result.summary != null) ...[
            const SizedBox(height: 10),
            Text(result.summary!, style: AppTypography.bodyLarge(context, color: p.textSecondary)),
          ],
          const SizedBox(height: 16),
          FadeSlideIn(
            index: 1,
            child: FilledButton.icon(
              onPressed: () {
                AppHaptics.tap();
                onDownload();
              },
              icon: const Icon(Icons.download_rounded),
              label: Text('Download ${f.label}'),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 2,
            child: OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share'),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 3,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onChangeFormat,
                    child: const Text('Change format'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: onAnother,
                    child: const Text('Convert another'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
