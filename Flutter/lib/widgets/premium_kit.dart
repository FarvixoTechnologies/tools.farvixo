import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// ============================================================================
/// FARVIXO PREMIUM UI KIT
/// Shared "ultra" building blocks so every screen matches the Home dashboard:
/// animated galaxy background, glass cards, glowing icons, staggered entrance
/// transitions, premium top bars and empty states. All theme-adaptive
/// (dark / light / custom accent).
/// ============================================================================

/// Animated galaxy backdrop (orbs + twinkling stars) identical to Home.
/// Wrap a page body with this; it sits behind [child].
class PremiumBackground extends StatefulWidget {
  const PremiumBackground({super.key, required this.child});

  final Widget child;

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bg =
      AnimationController(vsync: this, duration: const Duration(seconds: 30))
        ..repeat();

  @override
  void dispose() {
    _bg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _bg,
              builder: (context, _) => CustomPaint(
                painter: _GalaxyPainter(_bg.value, p.isDark, p.accent),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter(this.t, this.isDark, this.accent);
  final double t;
  final bool isDark;
  final Color accent;

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
    orb.color = accent.withValues(alpha: base);
    canvas.drawCircle(
        Offset(size.width * .1 + drift, size.height * .08), 120, orb);
    orb.color = AppColors.brandMagenta.withValues(alpha: base * .7);
    canvas.drawCircle(
        Offset(size.width * .9 - drift, size.height * .5), 130, orb);
    orb.color = AppColors.goldPremium.withValues(alpha: base * .5);
    canvas.drawCircle(
        Offset(size.width * .5, size.height * .95 + drift), 120, orb);

    if (isDark) {
      final p = Paint();
      for (final (x, y, r, phase) in _stars) {
        final tw = .12 + (math.sin(t * 20 + phase) + 1) / 2 * .35;
        p.color = accent.withValues(alpha: tw);
        canvas.drawCircle(Offset(x * size.width, y * size.height), r, p);
      }
    }
  }

  @override
  bool shouldRepaint(_GalaxyPainter old) =>
      old.t != t || old.isDark != isDark || old.accent != accent;
}

/// Staggered fade + slide-up entrance. Drop around any widget; [index]
/// controls the stagger delay. Self-contained (own controller) so it can be
/// used anywhere without a shared ticker.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, this.index = 0, required this.child});

  final int index;
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween<Offset>(
          begin: const Offset(0, .10), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(
        Duration(milliseconds: (widget.index * 70).clamp(0, 700)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Glassmorphism card — adaptive surface, subtle border and optional accent
/// glow. Tapable when [onTap] is provided.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
    this.glowColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? glowColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final glow = glowColor ?? p.accent;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? .75 : 1),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? p.border),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: p.isDark ? .10 : .06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: card,
    );
  }
}

/// Rounded glowing icon tile (category / feature accent).
class GlowIcon extends StatelessWidget {
  const GlowIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
    this.iconSize = 22,
    this.radius = 13,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .3), blurRadius: 12),
        ],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

/// Circular glass icon button used in premium top bars.
class CircleGlassButton extends StatelessWidget {
  const CircleGlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: .8),
              shape: BoxShape.circle,
              border: Border.all(color: p.border),
            ),
            child: Icon(icon, size: 20, color: p.textPrimary),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4.5),
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
      ],
    );
  }
}

/// Premium page header: optional back button, gradient title, subtitle and
/// trailing actions.
class PremiumHeader extends StatelessWidget {
  const PremiumHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.emoji,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        if (onBack != null) ...[
          CircleGlassButton(
              icon: Icons.arrow_back_rounded, onTap: onBack!),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (emoji != null) ...[
                    Text(emoji!, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: ShaderMask(
                      shaderCallback: (b) => LinearGradient(colors: [
                        p.textPrimary,
                        p.accent,
                      ]).createShader(b),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style:
                        TextStyle(fontSize: 12.5, color: p.textSecondary)),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// Premium empty-state used across Downloads / Favorites / Search etc.
class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent,
    this.actionLabel,
    this.onAction,
    this.emoji,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? accent;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = accent ?? p.accent;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    color.withValues(alpha: .22),
                    AppColors.brandMagenta.withValues(alpha: .12),
                  ]),
                  border: Border.all(color: color.withValues(alpha: .35)),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: .25), blurRadius: 30),
                  ],
                ),
                child: emoji != null
                    ? Center(
                        child: Text(emoji!,
                            style: const TextStyle(fontSize: 44)))
                    : Icon(icon, size: 46, color: color),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5, height: 1.5, color: p.textSecondary)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                _GradientButton(label: actionLabel!, onTap: onAction!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small gradient pill button (accent → magenta).
class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            accent,
            Color.lerp(accent, AppColors.brandMagenta, .55)!,
          ]),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
                color: accent.withValues(alpha: .5), blurRadius: 16),
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
    );
  }
}

/// Section header row (title + optional "View All").
class PremiumSectionHead extends StatelessWidget {
  const PremiumSectionHead({
    super.key,
    required this.title,
    this.onViewAll,
    this.padding = const EdgeInsets.fromLTRB(4, 22, 4, 12),
  });

  final String title;
  final VoidCallback? onViewAll;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary)),
          ),
          if (onViewAll != null)
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All',
                        style:
                            TextStyle(fontSize: 12.5, color: p.accent)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: p.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
