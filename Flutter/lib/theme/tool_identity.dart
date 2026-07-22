/// Per-tool visual identity engine.
///
/// [CategoryIdentity] gives each *category* a color; this layer gives each of
/// the 143 *tools* its own stable signature inside that family — a deterministic
/// hue shift derived from the tool id, plus ready-made gradient, glow and
/// confetti palettes. Two tools in the same category never look identical,
/// yet the category family remains recognizable.
///
/// ```dart
/// final identity = ToolIdentity.of('merge-pdf', categoryId: 'pdf');
/// identity.accent(context);          // this tool's unique accent
/// identity.gradient(context);        // hero / CTA gradient
/// identity.confettiColors(context);  // success celebration palette
/// ```
library;

import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'category_colors.dart';

class ToolIdentity {
  ToolIdentity._(this.toolId, this.category, this._hueShift);

  /// Tool slug from `tools_data.dart` (`merge-pdf`, `ai-writer`, …).
  final String toolId;

  /// The parent category identity — the color family this tool lives in.
  final CategoryIdentity category;

  /// Deterministic per-tool hue rotation in degrees (−14 … +14).
  final double _hueShift;

  static final Map<String, ToolIdentity> _cache = {};

  /// Resolves (and caches) the identity for a tool.
  static ToolIdentity of(String toolId, {String? categoryId}) {
    return _cache.putIfAbsent(toolId, () {
      final cat = CategoryColors.of(categoryId ?? toolId);
      // Stable hash — same tool id always yields the same shift on every
      // platform and app launch (String.hashCode is not guaranteed stable).
      var h = 0;
      for (final unit in toolId.codeUnits) {
        h = (h * 31 + unit) & 0x7fffffff;
      }
      final shift = ((h % 29) - 14).toDouble();
      return ToolIdentity._(toolId, cat, shift);
    });
  }

  /// Rotates [base] by this tool's hue shift, keeping saturation/lightness.
  Color _shifted(Color base) {
    if (_hueShift == 0) return base;
    final hsl = HSLColor.fromColor(base);
    return hsl.withHue((hsl.hue + _hueShift) % 360).toColor();
  }

  /// This tool's unique accent — the category hue, nudged.
  Color accent(BuildContext context) =>
      _shifted(category.accentOf(context));

  /// Companion stop for gradients, shifted in the opposite direction so the
  /// gradient spread widens slightly per tool.
  Color companion(BuildContext context) {
    final hsl = HSLColor.fromColor(category.companion);
    return hsl.withHue((hsl.hue - _hueShift) % 360).toColor();
  }

  /// Low-alpha chip / badge fill in this tool's accent.
  Color tint(BuildContext context) {
    final isDark = AppPalette.of(context).isDark;
    return accent(context).withValues(alpha: isDark ? 0.16 : 0.10);
  }

  /// Soft wash for hero headers and section backgrounds.
  Color wash(BuildContext context) {
    final isDark = AppPalette.of(context).isDark;
    return accent(context).withValues(alpha: isDark ? 0.08 : 0.05);
  }

  /// Hairline border in this tool's accent.
  Color border(BuildContext context) {
    final isDark = AppPalette.of(context).isDark;
    return accent(context).withValues(alpha: isDark ? 0.34 : 0.24);
  }

  /// Signature two-stop gradient for the hero, CTA and progress fill.
  LinearGradient gradient(
    BuildContext context, {
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [accent(context), companion(context)],
    );
  }

  /// Translucent surface gradient that carries the identity behind content.
  LinearGradient surfaceGradient(
    BuildContext context, {
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    final isDark = AppPalette.of(context).isDark;
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        accent(context).withValues(alpha: isDark ? 0.18 : 0.10),
        companion(context).withValues(alpha: isDark ? 0.06 : 0.03),
      ],
    );
  }

  /// Ambient glow under hero icons and CTAs, in this tool's accent.
  List<BoxShadow> glow(BuildContext context, {double strength = 1}) {
    final isDark = AppPalette.of(context).isDark;
    return [
      BoxShadow(
        color: accent(context)
            .withValues(alpha: (isDark ? 0.28 : 0.18) * strength),
        blurRadius: 28 * strength,
        spreadRadius: -10,
        offset: Offset(0, 12 * strength),
      ),
    ];
  }

  /// Celebration palette for [ConfettiBurst] — accent, companion and two
  /// brightness-shifted twins so the burst sparkles instead of being flat.
  List<Color> confettiColors(BuildContext context) {
    final a = accent(context);
    final c = companion(context);
    final aHsl = HSLColor.fromColor(a);
    final cHsl = HSLColor.fromColor(c);
    return [
      a,
      c,
      aHsl.withLightness((aHsl.lightness + 0.18).clamp(0.0, 1.0)).toColor(),
      cHsl.withLightness((cHsl.lightness - 0.12).clamp(0.0, 1.0)).toColor(),
      const Color(0xFFFFFFFF),
    ];
  }

  /// Foreground guaranteed readable on [gradient].
  Color onGradient(BuildContext context) => const Color(0xFFFFFFFF);
}
