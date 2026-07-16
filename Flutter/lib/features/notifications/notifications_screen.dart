import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/premium_kit.dart';

class _NotificationItem {
  const _NotificationItem(
      this.icon, this.color, this.title, this.body, this.time, this.unread);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final bool unread;
}

const _demoNotifications = [
  _NotificationItem(
    Icons.celebration_rounded,
    AppColors.brandPrimary,
    'Welcome to Farvixo!',
    'Explore 120+ tools and the AI Assistant — all in one app.',
    'Just now',
    true,
  ),
  _NotificationItem(
    Icons.auto_awesome_rounded,
    AppColors.accentAi,
    'AI Assistant is ready',
    'Ask anything — write, summarize, translate and more.',
    'Today',
    true,
  ),
  _NotificationItem(
    Icons.new_releases_rounded,
    AppColors.success,
    'New tools added',
    'AI Image Upscaler and Text Compare just landed.',
    'Yesterday',
    false,
  ),
  _NotificationItem(
    Icons.workspace_premium_rounded,
    AppColors.goldPremium,
    'Unlock Farvixo Pro',
    'Remove limits, go ad-free and access every premium tool.',
    '2 days ago',
    false,
  ),
];

/// Notifications — premium galaxy backdrop, glass header with unread count,
/// glowing glass cards with staggered entrance.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = _demoNotifications.where((n) => n.unread).length;
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: 'Notifications',
                    subtitle: unread > 0
                        ? '$unread unread update${unread == 1 ? '' : 's'}'
                        : 'You are all caught up',
                    emoji: '🔔',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: _demoNotifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => FadeSlideIn(
                    index: i,
                    child: _NotificationCard(item: _demoNotifications[i]),
                  ),
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
  const _NotificationCard({required this.item});
  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GlassCard(
      glowColor: item.color,
      borderColor: item.unread
          ? item.color.withValues(alpha: .35)
          : p.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlowIcon(icon: item.icon, color: item.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary)),
                    ),
                    if (item.unread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: item.color.withValues(alpha: .6),
                                blurRadius: 8),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.body,
                    style: TextStyle(
                        fontSize: 12.5, height: 1.4, color: p.textSecondary)),
                const SizedBox(height: 6),
                Text(item.time,
                    style: TextStyle(fontSize: 11, color: p.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
