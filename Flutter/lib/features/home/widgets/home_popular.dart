import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/tool_activity_provider.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/category_colors.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium_kit.dart';

/// Curated popular tool — titles, subtitles, icons and route from the approved
/// design (two-column list).
///
/// Colour resolves from [categoryId], which mirrors the tool's `categoryId` in
/// `tools_data.dart`. A tool therefore carries the same colour on Home, in the
/// tools grid, in search results and in its detail workspace.
class PopularItem {
  const PopularItem(
    this.title,
    this.subtitle,
    this.icon,
    this.categoryId,
    this.route, [
    this.toolId,
  ]);

  final String title;
  final String subtitle;
  final IconData icon;

  /// Slug into [CategoryColors] — matches the catalog entry for [toolId].
  final String categoryId;

  final String route;
  final String? toolId;

  /// The tool's colour identity, inherited from its category.
  CategoryIdentity get identity => CategoryColors.of(categoryId);
}

const popularItems = [
  PopularItem(
    'Background Remover',
    'Remove Background',
    Icons.auto_fix_high_rounded,
    'image',
    '/tool/background-remover',
    'background-remover',
  ),
  PopularItem(
    'PDF to Word',
    'Convert PDF to Word',
    Icons.description_rounded,
    'pdf',
    '/tool/pdf-to-word',
    'pdf-to-word',
  ),
  PopularItem(
    'QR Code Generator',
    'Create QR Codes Instantly',
    Icons.qr_code_rounded,
    'utility',
    '/tool/qr-generator',
    'qr-generator',
  ),
  PopularItem(
    'Compress PDF',
    'Reduce PDF File Size',
    Icons.compress_rounded,
    'pdf',
    '/tool/compress-pdf',
    'compress-pdf',
  ),
  PopularItem(
    'Word Counter',
    'Count Words & Characters',
    Icons.format_list_numbered_rounded,
    'text',
    '/tool/word-counter',
    'word-counter',
  ),
  PopularItem(
    'Image Resizer',
    'Resize Image in Any Size',
    Icons.aspect_ratio_rounded,
    'image',
    '/tool/image-resizer',
    'image-resizer',
  ),
  PopularItem(
    'Merge PDF',
    'Merge Multiple PDF Files',
    Icons.merge_rounded,
    'pdf',
    '/tool/merge-pdf',
    'merge-pdf',
  ),
  PopularItem(
    'AI Chat Assistant',
    'Ask Anything, Get Answers',
    Icons.chat_bubble_rounded,
    'ai',
    '/ai',
    'ai-chat',
  ),
];

/// Popular tool row (flat icon tile + title + subtitle + chevron).
class PopularToolRow extends ConsumerWidget {
  const PopularToolRow({super.key, required this.item, required this.palette});

  final PopularItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PressableScale(
      onTap: () {
        if (item.toolId != null) {
          ref.read(recentToolsProvider.notifier).recordUse(item.toolId!);
        }
        item.route.startsWith('/tool/')
            ? context.push(item.route)
            : context.go(item.route);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s10),
        decoration: BoxDecoration(
          color: palette.surfaceGlass,
          borderRadius: Radii.brTile,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            GlowIcon(
              icon: item.icon,
              color: item.identity.accentOf(context),
              size: 36,
              iconSize: 18,
              radius: 10,
              glow: false,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium(
                      context,
                      color: palette.textPrimary,
                      weight: FontWeights.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(
                      context,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
