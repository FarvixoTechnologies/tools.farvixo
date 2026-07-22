import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../theme/app_palette.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../widgets/premium_kit.dart';
import '../../engine/engines/engine_util.dart';
import '../models/conversion_result.dart';
import '../models/target_format.dart';

class CompareResultsPanel extends StatelessWidget {
  const CompareResultsPanel({
    super.key,
    required this.results,
    required this.onShare,
    required this.onDiff,
    required this.onBack,
  });

  final List<ConversionResult> results;
  final void Function(ConversionResult) onShare;
  final VoidCallback onDiff;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Compare (${results.length})',
          style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
        ),
        const SizedBox(height: 12),
        for (final r in results) ...[
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: Radii.brTile,
                    color: r.format.accentOf(context).withValues(alpha: 0.15),
                  ),
                  child: Icon(r.format.icon, color: r.format.accentOf(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.format.label,
                        style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                      ),
                      Text(
                        '${formatBytes(r.outputSize)} · ${r.confidence}%',
                        style: AppTypography.labelMedium(context, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => onShare(r),
                  icon: const Icon(Icons.share_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onDiff,
          icon: const Icon(Icons.compare_rounded),
          label: const Text('Open Diff view'),
        ),
        TextButton(onPressed: onBack, child: const Text('Change formats')),
      ],
    );
  }
}

class DiffViewPanel extends StatelessWidget {
  const DiffViewPanel({
    super.key,
    required this.originalThumb,
    required this.result,
    required this.onBack,
  });

  final Uint8List? originalThumb;
  final ConversionResult result;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Diff · Original vs ${result.format.label}',
          style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _pane(
                context,
                p,
                label: 'Original',
                child: originalThumb != null
                    ? Image.memory(originalThumb!, fit: BoxFit.contain)
                    : Icon(Icons.picture_as_pdf_rounded,
                        size: 48, color: p.textMuted),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _pane(
                context,
                p,
                label: 'Converted',
                child: result.previewBytes != null
                    ? Image.memory(result.previewBytes!, fit: BoxFit.contain)
                    : result.previewText != null
                        ? SingleChildScrollView(
                            child: Text(
                              result.previewText!,
                              style: AppTypography.labelSmall(context, color: p.textSecondary),
                            ),
                          )
                        : Icon(result.format.icon,
                            size: 48, color: result.format.accentOf(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${result.confidence}% confidence · ${formatBytes(result.originalSize)} → ${formatBytes(result.outputSize)} · ${result.durationMs} ms',
            style: AppTypography.bodySmall(context, color: p.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }

  Widget _pane(
    BuildContext context,
    AppPalette p, {
    required String label,
    required Widget child,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.labelMedium(context, color: p.textMuted, weight: FontWeights.bold),
        ),
        const SizedBox(height: 6),
        Container(
          height: 200,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: Radii.brTile,
            border: Border.all(color: p.border),
            color: p.surface2,
          ),
          child: Center(child: child),
        ),
      ],
    );
  }
}
