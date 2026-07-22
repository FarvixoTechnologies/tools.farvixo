import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/notification_feed_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/category_colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/skeletons.dart';
import '../../theme/app_typography.dart';

/// Notifications — Supabase feed with offline fallback list.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: FadeSlideIn(
                  child: async.when(
                    data: (items) {
                      final unread = items.where((n) => !n.isRead).length;
                      return PremiumHeader(
                        title: 'Notifications',
                        subtitle: unread > 0
                            ? '$unread unread update${unread == 1 ? '' : 's'}'
                            : 'You are all caught up',
                        emoji: '🔔',
                        onBack: () => context.canPop()
                            ? context.pop()
                            : context.go('/home'),
                        actions: unread > 0
                            ? [
                                TextButton(
                                  onPressed: () async {
                                    await NotificationFeedService.instance
                                        .markAllRead();
                                    ref.invalidate(notificationsListProvider);
                                  },
                                  child: const Text('Mark all read'),
                                ),
                              ]
                            : const [],
                      );
                    },
                    loading: () => PremiumHeader(
                      title: 'Notifications',
                      subtitle: 'Loading…',
                      emoji: '🔔',
                      onBack: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                    ),
                    error: (_, _) => PremiumHeader(
                      title: 'Notifications',
                      subtitle: 'Offline',
                      emoji: '🔔',
                      onBack: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: async.when(
                  loading: () => const _NotificationsSkeleton(),
                  error: (_, _) => PremiumEmptyState(
                    icon: Icons.cloud_off_rounded,
                    emoji: '📡',
                    accent: AppColors.error,
                    title: 'Could not load notifications',
                    message:
                        'Check your connection and pull down to try again.',
                    actionLabel: 'Retry',
                    onAction: () =>
                        ref.invalidate(notificationsListProvider),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return PremiumEmptyState(
                        icon: Icons.notifications_off_rounded,
                        emoji: '🔔',
                        title: 'No notifications yet',
                        message:
                            'Updates about your tools, files and account will show up here.',
                        actionLabel: 'Explore Tools',
                        onAction: () => context.go('/tools'),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => FadeSlideIn(
                        index: i,
                        child: _NotificationCard(
                          item: items[i],
                          onTap: () async {
                            if (!items[i].isRead &&
                                !items[i].id.startsWith('local-')) {
                              await NotificationFeedService.instance
                                  .markRead(items[i].id);
                              ref.invalidate(notificationsListProvider);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = _colorFor(context, item.type);
    return PressableScale(
      onTap: onTap,
      child: GlassCard(
          glowColor: color,
          borderColor: item.isRead
              ? null
              : AppColors.brandPrimary.withValues(alpha: .35),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .18),
                child: Icon(_iconFor(item.type), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTypography.titleSmall(context, weight: FontWeights.extrabold),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.brandPrimaryHover,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (item.body != null && item.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body!,
                        style: AppTypography.bodyMedium(context, color: p.textSecondary).copyWith(height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _timeLabel(item.createdAt),
                      style: AppTypography.labelSmall(context, color: p.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  static Color _colorFor(BuildContext context, String type) {
    switch (type) {
      case 'ai':
        return CategoryColors.ai.accentOf(context);
      case 'promo':
        return AppColors.goldPremium;
      case 'security':
        return AppColors.error;
      case 'tool':
        return AppColors.success;
      default:
        return AppColors.brandPrimary;
    }
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'ai':
        return Icons.auto_awesome_rounded;
      case 'promo':
        return Icons.workspace_premium_rounded;
      case 'security':
        return Icons.shield_rounded;
      case 'tool':
        return Icons.new_releases_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  static String _timeLabel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 2) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return 'Today';
    if (d.inDays < 2) return 'Yesterday';
    return '${d.inDays}d ago';
  }
}

/// Loading placeholder list that mirrors the notification card layout so the
/// switch from skeleton → real content causes no jump.
class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const _NotificationSkeletonCard(),
    );
  }
}

class _NotificationSkeletonCard extends StatelessWidget {
  const _NotificationSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: p.surface2.withValues(alpha: p.isDark ? 0.7 : 0.95),
            borderRadius: Radii.brXs,
          ),
        );
    return ExcludeSemantics(
      child: Shimmer(
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: p.isDark ? 0.72 : 0.95),
            borderRadius: Radii.brCard,
            border: Border.all(color: p.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.surface2.withValues(alpha: p.isDark ? 0.7 : 0.95),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(double.infinity, 12),
                    const SizedBox(height: 8),
                    bar(double.infinity, 10),
                    const SizedBox(height: 6),
                    bar(80, 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
