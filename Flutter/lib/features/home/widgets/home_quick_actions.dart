import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/category_colors.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium_kit.dart';

/// Quick-action shortcut definition for the Home dashboard row.
///
/// Actions carry a [CategoryIdentity] rather than a flat colour. Tool-bound
/// actions reuse their tool's category identity (so QR Scanner reads the same
/// here as in the tools grid); app-level actions use a brand component
/// identity. Both are brightness-aware.
class QuickAction {
  const QuickAction(
    this.icon,
    this.title,
    this.subtitle,
    this.identity,
    this.route,
  );

  final IconData icon;
  final String title;
  final String subtitle;
  final CategoryIdentity identity;
  final String route;
}

/// Curated quick actions — first four render on the Home row.
const quickActions = [
  QuickAction(
    Icons.smart_toy_outlined,
    'AI Assistant',
    'Smart Help',
    CategoryColors.ai,
    '/ai',
  ),
  QuickAction(
    Icons.folder_open_rounded,
    'Recent Files',
    'View History',
    CategoryColors.brand,
    '/downloads',
  ),
  QuickAction(
    Icons.favorite_outline_rounded,
    'Favorites',
    'Your Collection',
    CategoryColors.favorite,
    '/favorites',
  ),
  QuickAction(
    Icons.qr_code_scanner_rounded,
    'QR Scanner',
    'Scan Any Code',
    CategoryColors.utility,
    '/tool/qr-scanner',
  ),
  QuickAction(
    Icons.download_outlined,
    'Downloads',
    'Saved Files',
    CategoryColors.cloud,
    '/downloads',
  ),
  QuickAction(
    Icons.grid_view_rounded,
    'All Tools',
    '140+ Tools',
    CategoryColors.premium,
    '/tools',
  ),
];

/// One compact quick-action card (icon tile + title + subtitle).
class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.action,
    required this.palette,
  });

  final QuickAction action;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () =>
          action.route.startsWith('/tool/') ||
              action.route == '/downloads' ||
              action.route == '/notifications'
          ? context.push(action.route)
          : context.go(action.route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        decoration: BoxDecoration(
          color: palette.surfaceGlass,
          borderRadius: Radii.brTile,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            GlowIcon(
              icon: action.icon,
              color: action.identity.accentOf(context),
              size: 30,
              iconSize: 16,
              radius: 9,
              glowAlpha: .25,
              glowBlur: 8,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // scaleDown keeps the whole label visible on narrow cards
                  // instead of clipping to "AI As…".
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        action.title,
                        maxLines: 1,
                        style: AppTypography.caption(
                          context,
                          color: palette.textPrimary,
                          weight: FontWeights.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        action.subtitle,
                        maxLines: 1,
                        style: AppTypography.badge(
                          context,
                          color: palette.textMuted,
                          weight: FontWeights.regular,
                        ),
                      ),
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
