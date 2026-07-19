import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/appearance_layout_provider.dart';
import '../../providers/tool_activity_provider.dart';
import '../../services/notification_feed_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/farvixo_logo.dart';

/// FARVIXO — Home Dashboard FINAL (v10 Ultimate Enterprise, screen 022).
///
/// Mobile-first, theme-adaptive (dark / light / system):
/// header (menu · crown logo · FARVIXO · search · bell · profile) →
/// galaxy hero with stats + auto slider → quick actions → explore
/// categories → trending tools (ratings + Hot/New badges + favorite) →
/// popular tools (two-column) → premium banner.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Theme-adaptive palette so text stays readable in dark, light and
/// custom modes (FINAL spec: "dark & light & custom mode text fix").
class HomePalette {
  const HomePalette({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
  });

  factory HomePalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Custom accent flows from the app theme so every home highlight
    // follows the user's chosen colour.
    final accent = Theme.of(context).colorScheme.primary;
    return isDark
        ? HomePalette(
            isDark: true,
            bg: AppColors.bgBase,
            surface: const Color(0xBF12121C), // bgSurface @ .75
            surface2: AppColors.bgSurface2,
            border: AppColors.borderSubtle,
            textPrimary: AppColors.textPrimary,
            textSecondary: AppColors.textSecondary,
            textMuted: AppColors.textMuted,
            accent: accent,
          )
        : HomePalette(
            isDark: false,
            bg: const Color(0xFFF6F6FB),
            surface: Colors.white,
            surface2: const Color(0xFFEFEFF7),
            border: const Color(0xFFE3E3F0),
            textPrimary: const Color(0xFF1A1330),
            textSecondary: const Color(0xFF5A5876),
            textMuted: const Color(0xFF8A88A3),
            accent: accent,
          );
  }

  final bool isDark;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _introController;
  late final AnimationController _pulseController;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _entrance({required int index, required Widget child}) {
    final start = (index * 0.07).clamp(0.0, 0.65);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
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

  Future<bool> _confirmExit() async {
    final now = DateTime.now();
    final pressedRecently =
        _lastBackPressed != null &&
        now.difference(_lastBackPressed!) < const Duration(seconds: 2);
    _lastBackPressed = now;

    if (pressedRecently) return true;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final appearance = ref.watch(appearanceLayoutProvider);
    final p = HomePalette.of(context);
    final screenW = MediaQuery.of(context).size.width;
    // Trending cards are sized so ~4.3 fit across the viewport (the design
    // shows the 5th card peeking at the right edge → horizontal scroll).
    final trendW = ((screenW - 32) / 4.3).clamp(72.0, 96.0);
    final compact = appearance.homeLayout == HomeLayoutMode.compact;
    final sectionGap = compact ? 10.0 : 16.0;

    return PopScope(
      // Only the root home route handles app exit. Other routes keep normal
      // router back behavior. Double-back within 2s to exit.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (shouldExit) await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        drawer: _HomeDrawer(palette: p),
        body: Builder(
          builder: (scaffoldContext) => Stack(
            children: [
              // ---------------- animated background ----------------
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, _) => CustomPaint(
                      painter: _DashBackgroundPainter(
                        _bgController.value,
                        p.isDark,
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: RefreshIndicator(
                  onRefresh: () =>
                      Future<void>.delayed(const Duration(milliseconds: 800)),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // ================= header =================
                      SliverToBoxAdapter(
                        child: _entrance(
                          index: 0,
                          child: _Header(
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
                                top: compact ? 4 : 0,
                              ),
                              child: Transform.scale(
                                alignment: Alignment.topCenter,
                                scale: compact ? 0.92 : 1,
                                child: _HeroCarousel(
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
                                16,
                                sectionGap,
                                16,
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
                                        child: _QuickActionCard(
                                          action: _quickActions[i],
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
                            child: _SectionHead(
                              palette: p,
                              title: 'Explore Categories',
                              onViewAll: () => context.go('/tools'),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _entrance(
                          index: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              height: 112,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var i = 0;
                                    i < _homeCategoryPreviewCount;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(width: 10),
                                    Expanded(
                                      child: _CategoryCard(
                                        category: _homeCategories[i],
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
                          child: _SectionHead(
                            palette: p,
                            title: '🔥 Trending Tools',
                            onViewAll: () => context.go('/tools'),
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
                                horizontal: 16,
                              ),
                              itemCount: _trendingItems.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) => _TrendingCard(
                                item: _trendingItems[i],
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
                          child: _SectionHead(
                            palette: p,
                            title: 'Popular Tools',
                            onViewAll: () => context.go('/tools'),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                mainAxisExtent: 64,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) =>
                                _PopularRow(item: _popularItems[i], palette: p),
                            childCount: math.min(_popularItems.length, 8),
                          ),
                        ),
                      ),

                      // ================= premium banner =================
                      if (!(user?.isPro ?? false))
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                            child: _entrance(
                              index: 6,
                              child: _PremiumBanner(
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
      ),
    );
  }
}

// =============================================================================
// HEADER — ☰ · crown logo · FARVIXO · 🔍 · 🔔 · 👤(crown badge + online)
// =============================================================================
class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.pulse,
    required this.onMenu,
    required this.userInitial,
    required this.isPro,
  });

  final HomePalette palette;
  final AnimationController pulse;
  final VoidCallback onMenu;
  final String userInitial;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: Icon(Icons.menu_rounded, color: palette.textPrimary),
            tooltip: 'Menu',
          ),
          const FarvixoLogo(size: 36),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFF5B93D), Color(0xFFC026D3)],
            ).createShader(b),
            child: const Text(
              'FARVIXO',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: Colors.white,
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
                  color: palette.surface,
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
          const SizedBox(width: 4),
          _BouncyBell(
            palette: palette,
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(width: 2),
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
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5B93D), Color(0xFFC026D3)],
                    ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandPrimaryHover,
                        ),
                      ),
                    ),
                    if (isPro)
                      const Positioned(
                        top: -7,
                        right: -3,
                        child: Text('👑', style: TextStyle(fontSize: 12)),
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
  final HomePalette palette;

  @override
  ConsumerState<_BouncyBell> createState() => _BouncyBellState();
}

class _BouncyBellState extends ConsumerState<_BouncyBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
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
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// DRAWER (☰ menu)
// =============================================================================
class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer({required this.palette});
  final HomePalette palette;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: palette.isDark ? AppColors.bgSurface : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const FarvixoLogo(size: 44),
                  const SizedBox(width: 10),
                  Text(
                    'FARVIXO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Downloads'),
              onTap: () {
                Navigator.pop(context);
                context.push('/downloads');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HERO — galaxy glass card, logo + RGB ring left, headline + stats right,
// 5 slides auto 5s
// =============================================================================
class _HeroSlideData {
  const _HeroSlideData({
    required this.line1,
    this.prefix = '',
    required this.highlight,
    this.suffix = '',
    required this.subtitle,
    required this.pill,
  });

  /// First headline line (plain white).
  final String line1;

  /// Second headline line split into [prefix] (white) + [highlight]
  /// (gradient) + [suffix] (white), so only the key word is coloured —
  /// matching the approved design ("One **Smart** Platform.").
  final String prefix;
  final String highlight;
  final String suffix;

  final String subtitle;
  final String pill;
}

const _heroSlides = [
  _HeroSlideData(
    line1: 'All Your Tools.',
    prefix: 'One ',
    highlight: 'Smart',
    suffix: ' Platform.',
    subtitle:
        '120+ Powerful Tools to Simplify, Create, Convert & Achieve More.',
    pill: '✨ AI POWERED ECOSYSTEM',
  ),
  _HeroSlideData(
    line1: 'Meet Your',
    highlight: 'AI Assistant.',
    subtitle: 'Chat, write, summarize & translate — instantly with Farvixo AI.',
    pill: '🤖 SMART HELP 24/7',
  ),
  _HeroSlideData(
    line1: 'Trending',
    highlight: 'This Week.',
    subtitle: 'OCR Scanner, BG Remover, AI Image & more hot tools.',
    pill: '🔥 MOST USED TOOLS',
  ),
  _HeroSlideData(
    line1: 'Go',
    highlight: 'Farvixo Pro.',
    subtitle: 'Unlock every tool, higher limits and priority AI.',
    pill: '👑 PREMIUM UNLOCKED',
  ),
  _HeroSlideData(
    line1: 'Join Our',
    highlight: 'Community.',
    subtitle: '10M+ happy users creating with Farvixo every day.',
    pill: '🌍 TRUSTED WORLDWIDE',
  ),
];

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({
    required this.bg,
    required this.pulse,
    required this.isDark,
  });
  final AnimationController bg;
  final AnimationController pulse;
  final bool isDark;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _heroSlides.length,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Light mode gets a soft lilac card (dark text) instead of the
            // near-black galaxy gradient, so it no longer looks like dark mode.
            colors: isDark
                ? const [Color(0xFF160A33), Color(0xFF0A0518)]
                : const [Color(0xFFF1EBFF), Color(0xFFFBF7FF)],
          ),
          border: Border.all(
            color: isDark
                ? AppColors.brandPrimaryHover.withValues(alpha: .3)
                : AppColors.brandPrimary.withValues(alpha: .18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPrimary.withValues(alpha: isDark ? .25 : .12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // galaxy particles (only meaningful on the dark galaxy card)
            if (isDark)
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: widget.bg,
                    builder: (context, _) => CustomPaint(
                      painter: _HeroParticlesPainter(widget.bg.value),
                    ),
                  ),
                ),
              ),
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _heroSlides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _HeroSlide(
                      data: _heroSlides[i],
                      bg: widget.bg,
                      pulse: widget.pulse,
                      isDark: isDark,
                    ),
                  ),
                ),
                // dots
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _heroSlides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: i == _page
                                ? AppColors.brandGradient
                                : null,
                            color: i == _page
                                ? null
                                : (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: .22),
                          ),
                        ),
                    ],
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

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({
    required this.data,
    required this.bg,
    required this.pulse,
    required this.isDark,
  });
  final _HeroSlideData data;
  final AnimationController bg;
  final AnimationController pulse;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final headlineColor = isDark ? Colors.white : const Color(0xFF1A1330);
    final headlineStyle = TextStyle(
      fontSize: 20,
      height: 1.15,
      fontWeight: FontWeight.w900,
      color: headlineColor,
    );
    final subtitleColor =
        isDark ? const Color(0xFFA9A3CC) : const Color(0xFF5A5876);
    final pillTextColor =
        isDark ? const Color(0xFFE0D5FF) : AppColors.brandPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          // -------- left: crown logo + RGB ring --------
          SizedBox(
            width: 128,
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([bg, pulse]),
                builder: (context, child) {
                  final glow = .3 + pulse.value * .35;
                  return SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: bg.value * 2 * math.pi * 3,
                          child: CustomPaint(
                            size: const Size(116, 116),
                            painter: _RgbRingPainter(),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldPremium.withValues(
                                  alpha: glow,
                                ),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ],
                    ),
                  );
                },
                child: const FarvixoLogo(size: 78),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // -------- right: pill + headline + subtitle + stats --------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: AppColors.brandPrimary
                        .withValues(alpha: isDark ? .25 : .12),
                    border: Border.all(
                      color: AppColors.brandPrimaryHover
                          .withValues(alpha: isDark ? .4 : .3),
                    ),
                  ),
                  child: Text(
                    data.pill,
                    style: TextStyle(
                      fontSize: 8.5,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w700,
                      color: pillTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(data.line1, style: headlineStyle),
                // second line: prefix + highlight (gradient) + suffix
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (data.prefix.isNotEmpty)
                      Text(data.prefix, style: headlineStyle),
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [
                          Color(0xFF8B5CF6),
                          Color(0xFFEC4899),
                          Color(0xFF3B82F6),
                        ],
                      ).createShader(b),
                      child: Text(data.highlight, style: headlineStyle),
                    ),
                    if (data.suffix.isNotEmpty)
                      Text(data.suffix, style: headlineStyle),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _HeroStat(
                        value: '120+', label: 'Smart Tools', isDark: isDark),
                    const SizedBox(width: 8),
                    _HeroStat(
                        value: '16', label: 'Categories', isDark: isDark),
                    const SizedBox(width: 8),
                    _HeroStat(
                        value: '10M+', label: 'Happy Users', isDark: isDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.isDark,
  });
  final String value;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: .06)
              : Colors.white.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: .1)
                : AppColors.brandPrimary.withValues(alpha: .14),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1330),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                color:
                    isDark ? const Color(0xFF9BA0C2) : const Color(0xFF8A88A3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RgbRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFF5B93D),
          Color(0xFFEC4899),
          Color(0xFF8B5CF6),
          Color(0xFF3B82F6),
          Color(0xFF22D3EE),
          Color(0xFFF5B93D),
        ],
      ).createShader(rect);
    canvas.drawArc(rect, 0, 2 * math.pi, false, ring);
    final spark = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(c.dx + r, c.dy), 4, spark);
  }

  @override
  bool shouldRepaint(_RgbRingPainter oldDelegate) => false;
}

// =============================================================================
// QUICK ACTIONS
// =============================================================================
class _QuickAction {
  const _QuickAction(
    this.icon,
    this.title,
    this.subtitle,
    this.color,
    this.route,
  );
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
}

const _quickActions = [
  _QuickAction(
    Icons.smart_toy_outlined,
    'AI Assistant',
    'Smart Help',
    AppColors.accentText,
    '/ai',
  ),
  _QuickAction(
    Icons.folder_open_rounded,
    'Recent Files',
    'View History',
    AppColors.brandPrimaryHover,
    '/downloads',
  ),
  _QuickAction(
    Icons.favorite_outline_rounded,
    'Favorites',
    'Your Collection',
    AppColors.brandMagenta,
    '/favorites',
  ),
  _QuickAction(
    Icons.cloud_outlined,
    'Cloud Drive',
    'Storage Access',
    AppColors.accentDev,
    '/downloads',
  ),
  _QuickAction(
    Icons.download_outlined,
    'Downloads',
    'Saved Files',
    AppColors.accentImage,
    '/downloads',
  ),
  _QuickAction(
    Icons.grid_view_rounded,
    'All Tools',
    '120+ Tools',
    AppColors.goldPremium,
    '/tools',
  ),
];

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.palette});
  final _QuickAction action;
  final HomePalette palette;

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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: action.color.withValues(alpha: .25),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(action.icon, color: action.color, size: 16),
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
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
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
                        style: TextStyle(fontSize: 8, color: palette.textMuted),
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

// =============================================================================
// SECTION HEAD
// =============================================================================
class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.palette,
    required this.title,
    required this.onViewAll,
  });
  final HomePalette palette;
  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All',
                  style: TextStyle(fontSize: 12.5, color: palette.accent),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: palette.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CATEGORIES
// =============================================================================
/// Curated home categories — exact labels, counts, icons and colours from
/// the approved design (kept local so the shared tool catalog is untouched).
class _HomeCategory {
  const _HomeCategory(
    this.label,
    this.count,
    this.icon,
    this.color,
    this.route,
  );
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final String route;
}

/// Mobile home preview — exactly 4 category cards in one row.
const _homeCategoryPreviewCount = 4;

const _homeCategories = [
  _HomeCategory(
    'PDF & Document',
    10,
    Icons.picture_as_pdf_rounded,
    AppColors.accentPdf,
    '/tools?category=pdf',
  ),
  _HomeCategory(
    'Image & Photo',
    9,
    Icons.image_rounded,
    AppColors.accentAudio,
    '/tools?category=image',
  ),
  _HomeCategory(
    'Video Tools',
    9,
    Icons.play_circle_rounded,
    AppColors.accentVideo,
    '/tools?category=video',
  ),
  _HomeCategory(
    'AI Tools',
    12,
    Icons.smart_toy_rounded,
    AppColors.accentDev,
    '/tools?category=ai',
  ),
];

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.palette,
    this.highlighted = false,
  });

  final _HomeCategory category;
  final HomePalette palette;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.go(category.route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? category.color.withValues(alpha: .6)
                : palette.border,
            width: highlighted ? 1.3 : 1,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: category.color.withValues(alpha: .18),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: category.color.withValues(alpha: .3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(category.icon, color: category.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              category.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${category.count} Tools',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TRENDING — badge, rating, favorite
// =============================================================================
/// Curated trending tools — exact copy, ratings, badges and colours from
/// the approved design.
class _TrendingItem {
  const _TrendingItem({
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.icon,
    required this.color,
    required this.badgeText,
    required this.badgeColor,
    required this.route,
    this.toolId,
  });
  final String title;
  final String subtitle;
  final double rating;
  final IconData icon;
  final Color color;
  final String badgeText;
  final Color badgeColor;
  final String route;
  final String? toolId;
}

const _trendingItems = [
  _TrendingItem(
    title: 'PDF Converter',
    subtitle: 'Convert PDF to Word, Excel, PPT',
    rating: 4.8,
    icon: Icons.picture_as_pdf_rounded,
    color: AppColors.accentPdf,
    badgeText: '🔥 Hot',
    badgeColor: AppColors.error,
    route: '/tool/pdf-to-word',
    toolId: 'pdf-to-word',
  ),
  _TrendingItem(
    title: 'Image to PDF',
    subtitle: 'Convert Images to PDF',
    rating: 4.7,
    icon: Icons.image_rounded,
    color: AppColors.accentImage,
    badgeText: 'New',
    badgeColor: AppColors.success,
    route: '/tool/image-converter',
    toolId: 'image-converter',
  ),
  _TrendingItem(
    title: 'AI Image Generator',
    subtitle: 'Create AI Images from Text',
    rating: 4.9,
    icon: Icons.auto_awesome_rounded,
    color: AppColors.brandMagenta,
    badgeText: '🔥 Hot',
    badgeColor: AppColors.error,
    route: '/tools?category=ai',
  ),
  _TrendingItem(
    title: 'OCR Image',
    subtitle: 'Extract Text from Image',
    rating: 4.8,
    icon: Icons.document_scanner_rounded,
    color: AppColors.accentDev,
    badgeText: 'New',
    badgeColor: AppColors.success,
    route: '/tool/image-ocr',
    toolId: 'image-ocr',
  ),
  _TrendingItem(
    title: 'Video Converter',
    subtitle: 'Convert Video to MP4, AVI, MOV',
    rating: 4.7,
    icon: Icons.movie_rounded,
    color: AppColors.accentAudio,
    badgeText: '',
    badgeColor: Colors.transparent,
    route: '/tool/video-converter',
    toolId: 'video-converter',
  ),
];

class _TrendingCard extends ConsumerWidget {
  const _TrendingCard({
    required this.item,
    required this.palette,
    required this.width,
  });
  final _TrendingItem item;
  final HomePalette palette;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.color.withValues(alpha: .35),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: item.color.withValues(alpha: .12),
              blurRadius: 14,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: 18,
              child: item.badgeText.isEmpty
                  ? null
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.badgeColor.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: item.badgeColor.withValues(alpha: .45),
                          ),
                        ),
                        child: Text(
                          item.badgeText,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: item.badgeColor,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: .35),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                item.subtitle,
                maxLines: 3,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.25,
                  color: palette.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: AppColors.goldPremium,
                ),
                const SizedBox(width: 3),
                Text(
                  item.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldPremium,
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

// =============================================================================
// POPULAR — two-column rows
// =============================================================================
/// Curated popular tools — exact titles, subtitles, icons and colours from
/// the approved design (two-column list).
class _PopularItem {
  const _PopularItem(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.route, [
    this.toolId,
  ]);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final String? toolId;
}

const _popularItems = [
  _PopularItem(
    'Background Remover',
    'Remove Background',
    Icons.auto_fix_high_rounded,
    AppColors.accentImage,
    '/tool/background-remover',
    'background-remover',
  ),
  _PopularItem(
    'PDF to Word',
    'Convert PDF to Word',
    Icons.description_rounded,
    AppColors.accentDev,
    '/tool/pdf-to-word',
    'pdf-to-word',
  ),
  _PopularItem(
    'QR Code Generator',
    'Create QR Codes Instantly',
    Icons.qr_code_rounded,
    AppColors.accentText,
    '/tool/qr-generator',
    'qr-generator',
  ),
  _PopularItem(
    'Compress PDF',
    'Reduce PDF File Size',
    Icons.compress_rounded,
    AppColors.accentAudio,
    '/tool/compress-pdf',
    'compress-pdf',
  ),
  _PopularItem(
    'Word Counter',
    'Count Words & Characters',
    Icons.format_list_numbered_rounded,
    AppColors.brandPrimaryHover,
    '/tool/word-counter',
    'word-counter',
  ),
  _PopularItem(
    'Image Resizer',
    'Resize Image in Any Size',
    Icons.aspect_ratio_rounded,
    AppColors.brandMagenta,
    '/tool/image-resizer',
    'image-resizer',
  ),
  _PopularItem(
    'Merge PDF',
    'Merge Multiple PDF Files',
    Icons.merge_rounded,
    AppColors.accentPdf,
    '/tool/merge-pdf',
    'merge-pdf',
  ),
  _PopularItem(
    'AI Chat Assistant',
    'Ask Anything, Get Answers',
    Icons.chat_bubble_rounded,
    AppColors.accentText,
    '/ai',
    'ai-chat',
  ),
];

class _PopularRow extends ConsumerWidget {
  const _PopularRow({required this.item, required this.palette});
  final _PopularItem item;
  final HomePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, color: palette.textMuted),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PREMIUM BANNER
// =============================================================================
class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.pulse, required this.isDark});
  final AnimationController pulse;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1330);
    final bodyColor =
        isDark ? const Color(0xFFB9B2DA) : const Color(0xFF5A5876);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF2A0F55), Color(0xFF1B1040), Color(0xFF3A2408)]
              : const [Color(0xFFF3ECFF), Color(0xFFEDE7FF), Color(0xFFFCF3E4)],
        ),
        border: Border.all(color: AppColors.goldPremium.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: pulse,
              builder: (context, child) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldPremium.withValues(
                        alpha: .25 + pulse.value * .25,
                      ),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: child,
              ),
              child: const FarvixoLogo(size: 58),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Upgrade to ',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFFF5B93D), Color(0xFFEC4899)],
                        ).createShader(b),
                        child: const Text(
                          'Farvixo Pro 👑',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlock all premium tools, remove limits, ads free experience & much more!',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: bodyColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => context.push('/profile'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandMagenta.withValues(alpha: .5),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Upgrade Now',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // floating hex feature icons
            AnimatedBuilder(
              animation: pulse,
              builder: (context, _) => Column(
                children: [
                  Transform.translate(
                    offset: Offset(0, pulse.value * -3),
                    child: _HexIcon(icon: Icons.bolt_rounded, isDark: isDark),
                  ),
                  const SizedBox(height: 6),
                  Transform.translate(
                    offset: Offset(0, pulse.value * 3),
                    child: _HexIcon(icon: Icons.shield_outlined, isDark: isDark),
                  ),
                  const SizedBox(height: 6),
                  Transform.translate(
                    offset: Offset(0, pulse.value * -2),
                    child: _HexIcon(
                      icon: Icons.all_inclusive_rounded,
                      isDark: isDark,
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

class _HexIcon extends StatelessWidget {
  const _HexIcon({required this.icon, required this.isDark});
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.brandPrimaryHover.withValues(alpha: isDark ? .55 : .4),
        ),
        color: AppColors.brandPrimary.withValues(alpha: isDark ? .18 : .1),
      ),
      child: Icon(
        icon,
        size: 16,
        color: isDark ? const Color(0xFFD8CCFF) : AppColors.brandPrimary,
      ),
    );
  }
}

// =============================================================================
// BACKGROUNDS
// =============================================================================
class _DashBackgroundPainter extends CustomPainter {
  _DashBackgroundPainter(this.t, this.isDark);
  final double t;
  final bool isDark;

  static final _stars = List.generate(50, (i) {
    final rnd = math.Random(i * 13 + 5);
    return (
      rnd.nextDouble(),
      rnd.nextDouble(),
      rnd.nextDouble() * 1.3 + .3,
      rnd.nextDouble() * math.pi * 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final orb = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    final drift = math.sin(t * 2 * math.pi) * 30;
    final base = isDark ? .12 : .06;
    orb.color = AppColors.brandPrimary.withValues(alpha: base);
    canvas.drawCircle(
      Offset(size.width * .1 + drift, size.height * .08),
      120,
      orb,
    );
    orb.color = AppColors.brandMagenta.withValues(alpha: base * .7);
    canvas.drawCircle(
      Offset(size.width * .9 - drift, size.height * .5),
      130,
      orb,
    );

    if (isDark) {
      final p = Paint();
      for (final (x, y, r, phase) in _stars) {
        final tw = .12 + (math.sin(t * 20 + phase) + 1) / 2 * .35;
        p.color = AppColors.brandPrimaryHover.withValues(alpha: tw);
        canvas.drawCircle(Offset(x * size.width, y * size.height), r, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashBackgroundPainter old) =>
      old.t != t || old.isDark != isDark;
}

class _HeroParticlesPainter extends CustomPainter {
  _HeroParticlesPainter(this.t);
  final double t;

  static final _pts = List.generate(26, (i) {
    final rnd = math.Random(i * 31 + 7);
    return (
      rnd.nextDouble(),
      rnd.nextDouble(),
      rnd.nextDouble() * 1.5 + .5,
      rnd.nextDouble() * .5 + .2,
      rnd.nextDouble() > .7,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final (x, y0, r, speed, gold) in _pts) {
      final y = (y0 - t * speed * 4) % 1.0;
      final alpha = .2 + (math.sin(t * 30 * speed + x * 8) + 1) / 2 * .5;
      p.color = (gold ? AppColors.goldPremium : AppColors.brandPrimaryHover)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, p);
    }
  }

  @override
  bool shouldRepaint(_HeroParticlesPainter old) => old.t != t;
}
