import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/notification_feed_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/category_colors.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/farvixo_logo.dart';

/// Home top bar — ☰ · crown logo · FARVIXO wordmark · search · bell ·
/// profile avatar (crown badge + online dot).
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.palette,
    required this.pulse,
    required this.onMenu,
    required this.userInitial,
    required this.isPro,
  });

  final AppPalette palette;
  final AnimationController pulse;
  final VoidCallback onMenu;
  final String userInitial;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, 10, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: Icon(Icons.menu_rounded, color: palette.textPrimary),
            tooltip: 'Menu',
          ),
          const FarvixoLogo(size: 36),
          const SizedBox(width: Insets.sm),
          ShaderMask(
            shaderCallback: (b) =>
                AppColors.goldMagentaGradient.createShader(b),
            // Opaque on-accent colour so the ShaderMask gradient replaces it.
            child: Text(
              'FARVIXO',
              style: AppTypography.wordmark(
                context,
                color: AppColors.onAccent,
              ),
            ),
          ),
          const Spacer(),
          // circular outlined search chip (matches approved design)
          Semantics(
            button: true,
            label: 'Search',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push('/search'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surfaceGlass,
                  border: Border.all(color: palette.border),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.xs),
          _BouncyBell(
            palette: palette,
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(width: Insets.xxs),
          // profile avatar with crown badge + online dot
          Semantics(
            button: true,
            label: 'Profile',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push('/profile'),
              child: AnimatedBuilder(
                animation: pulse,
                builder: (context, child) => Container(
                  padding: const EdgeInsets.all(Insets.xxs),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldMagentaGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldPremium.withValues(
                          alpha: .2 + pulse.value * .25,
                        ),
                        blurRadius: 10 + pulse.value * 6,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: palette.surface2,
                      child: Text(
                        userInitial,
                        style: AppTypography.titleMedium(
                          context,
                          color: CategoryColors.brand.accentOf(context),
                          weight: FontWeights.extrabold,
                        ),
                      ),
                    ),
                    if (isPro)
                      Positioned(
                        top: -7,
                        right: -3,
                        child: Text(
                          '👑',
                          style: AppTypography.labelMediumStyle,
                        ),
                      ),
                    // online status dot
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.bg, width: 1.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncyBell extends ConsumerStatefulWidget {
  const _BouncyBell({required this.onTap, required this.palette});

  final VoidCallback onTap;
  final AppPalette palette;

  @override
  ConsumerState<_BouncyBell> createState() => _BouncyBellState();
}

class _BouncyBellState extends ConsumerState<_BouncyBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.pulse,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsCountProvider);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final k = t < .15 ? math.sin(t / .15 * math.pi * 2) : 0.0;
        return Transform.rotate(angle: k * .18, child: child);
      },
      child: Stack(
        children: [
          IconButton(
            onPressed: widget.onTap,
            icon: Icon(
              Icons.notifications_outlined,
              color: widget.palette.textPrimary,
            ),
            tooltip: 'Notifications',
          ),
          if (unread > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: AppTypography.overline(
                    context,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
