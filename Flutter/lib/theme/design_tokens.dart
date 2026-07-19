/// Farvixo Enterprise Design System v10 — token scales.
///
/// Single source of truth for spacing, radius, elevation, motion and
/// blur so no screen ever hardcodes a magic number. Pair with [AppColors]
/// (fixed brand colors) and [AppPalette] (theme-adaptive surfaces/text).
///
/// These are pure constants / helpers — importing this file changes no
/// runtime behavior on its own.
library;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_palette.dart';

/// 4px-based spacing scale. `Insets.md` == 16.
class Insets {
  Insets._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Standard screen gutter (horizontal page padding).
  static const double gutter = 20;
}

/// Corner-radius scale. `Radii.card` == 16.
class Radii {
  Radii._();
  static const double xs = 6;
  static const double sm = 8;
  static const double button = 12;
  static const double card = 16;
  static const double panel = 20;
  static const double sheet = 28;
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brButton = BorderRadius.all(Radius.circular(button));
  static const BorderRadius brCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius brPanel = BorderRadius.all(Radius.circular(panel));
  static const BorderRadius brSheet = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Blur radii for glass-morphism surfaces.
class Blurs {
  Blurs._();
  static const double subtle = 8;
  static const double glass = 18;
  static const double heavy = 32;
}

/// Motion durations. Keep interactions in the 120–320ms band for a
/// responsive, premium feel; page-level transitions up to ~420ms.
class Motion {
  Motion._();
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration page = Duration(milliseconds: 420);

  /// Standard easing for enter/settle motion.
  static const Curve easeOut = Curves.easeOutCubic;

  /// Emphasized, springy easing for interactive press/scale.
  static const Curve emphasized = Curves.easeOutBack;

  /// Symmetric easing for cross-fades / color transitions.
  static const Curve standard = Curves.easeInOutCubic;
}

/// Elevation as reusable, theme-aware shadow stacks (Material 3 style soft
/// shadows rather than a single hard drop). Read via [AppPalette] so light
/// mode gets softer, cooler shadows than dark.
class Elevations {
  Elevations._();

  /// Resting card shadow.
  static List<BoxShadow> card(AppPalette p) => [
        BoxShadow(
          color: p.isDark
              ? const Color(0x66000000)
              : const Color(0x14181330),
          blurRadius: 18,
          spreadRadius: -6,
          offset: const Offset(0, 8),
        ),
      ];

  /// Raised / hovered / floating element shadow.
  static List<BoxShadow> raised(AppPalette p) => [
        BoxShadow(
          color: p.isDark
              ? const Color(0x8C000000)
              : const Color(0x1F181330),
          blurRadius: 32,
          spreadRadius: -8,
          offset: const Offset(0, 16),
        ),
      ];

  /// Colored accent glow for primary/CTA surfaces.
  static List<BoxShadow> accentGlow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.30),
          blurRadius: 28,
          spreadRadius: -10,
          offset: const Offset(0, 12),
        ),
      ];
}

/// Handy semantic durations for common widgets.
class Gaps {
  Gaps._();
  static const SizedBox h4 = SizedBox(height: Insets.xs);
  static const SizedBox h8 = SizedBox(height: Insets.sm);
  static const SizedBox h12 = SizedBox(height: 12);
  static const SizedBox h16 = SizedBox(height: Insets.md);
  static const SizedBox h24 = SizedBox(height: Insets.lg);
  static const SizedBox h32 = SizedBox(height: Insets.xl);
  static const SizedBox w4 = SizedBox(width: Insets.xs);
  static const SizedBox w8 = SizedBox(width: Insets.sm);
  static const SizedBox w12 = SizedBox(width: 12);
  static const SizedBox w16 = SizedBox(width: Insets.md);
}
