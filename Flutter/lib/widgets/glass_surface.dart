/// Glassmorphism surface primitive.
///
/// [GlassPanel] is the canonical reusable frosted surface: a real
/// [BackdropFilter] blur ([Blurs]), a theme-adaptive translucent tint, a soft
/// hairline border and a token-driven shadow ([Elevations]). It is wrapped in a
/// [RepaintBoundary] so its blur never forces siblings to repaint — key for
/// 60fps scrolling.
///
/// Prefer [GlassPanel] for new code. The older `GlassCard` in `premium_kit.dart`
/// now delegates here for backward compatibility.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/design_tokens.dart';
import 'animations.dart';

/// Frosted glass surface. Adapts tint/border/shadow to light, dark and
/// custom-accent themes.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    this.margin,
    this.borderRadius = Radii.brCard,
    this.blur = Blurs.glass,
    this.onTap,
    this.onLongPress,
    this.glowColor,
    this.borderColor,
    this.tintOpacity,
    this.elevated = false,
    this.haptic = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final double blur;

  /// When provided, the panel becomes a [PressableScale] tappable surface.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Accent used for the ambient glow (defaults to the theme accent).
  final Color? glowColor;
  final Color? borderColor;

  /// Override the surface tint opacity (0–1).
  final double? tintOpacity;

  /// Use the stronger raised shadow instead of the resting card shadow.
  final bool elevated;

  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final glow = glowColor ?? p.accent;
    final tint = tintOpacity ?? (p.isDark ? 0.62 : 0.82);

    final surface = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            ...(elevated ? Elevations.raised(p) : Elevations.card(p)),
            BoxShadow(
              color: glow.withValues(alpha: p.isDark ? 0.10 : 0.06),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: p.surface.withValues(alpha: tint),
                borderRadius: borderRadius,
                border: Border.all(
                  color: borderColor ??
                      (p.isDark
                          ? AppColors.onAccent.withValues(alpha: 0.06)
                          : p.border),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

    final result = margin != null
        ? Padding(padding: margin!, child: surface)
        : surface;

    if (onTap == null && onLongPress == null) return result;
    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      haptic: haptic,
      child: result,
    );
  }
}
