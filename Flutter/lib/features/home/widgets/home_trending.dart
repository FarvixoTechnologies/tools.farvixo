import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/tool_activity_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/category_colors.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium_kit.dart';

/// Trending badge state — carries its own semantic colour so no call site
/// picks one.
enum TrendingBadge {
  none(''),
  isNew('New'),
  hot('🔥 Hot');

  const TrendingBadge(this.label);

  final String label;

  bool get visible => this != TrendingBadge.none;

  /// Status colour for this badge. `New` reads as success, `Hot` as urgent.
  /// [TrendingBadge.none] is never rendered — see [visible].
  Color color(BuildContext context) => switch (this) {
        TrendingBadge.none => Colors.transparent,
        TrendingBadge.isNew => AppColors.success,
        TrendingBadge.hot => AppColors.error,
      };
}

/// Curated trending tool — copy, rating, badge and route from the approved
/// design.
///
/// Colour resolves from [categoryId] (mirroring `tools_data.dart`), so a tool
/// carries one identity everywhere it appears.
class TrendingItem {
  const TrendingItem({
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.icon,
    required this.categoryId,
    required this.badge,
    required this.route,
    this.toolId,
  });

  final String title;
  final String subtitle;
  final double rating;
  final IconData icon;

  /// Slug into [CategoryColors] — matches the catalog entry for [toolId].
  final String categoryId;

  final TrendingBadge badge;
  final String route;
  final String? toolId;

  /// The tool's colour identity, inherited from its category.
  CategoryIdentity get identity => CategoryColors.of(categoryId);
}

const trendingItems = [
  TrendingItem(
    title: 'QR Scanner',
    subtitle: 'Scan QR Codes from Photos',
    rating: 4.9,
    icon: Icons.qr_code_scanner_rounded,
    categoryId: 'utility',
    badge: TrendingBadge.isNew,
    route: '/tool/qr-scanner',
    toolId: 'qr-scanner',
  ),
  TrendingItem(
    title: 'PDF Converter',
    subtitle: 'Convert PDF to Word, Excel, PPT',
    rating: 4.8,
    icon: Icons.picture_as_pdf_rounded,
    categoryId: 'pdf',
    badge: TrendingBadge.hot,
    route: '/tool/pdf-converter',
    toolId: 'pdf-converter',
  ),
  TrendingItem(
    title: 'Image to PDF',
    subtitle: 'Convert Images to PDF',
    rating: 4.7,
    icon: Icons.image_rounded,
    categoryId: 'image',
    badge: TrendingBadge.isNew,
    route: '/tool/image-converter',
    toolId: 'image-converter',
  ),
  TrendingItem(
    title: 'AI Image Generator',
    subtitle: 'Create AI Images from Text',
    rating: 4.9,
    icon: Icons.auto_awesome_rounded,
    categoryId: 'ai',
    badge: TrendingBadge.hot,
    route: '/tools?category=ai',
  ),
  TrendingItem(
    title: 'OCR Image',
    subtitle: 'Extract Text from Image',
    rating: 4.8,
    icon: Icons.document_scanner_rounded,
    categoryId: 'image',
    badge: TrendingBadge.isNew,
    route: '/tool/image-ocr',
    toolId: 'image-ocr',
  ),
  TrendingItem(
    title: 'Video Converter',
    subtitle: 'Convert Video to MP4, AVI, MOV',
    rating: 4.7,
    icon: Icons.movie_rounded,
    categoryId: 'video',
    badge: TrendingBadge.none,
    route: '/tool/video-converter',
    toolId: 'video-converter',
  ),
];

/// Trending tool card — badge, glowing icon, rating.
class TrendingCard extends ConsumerWidget {
  const TrendingCard({
    super.key,
    required this.item,
    required this.palette,
    required this.width,
  });

  final TrendingItem item;
  final AppPalette palette;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = item.identity.accentOf(context);
    final badgeColor = item.badge.color(context);
    final premium = CategoryColors.premium.accentOf(context);

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
        width: width,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s8,
          vertical: Space.s10,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceGlass,
          borderRadius: Radii.brCard,
          border: Border.all(
            color: item.identity.border(context),
            width: 1.1,
          ),
          boxShadow: item.identity.cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: 18,
              child: !item.badge.visible
                  ? null
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s6,
                          vertical: Space.s2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: .16),
                          borderRadius: Radii.brPill,
                          border: Border.all(
                            color: badgeColor.withValues(alpha: .45),
                          ),
                        ),
                        child: Text(
                          item.badge.label,
                          style: AppTypography.overline(
                            context,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: Space.s6),
            GlowIcon(
              icon: item.icon,
              color: accent,
              size: 44,
              iconSize: 22,
              radius: 12,
              glowAlpha: .35,
            ),
            const SizedBox(height: Insets.sm),
            Text(
              item.title,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall(
                context,
                color: palette.textPrimary,
                weight: FontWeights.bold,
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                item.subtitle,
                maxLines: 3,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(
                  context,
                  color: palette.textMuted,
                ),
              ),
            ),
            const SizedBox(height: Insets.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, size: 13, color: premium),
                const SizedBox(width: 3),
                Text(
                  item.rating.toStringAsFixed(1),
                  style: AppTypography.numeric(
                    context,
                    color: premium,
                    weight: FontWeights.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
