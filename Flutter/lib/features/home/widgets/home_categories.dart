import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/category_colors.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium_kit.dart';

/// Curated home category — labels, counts, icons and route from the approved
/// design (kept local so the shared tool catalog is untouched).
///
/// Colour is **not** stored here: it resolves from [categoryId] through
/// [CategoryColors], so a category reads identically on Home, the tools grid,
/// search results and its detail workspace, in both light and dark themes.
class HomeCategory {
  const HomeCategory(
    this.label,
    this.count,
    this.icon,
    this.categoryId,
    this.route,
  );

  final String label;
  final int count;
  final IconData icon;

  /// Slug into [CategoryColors] — the single source of this category's colour.
  final String categoryId;

  final String route;

  /// The category's colour identity.
  CategoryIdentity get identity => CategoryColors.of(categoryId);
}

/// Mobile home preview — exactly 4 category cards in one row.
const homeCategoryPreviewCount = 4;

const homeCategories = [
  HomeCategory(
    'PDF & Document',
    16,
    Icons.picture_as_pdf_rounded,
    'pdf',
    '/tools?category=pdf',
  ),
  HomeCategory(
    'Image & Photo',
    19,
    Icons.image_rounded,
    'image',
    '/tools?category=image',
  ),
  HomeCategory(
    'Video Tools',
    14,
    Icons.play_circle_rounded,
    'video',
    '/tools?category=video',
  ),
  HomeCategory(
    'AI Tools',
    20,
    Icons.smart_toy_rounded,
    'ai',
    '/tools?category=ai',
  ),
];

/// Category preview card (glowing icon tile + label + tool count).
class HomeCategoryCard extends StatelessWidget {
  const HomeCategoryCard({
    super.key,
    required this.category,
    required this.palette,
    this.highlighted = false,
  });

  final HomeCategory category;
  final AppPalette palette;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final accent = category.identity.accentOf(context);

    return PressableScale(
      onTap: () => context.go(category.route),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s6,
          vertical: Space.s10,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceGlass,
          borderRadius: Radii.brCard,
          border: Border.all(
            color: highlighted
                ? category.identity.border(context)
                : palette.border,
            width: highlighted ? 1.3 : 1,
          ),
          boxShadow:
              highlighted ? category.identity.cardShadow(context) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlowIcon(
              icon: category.icon,
              color: accent,
              size: 38,
              iconSize: 20,
              radius: 11,
              glowBlur: 10,
            ),
            const SizedBox(height: Insets.sm),
            Text(
              category.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall(
                context,
                color: palette.textPrimary,
                weight: FontWeights.bold,
              ),
            ),
            const SizedBox(height: Insets.xxs),
            Text(
              '${category.count} Tools',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(context, color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
