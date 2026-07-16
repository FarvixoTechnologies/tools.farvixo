import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/tools_data.dart';
import '../models/tool_model.dart';
import '../providers/tool_activity_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

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
            borderRadius: BorderRadius.circular(20),
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
                  borderRadius: BorderRadius.circular(999),
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
        ref.read(favoriteToolsProvider.notifier).toggle(tool.id);
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
              duration: Duration(seconds: 2),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ToolsData.categoryOf(tool);
    final p = AppPalette.of(context);
    final isFavorite = ref.watch(favoriteToolsProvider).contains(tool.id);
    final shortCat = category.name.replaceAll(' Tools', '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(context, ref),
        onLongPress: () => _longPressMenu(context, ref),
        child: Ink(
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: p.isDark ? 0.72 : 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: p.border.withValues(alpha: p.isDark ? 0.9 : 1),
            ),
            boxShadow: [
              BoxShadow(
                color: category.color.withValues(alpha: p.isDark ? 0.08 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 36 : 40,
                      height: compact ? 36 : 40,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        tool.icon,
                        color: category.color,
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
                        ref
                            .read(favoriteToolsProvider.notifier)
                            .toggle(tool.id);
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12.5 : 15,
                    height: 1.15,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    tool.description,
                    maxLines: compact ? 2 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10.5 : 12.5,
                      height: 1.25,
                      color: p.textSecondary,
                    ),
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
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        shortCat.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: category.color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 14,
                      color: p.accent.withValues(alpha: 0.85),
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
      ToolBadge.popular => ('POPULAR', AppColors.goldPremium),
      ToolBadge.isNew => ('NEW', AppColors.success),
      ToolBadge.ai => ('AI', AppColors.accentAi),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }
}
