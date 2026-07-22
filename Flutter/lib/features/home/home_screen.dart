import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/appearance_layout_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_kit.dart';
import 'widgets/home_background.dart';
import 'widgets/home_categories.dart';
import 'widgets/home_drawer.dart';
import 'widgets/home_header.dart';
import 'widgets/home_hero.dart';
import 'widgets/home_popular.dart';
import 'widgets/home_premium_banner.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_trending.dart';

/// FARVIXO — Home Dashboard (v10 Ultimate Enterprise, screen 022).
///
/// Mobile-first, theme-adaptive (dark / light / custom):
/// header (menu · crown logo · FARVIXO · search · bell · profile) →
/// galaxy hero with stats + auto slider → quick actions → explore
/// categories → trending tools (ratings + Hot/New badges) → popular tools
/// (two-column) → premium banner.
///
/// Composition only — every section lives in `widgets/` and reads the shared
/// [AppPalette] + design tokens, so this file stays a thin orchestrator.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _introController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: Motion.ambient,
    )..repeat();
    _introController = AnimationController(
      vsync: this,
      duration: Motion.intro,
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: Motion.breathe,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Staggered entrance driven by the shared intro controller so all
  /// sections animate on one ticker (cheaper than per-section controllers).
  Widget _entrance({required int index, required Widget child}) {
    final start = (index * 0.07).clamp(0.0, 0.65);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Motion.easeOut),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .12),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final appearance = ref.watch(appearanceLayoutProvider);
    final p = AppPalette.of(context);
    final screenW = MediaQuery.of(context).size.width;
    // Trending cards are sized so ~4.3 fit across the viewport (the design
    // shows the 5th card peeking at the right edge → horizontal scroll).
    final trendW = ((screenW - 32) / 4.3).clamp(72.0, 96.0);
    final compact = appearance.homeLayout == HomeLayoutMode.compact;
    final sectionGap = compact ? 10.0 : Insets.md;

    // Double-back-to-exit is handled once, at the MainShell level, so it
    // works identically on every tab.
    return Scaffold(
        backgroundColor: p.bg,
        drawer: HomeDrawer(palette: p),
        body: Builder(
          builder: (scaffoldContext) => Stack(
            children: [
              // ---------------- animated background ----------------
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, _) => CustomPaint(
                      painter: DashBackgroundPainter(
                        _bgController.value,
                        p.isDark,
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: RefreshIndicator(
                  onRefresh: () => Future<void>.delayed(Motion.refreshDwell),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // ================= header =================
                      SliverToBoxAdapter(
                        child: _entrance(
                          index: 0,
                          child: HomeHeader(
                            palette: p,
                            pulse: _pulseController,
                            onMenu: () =>
                                Scaffold.of(scaffoldContext).openDrawer(),
                            userInitial: (user?.displayName.isNotEmpty ?? false)
                                ? user!.displayName[0].toUpperCase()
                                : '?',
                            isPro: user?.isPro ?? false,
                          ),
                        ),
                      ),

                      // ================= hero banner =================
                      if (appearance.effectiveShowHero)
                        SliverToBoxAdapter(
                          child: _entrance(
                            index: 1,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: compact ? Insets.xs : 0,
                              ),
                              child: Transform.scale(
                                alignment: Alignment.topCenter,
                                scale: compact ? 0.92 : 1,
                                child: HeroCarousel(
                                  bg: _bgController,
                                  pulse: _pulseController,
                                  isDark: p.isDark,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ================= quick actions =================
                      if (appearance.homeShowQuickActions)
                        SliverToBoxAdapter(
                          child: _entrance(
                            index: 2,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                Insets.md,
                                sectionGap,
                                Insets.md,
                                0,
                              ),
                              child: SizedBox(
                                height: compact ? 50 : 58,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < 4; i++) ...[
                                      if (i > 0) const SizedBox(width: 9),
                                      Expanded(
                                        child: QuickActionCard(
                                          action: quickActions[i],
                                          palette: p,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ================= explore categories =================
                      SliverToBoxAdapter(
                        child: _entrance(
                          index: 3,
                          child: Padding(
                            padding: EdgeInsets.only(top: sectionGap),
                            child: PremiumSectionHead(
                              title: 'Explore Categories',
                              onViewAll: () => context.go('/tools'),
                              padding: const EdgeInsets.fromLTRB(
                                Insets.md,
                                22,
                                Insets.sm,
                                10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _entrance(
                          index: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.md,
                            ),
                            child: SizedBox(
                              height: 112,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var i = 0;
                                    i < homeCategoryPreviewCount;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(width: 10),
                                    Expanded(
                                      child: HomeCategoryCard(
                                        category: homeCategories[i],
                                        palette: p,
                                        highlighted: i == 0,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ================= trending tools =================
                      SliverToBoxAdapter(
                        child: _entrance(
                          index: 4,
                          child: PremiumSectionHead(
                            title: '🔥 Trending Tools',
                            onViewAll: () => context.go('/tools'),
                            padding: const EdgeInsets.fromLTRB(
                              Insets.md,
                              22,
                              Insets.sm,
                              10,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _entrance(
                          index: 4,
                          child: SizedBox(
                            height: 188,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Insets.md,
                              ),
                              itemCount: trendingItems.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) => TrendingCard(
                                item: trendingItems[i],
                                palette: p,
                                width: trendW,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ================= popular tools =================
                      SliverToBoxAdapter(
                        child: _entrance(
                          index: 5,
                          child: PremiumSectionHead(
                            title: 'Popular Tools',
                            onViewAll: () => context.go('/tools'),
                            padding: const EdgeInsets.fromLTRB(
                              Insets.md,
                              22,
                              Insets.sm,
                              10,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.md,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                mainAxisExtent: 64,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => PopularToolRow(
                              item: popularItems[i],
                              palette: p,
                            ),
                            childCount: math.min(popularItems.length, 8),
                          ),
                        ),
                      ),

                      // ================= premium banner =================
                      if (!(user?.isPro ?? false))
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Insets.md,
                              22,
                              Insets.md,
                              0,
                            ),
                            child: _entrance(
                              index: 6,
                              child: HomePremiumBanner(
                                pulse: _pulseController,
                                isDark: p.isDark,
                              ),
                            ),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 110)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
