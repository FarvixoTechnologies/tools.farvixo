import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/category_colors.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/farvixo_logo.dart';

/// Home hero — galaxy glass card: crown logo + rotating RGB ring on the left,
/// headline + subtitle + stats on the right, 5 slides auto-advancing every 5s.
class HeroSlideData {
  const HeroSlideData({
    required this.line1,
    this.prefix = '',
    required this.highlight,
    this.suffix = '',
    required this.subtitle,
    required this.pill,
  });

  /// First headline line (plain).
  final String line1;

  /// Second headline line split into [prefix] + [highlight] (aurora gradient)
  /// + [suffix], so only the key word is coloured — matching the approved
  /// design ("One **Smart** Platform.").
  final String prefix;
  final String highlight;
  final String suffix;

  final String subtitle;
  final String pill;
}

const heroSlides = [
  HeroSlideData(
    line1: 'All Your Tools.',
    prefix: 'One ',
    highlight: 'Smart',
    suffix: ' Platform.',
    subtitle:
        '140+ Powerful Tools to Simplify, Create, Convert & Achieve More.',
    pill: '✨ AI POWERED ECOSYSTEM',
  ),
  HeroSlideData(
    line1: 'Meet Your',
    highlight: 'AI Assistant.',
    subtitle: 'Chat, write, summarize & translate — instantly with Farvixo AI.',
    pill: '🤖 SMART HELP 24/7',
  ),
  HeroSlideData(
    line1: 'Trending',
    highlight: 'This Week.',
    subtitle: 'OCR Scanner, BG Remover, AI Image & more hot tools.',
    pill: '🔥 MOST USED TOOLS',
  ),
  HeroSlideData(
    line1: 'Go',
    highlight: 'Farvixo Pro.',
    subtitle: 'Unlock every tool, higher limits and priority AI.',
    pill: '👑 PREMIUM UNLOCKED',
  ),
  HeroSlideData(
    line1: 'Join Our',
    highlight: 'Community.',
    subtitle: '10M+ happy users creating with Farvixo every day.',
    pill: '🌍 TRUSTED WORLDWIDE',
  ),
];

class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    super.key,
    required this.bg,
    required this.pulse,
    required this.isDark,
  });

  final AnimationController bg;
  final AnimationController pulse;
  final bool isDark;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Motion.carouselDwell, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % heroSlides.length,
        duration: Motion.carouselSlide,
        curve: Motion.easeOut,
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
      padding: const EdgeInsets.fromLTRB(Insets.md, 12, Insets.md, 0),
      child: Container(
        height: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: Radii.brHero,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Light mode gets a soft lilac card (dark text) instead of the
            // near-black galaxy gradient, so it no longer looks like dark mode.
            colors: isDark ? AppColors.heroCardDark : AppColors.heroCardLight,
          ),
          border: Border.all(color: CategoryColors.brand.border(context)),
          boxShadow: CategoryColors.brand.glow(context),
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
                    itemCount: heroSlides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _HeroSlide(
                      data: heroSlides[i],
                      bg: widget.bg,
                      pulse: widget.pulse,
                      isDark: isDark,
                    ),
                  ),
                ),
                // dots
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < heroSlides.length; i++)
                        AnimatedContainer(
                          duration: Motion.of(context, Motion.slow),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 18 : Space.s6,
                          height: Space.s6,
                          decoration: BoxDecoration(
                            borderRadius: Radii.brPill,
                            gradient:
                                i == _page ? AppColors.brandGradient : null,
                            color: i == _page
                                ? null
                                : AppPalette.of(context)
                                    .textPrimary
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

  final HeroSlideData data;
  final AnimationController bg;
  final AnimationController pulse;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final brand = CategoryColors.brand;
    final headlineColor = isDark ? AppColors.textPrimary : p.textPrimary;
    final headlineStyle = AppTypography.titleLarge(
      context,
      color: headlineColor,
      weight: FontWeights.black,
    ).copyWith(height: 1.15);
    final subtitleColor = isDark ? AppColors.lavender400 : p.textSecondary;
    final pillTextColor =
        isDark ? AppColors.lavender100 : brand.accentOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.s16,
        Space.s12,
        Space.s16,
        Space.s4,
      ),
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
                                color: CategoryColors.premium
                                    .accentOf(context)
                                    .withValues(alpha: glow),
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
                    horizontal: Space.s10,
                    vertical: Space.s4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: Radii.brPill,
                    color: brand
                        .accentOf(context)
                        .withValues(alpha: isDark ? .25 : .12),
                    border: Border.all(color: brand.border(context)),
                  ),
                  child: Text(
                    data.pill,
                    style: AppTypography.overline(
                      context,
                      color: pillTextColor,
                      weight: FontWeights.bold,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.sm),
                Text(data.line1, style: headlineStyle),
                // second line: prefix + highlight (gradient) + suffix
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (data.prefix.isNotEmpty)
                      Text(data.prefix, style: headlineStyle),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.auroraGradient.createShader(b),
                      child: Text(data.highlight, style: headlineStyle),
                    ),
                    if (data.suffix.isNotEmpty)
                      Text(data.suffix, style: headlineStyle),
                  ],
                ),
                const SizedBox(height: Insets.xs + 2),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall(
                    context,
                    color: subtitleColor,
                    weight: FontWeights.regular,
                  ).copyWith(height: 1.35),
                ),
                const SizedBox(height: Insets.sm),
                Row(
                  children: [
                    _HeroStat(
                        value: '140+', label: 'Smart Tools', isDark: isDark),
                    const SizedBox(width: Insets.sm),
                    _HeroStat(
                        value: '16', label: 'Categories', isDark: isDark),
                    const SizedBox(width: Insets.sm),
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
    final p = AppPalette.of(context);
    // Glass sits on the vivid galaxy card, so it is built from the on-accent
    // colour rather than the theme surface.
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.s8),
        decoration: BoxDecoration(
          color: AppColors.onAccent.withValues(alpha: isDark ? .06 : .7),
          borderRadius: Radii.brButton,
          border: Border.all(
            color: isDark
                ? AppColors.onAccent.withValues(alpha: .1)
                : CategoryColors.brand
                    .accentOf(context)
                    .withValues(alpha: .14),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.numeric(
                context,
                color: isDark ? AppColors.textPrimary : p.textPrimary,
                weight: FontWeights.black,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.overline(
                context,
                color: isDark ? AppColors.lavender500 : p.textMuted,
                weight: FontWeights.regular,
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
        colors: AppColors.rgbRingColors,
      ).createShader(rect);
    canvas.drawArc(rect, 0, 2 * math.pi, false, ring);
    final spark = Paint()
      ..color = AppColors.onAccent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(c.dx + r, c.dy), 4, spark);
  }

  @override
  bool shouldRepaint(_RgbRingPainter oldDelegate) => false;
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
