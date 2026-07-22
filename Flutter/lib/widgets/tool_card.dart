import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/tool_model.dart';
import '../providers/auth_provider.dart';
import '../providers/tool_activity_provider.dart';
import '../providers/tool_repository_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../theme/category_colors.dart';
import '../theme/design_tokens.dart';
import 'animations.dart';

/// Compact glass tool card — 3-col mobile grid (TOOLS_PAGE.md 2026).
class ToolCard extends ConsumerWidget {
  const ToolCard({
    super.key,
    required this.tool,
    this.compact = true,
  });

  final Tool tool;
  final bool compact;

  void _open(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    ref.read(recentToolsProvider.notifier).recordUse(tool.id);
    context.push('/tool/${tool.id}');
  }

  /// Optimistic local toggle + backend Favorites API write. Rolls back the
  /// optimistic change (and notifies) if the signed-in write is rejected.
  /// Offline / guest favorites stay local — nothing to roll back.
  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(favoriteToolsProvider.notifier);
    final willFavorite = !ref.read(favoriteToolsProvider).contains(tool.id);

    notifier.toggle(tool.id); // optimistic

    final user = ref.read(authProvider);
    final signedIn = user != null && !user.isGuest;
    if (!signedIn) return; // local-only favorite

    final ok = await ref
        .read(toolRepositoryProvider)
        .setFavorite(tool.remoteSlug, favorite: willFavorite);

    if (ok) {
      ref.invalidate(remoteFavoritesProvider);
    } else {
      notifier.toggle(tool.id); // rollback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't update favorite. Please try again."),
            behavior: SnackBarBehavior.floating,
            duration: Motion.snackbar,
          ),
        );
      }
    }
  }

  Future<void> _longPressMenu(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final isFavorite = ref.read(favoriteToolsProvider).contains(tool.id);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final p = AppPalette.of(ctx);
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: Radii.brPanel,
            border: Border.all(color: p.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: Radii.brPill,
                ),
              ),
              ListTile(
                leading: Icon(Icons.open_in_new_rounded, color: p.accent),
                title: const Text('Open tool'),
                onTap: () => Navigator.pop(ctx, 'open'),
              ),
              ListTile(
                leading: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: AppColors.brandMagenta,
                ),
                title: Text(isFavorite ? 'Remove favorite' : 'Add favorite'),
                onTap: () => Navigator.pop(ctx, 'favorite'),
              ),
              ListTile(
                leading: Icon(Icons.share_rounded, color: p.textSecondary),
                title: const Text('Share'),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
              ListTile(
                leading: Icon(Icons.link_rounded, color: p.textSecondary),
                title: const Text('Copy link'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return;
    switch (action) {
      case 'open':
        _open(context, ref);
      case 'favorite':
        unawaited(_toggleFavorite(context, ref));
      case 'share':
      case 'copy':
        await Clipboard.setData(
          ClipboardData(text: 'https://tools.farvixo.com/tools/${tool.id}'),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied'),
              behavior: SnackBarBehavior.floating,
              duration: Motion.snackbar,
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryResolverProvider)(tool.categoryId);
    final p = AppPalette.of(context);
    // Per-category identity: brightness-aware accent, gradient, tint and glow
    // so every category reads as a distinct visual family in both themes.
    final id = CategoryColors.of(tool.categoryId);
    final accent = id.accentOf(context);
    // select() so a card rebuilds only when ITS own favorite bit flips, not on
    // every favorites-list change.
    final isFavorite = ref.watch(
      favoriteToolsProvider.select((f) => f.contains(tool.id)),
    );
    final shortCat = category.name.replaceAll(' Tools', '');

    return RepaintBoundary(
      child: PressableScale(
        // _open already fires a selection haptic; keep exactly one.
        haptic: false,
        onTap: () => _open(context, ref),
        onLongPress: () => _longPressMenu(context, ref),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: p.isDark ? 0.72 : 0.95),
            borderRadius: Radii.brPanel,
            border: Border.all(
              color: Color.lerp(
                p.border.withValues(alpha: p.isDark ? 0.9 : 1),
                id.border(context),
                0.55,
              )!,
            ),
            boxShadow: id.cardShadow(context),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? Insets.sm + 4 : Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 36 : 40,
                      height: compact ? 36 : 40,
                      decoration: BoxDecoration(
                        gradient: id.surfaceGradient(context),
                        borderRadius: Radii.brButton,
                        border: Border.all(color: id.border(context)),
                      ),
                      child: Icon(
                        tool.icon,
                        color: accent,
                        size: compact ? 18 : 22,
                      ),
                    ),
                    const Spacer(),
                    if (tool.badge != null) ...[
                      _BadgeChip(badge: tool.badge!),
                      const SizedBox(width: 2),
                    ],
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        unawaited(_toggleFavorite(context, ref));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: isFavorite
                              ? AppColors.brandMagenta
                              : p.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 12),
                Text(
                  tool.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: compact
                      ? AppTypography.toolTitle(context, color: p.textPrimary)
                      : AppTypography.titleSmall(
                          context,
                          color: p.textPrimary,
                          weight: FontWeights.extrabold,
                        ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    tool.description,
                    maxLines: compact ? 2 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: compact
                        ? AppTypography.caption(context,
                            color: p.textSecondary)
                        : AppTypography.bodySmall(context,
                            color: p.textSecondary),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: id.tint(context),
                        borderRadius: Radii.brPill,
                      ),
                      child: Text(
                        shortCat.toUpperCase(),
                        style: AppTypography.overline(context, color: accent),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 14,
                      color: accent.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final ToolBadge badge;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (badge) {
      ToolBadge.popular =>
        ('POPULAR', CategoryColors.premium.accentOf(context)),
      // Status colour, not a category — matches the New filter chip in Search.
      ToolBadge.isNew => ('NEW', AppColors.success),
      ToolBadge.ai => ('AI', CategoryColors.ai.accentOf(context)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: Radii.brPill,
      ),
      child: Text(
        label,
        style: AppTypography.badge(context, color: color),
      ),
    );
  }
}
