import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_palette.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../widgets/premium_kit.dart';
import '../models/document_structure.dart';
import '../models/target_format.dart';

class AnalysisReview extends StatelessWidget {
  const AnalysisReview({
    super.key,
    required this.structure,
    this.thumbnail,
    required this.onContinue,
    required this.onUseRecommendation,
    this.onOpenOcr,
  });

  final DocumentStructure structure;
  final ImageProvider? thumbnail;
  final VoidCallback onContinue;
  final VoidCallback onUseRecommendation;
  final VoidCallback? onOpenOcr;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final rec = structure.recommendation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (thumbnail != null) ...[
          ClipRRect(
            borderRadius: Radii.brPanel,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image(image: thumbnail!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(context, p, Icons.layers_rounded, '${structure.pageCount} pages'),
            _chip(context, p, Icons.notes_rounded, '${structure.totalWords} words'),
            _chip(context, p, Icons.table_chart_rounded, '${structure.tableCount} tables'),
            _chip(context, p, Icons.image_rounded, '${structure.imageCount} images'),
            _chip(context, p, Icons.category_rounded, structure.documentType.name),
            _chip(context, p, Icons.translate_rounded, structure.scriptHint.name),
            if (structure.isScanned)
              _chip(context, p, Icons.document_scanner_rounded, 'Scanned', warn: true),
          ],
        ),
        if (structure.isScanned) ...[
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded,
                        color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Scanned PDF detected. Run PDF OCR for editable text, or export as Image.',
                        style:
                            AppTypography.bodySmall(context, color: p.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (onOpenOcr != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onOpenOcr,
                    icon: const Icon(Icons.document_scanner_rounded),
                    label: const Text('Open PDF OCR'),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        PressableScale(
          onTap: onUseRecommendation,
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                GlowIcon(
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended: ${rec.format.label}',
                        style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rec.reason,
                        style: AppTypography.bodySmall(context, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConfidenceBanner(overall: structure.overallConfidence),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: onContinue,
            child: const Text('Choose format'),
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, AppPalette p, IconData icon, String label,
      {bool warn = false}) {
    final color = warn ? AppColors.warning : p.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: Radii.brPill,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelMedium(context, color: p.textPrimary, weight: FontWeights.semibold),
          ),
        ],
      ),
    );
  }
}

class ConfidenceBanner extends StatelessWidget {
  const ConfidenceBanner({
    super.key,
    required this.overall,
    this.breakdown,
  });

  final int overall;
  final ConfidenceBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = overall >= 80
        ? AppColors.success
        : overall >= 50
            ? AppColors.warning
            : AppColors.error;
    return Semantics(
      label: 'Conversion confidence $overall percent',
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_rounded, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$overall% confidence',
                  style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                ),
              ],
            ),
            if (breakdown != null && breakdown!.issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final issue in breakdown!.issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $issue',
                    style: AppTypography.labelMedium(context, color: p.textSecondary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
