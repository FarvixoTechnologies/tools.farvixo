import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/notification_feed_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/premium_kit.dart';

/// Notifications — Supabase feed with offline fallback list.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    final p = AppPalette.of(context);

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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Text('Could not load notifications',
                        style: TextStyle(color: p.textSecondary)),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(color: p.textSecondary),
                        ),
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
    final color = _colorFor(item.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
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
                        style: TextStyle(
                          fontSize: 13,
                          color: p.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _timeLabel(item.createdAt),
                      style: TextStyle(fontSize: 11.5, color: p.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _colorFor(String type) {
    switch (type) {
      case 'ai':
        return AppColors.accentAi;
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
