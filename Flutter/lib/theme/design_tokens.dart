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

/// The complete 4px-based spacing ladder, addressed by value.
///
/// See also [Gap], [Insets], [Radii], [Motion], [Elevations] below.
///
/// Use this when you want an exact step (`Space.s20`). Use [Insets] when you
/// want the semantic name (`Insets.md`). They are the same numbers — [Insets]
/// is a semantic alias layer over this ladder.
class Space {
  Space._();
  static const double s0 = 0;
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s56 = 56;
  static const double s64 = 64;
  static const double s72 = 72;
  static const double s80 = 80;
  static const double s96 = 96;
  static const double s112 = 112;
  static const double s128 = 128;

  /// Every step, ascending — used by the token audit.
  static const List<double> ladder = [
    s0, s2, s4, s6, s8, s10, s12, s16, s20, s24, s28,
    s32, s40, s48, s56, s64, s72, s80, s96, s112, s128,
  ];
}

/// Role-named spacing — reads as intent at the call site.
///
/// `Gap.card` says *why* the number is 16; `Space.s16` says *what* it is.
/// Prefer this layer in feature code.
class Gap {
  Gap._();

  /// Inside a card / tile.
  static const double card = Space.s16;

  /// Inside a dialog / bottom sheet.
  static const double dialog = Space.s24;

  /// Horizontal page gutter.
  static const double screen = Space.s20;

  /// Between elements inside one group (icon → label).
  static const double inline = Space.s8;

  /// Between sibling items in a list or grid.
  static const double item = Space.s12;

  /// Between grid cells (both axes).
  static const double grid = Space.s12;

  /// Between rows in a vertical list.
  static const double list = Space.s8;

  /// Between actions in a toolbar / app bar.
  static const double toolbar = Space.s12;

  /// Between adjacent buttons in a row.
  static const double button = Space.s12;

  /// Between an icon and its adjacent label.
  static const double icon = Space.s8;

  /// Between stacked form fields.
  static const double input = Space.s16;

  /// Between content blocks inside a section.
  static const double content = Space.s16;

  /// Between major page sections.
  static const double section = Space.s32;

  /// Scroll bottom padding that clears the floating nav bar / FAB.
  static const double scrollBottom = Space.s96;
}

/// Semantic spacing scale. `Insets.md` == 16.
///
/// Names map onto the [Space] ladder; both are valid and interchangeable.
class Insets {
  Insets._();
  static const double xxs = Space.s2;
  static const double xs = Space.s4;
  static const double sm = Space.s8;
  static const double md = Space.s16;
  static const double lg = Space.s24;
  static const double xl = Space.s32;
  static const double xxl = Space.s48;
  static const double xxxl = Space.s64;

  /// Standard screen gutter (horizontal page padding).
  static const double gutter = Space.s20;

  // Intermediate steps the semantic ladder was missing.
  static const double smd = Space.s12;
  static const double mlg = Space.s20;
  static const double lxl = Space.s28;
  static const double xxxxl = Space.s80;

  /// Section rhythm — vertical gap between major page sections.
  static const double section = Space.s32;

  /// Bottom padding that clears the floating nav bar / FAB.
  static const double scrollBottom = Space.s96;
}

/// Corner-radius scale. `Radii.card` == 16.
///
/// Two naming layers over one ramp: **t-shirt** sizes (`xs`…`xxl`, `full`) and
/// **semantic** names (`button`, `card`, `sheet`, `hero`, `pill`). Prefer the
/// semantic name when the surface has an obvious role.
class Radii {
  Radii._();
  static const double xs = 6;
  static const double sm = 8;
  static const double button = 12;
  static const double tile = 14;
  static const double card = 16;
  static const double panel = 20;
  static const double banner = 22;
  static const double sheet = 28;
  static const double hero = 32;
  static const double pill = 999;

  // T-shirt aliases onto the same ramp.
  static const double none = 0;
  static const double md = card; // 16
  static const double lg = panel; // 20
  static const double xl = sheet; // 28
  static const double xxl = hero; // 32
  static const double full = pill; // 999

  // Component-role aliases — say what the surface is, not what size it is.
  static const double input = button; // 12
  static const double chip = pill; // 999
  static const double avatar = pill; // 999
  static const double fab = panel; // 20
  static const double dialog = sheet; // 28
  static const double bottomSheet = sheet; // 28
  static const double navigation = panel; // 20

  static const BorderRadius brNone = BorderRadius.zero;
  static const BorderRadius brInput = brButton;
  static const BorderRadius brChip = brPill;
  static const BorderRadius brAvatar = brPill;
  static const BorderRadius brFab = brPanel;
  static const BorderRadius brDialog = brSheet;
  static const BorderRadius brNavigation = brPanel;

  /// Bottom sheets round only their top corners.
  static const BorderRadius brBottomSheet = brSheetTop;

  static const BorderRadius brMd = brCard;
  static const BorderRadius brLg = brPanel;
  static const BorderRadius brXl = brSheet;
  static const BorderRadius brXxl = brHero;
  static const BorderRadius brFull = brPill;

  /// Top-only radius for bottom sheets and drag-up panels.
  static const BorderRadius brSheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );

  // Bare `Radius` values, for painters and `RRect` builders that take a
  // corner radius rather than a `BorderRadius`.
  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rTile = Radius.circular(tile);
  static const Radius rPanel = Radius.circular(panel);
  static const Radius rBanner = Radius.circular(banner);
  static const Radius rSheet = Radius.circular(sheet);
  static const Radius rHero = Radius.circular(hero);
  static const Radius rButton = Radius.circular(button);
  static const Radius rCard = Radius.circular(card);
  static const Radius rPill = Radius.circular(pill);

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brButton = BorderRadius.all(Radius.circular(button));
  static const BorderRadius brTile = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius brCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius brPanel = BorderRadius.all(Radius.circular(panel));
  static const BorderRadius brBanner = BorderRadius.all(Radius.circular(banner));
  static const BorderRadius brSheet = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius brHero = BorderRadius.all(Radius.circular(hero));
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

  // ---- Durations ----
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration page = Duration(milliseconds: 420);

  /// Alias of [base] — the default interaction duration.
  static const Duration normal = base;

  /// Between [base] and [slow]; for expanding panels and sheet reveals.
  static const Duration medium = Duration(milliseconds: 270);

  /// Ambient / decorative motion (hero reveals, celebration sequences).
  static const Duration verySlow = Duration(milliseconds: 640);

  /// Looping background drift (galaxy orbs, gradient flow, particles).
  static const Duration ambient = Duration(seconds: 30);

  /// Faster ambient loop for a second, closer parallax layer.
  static const Duration ambientFast = Duration(seconds: 6);

  /// Looping attention micro-interaction (bell shake, avatar glow pulse).
  static const Duration pulse = Duration(milliseconds: 2600);

  /// Looping shimmer / skeleton sweep.
  static const Duration shimmer = Duration(milliseconds: 1400);

  /// Dwell time before a carousel advances to the next slide.
  static const Duration carouselDwell = Duration(seconds: 5);

  /// Carousel slide-to-slide transition.
  static const Duration carouselSlide = Duration(milliseconds: 650);

  /// Screen entrance / staggered intro sequence.
  static const Duration intro = Duration(milliseconds: 1500);

  /// Slow breathing loop (hero glow, premium crown pulse).
  static const Duration breathe = Duration(milliseconds: 2200);

  /// Minimum pull-to-refresh spinner dwell, so the gesture feels acknowledged
  /// even when the refresh resolves instantly.
  static const Duration refreshDwell = Duration(milliseconds: 800);

  /// How long a transient snackbar stays on screen.
  static const Duration snackbar = Duration(seconds: 2);

  /// Confetti / celebration burst — longer than [burst] so pieces fall fully.
  static const Duration confetti = Duration(milliseconds: 1600);

  /// Window for a double-tap-to-exit gesture. A UX threshold, not an easing.
  static const Duration doubleTapExit = Duration(seconds: 2);

  /// Gap between beats in a two-stage haptic pattern.
  static const Duration hapticGap = Duration(milliseconds: 110);

  /// Per-item delay in a staggered list/grid entrance.
  static const Duration staggerStep = Duration(milliseconds: 70);

  /// Cap on accumulated stagger delay, so long lists never make the user wait.
  static const Duration staggerCap = Duration(milliseconds: 700);

  /// Keystroke debounce before running a live search.
  static const Duration searchDebounce = Duration(milliseconds: 160);

  /// Settle delay before reporting a search query to analytics, so every
  /// intermediate keystroke is not logged as its own query.
  static const Duration analyticsDebounce = Duration(milliseconds: 900);

  // ---- Curves ----

  /// Symmetric easing for cross-fades / color transitions.
  static const Curve standard = Curves.easeInOutCubic;

  /// Standard easing for enter/settle motion.
  static const Curve easeOut = Curves.easeOutCubic;

  /// Accelerating exit motion.
  static const Curve easeIn = Curves.easeInCubic;

  /// Plain symmetric ease.
  static const Curve ease = Curves.ease;

  /// Symmetric accelerate-then-decelerate.
  static const Curve easeInOut = Curves.easeInOut;

  /// No easing — also the reduce-motion substitute for spring/elastic/bounce.
  static const Curve linear = Curves.linear;

  /// Emphasized, springy easing for interactive press/scale.
  static const Curve emphasized = Curves.easeOutBack;

  /// Overshoot-and-settle — morphing buttons, FAB expansion.
  static const Curve spring = Curves.easeOutBack;

  /// Pronounced oscillation — success celebrations, attention pulls.
  static const Curve elastic = Curves.elasticOut;

  /// Drop-and-bounce — confetti, dropped-file landing.
  static const Curve bounce = Curves.bounceOut;

  /// Decelerating entrance for content arriving from offscreen.
  static const Curve decelerate = Curves.decelerate;

  // ---- Reduce-motion helpers ----

  /// Whether the user has asked for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [preferred] unless the user has disabled animations.
  static Duration of(BuildContext context, Duration preferred) {
    return reduced(context) ? Duration.zero : preferred;
  }

  /// Returns [preferred] unless reduced motion is on, in which case a linear
  /// curve avoids overshoot/bounce for motion-sensitive users.
  static Curve curveOf(BuildContext context, Curve preferred) {
    return reduced(context) ? Curves.linear : preferred;
  }

  /// Staggered list/grid entrance delay for item [index], capped so long
  /// lists do not accumulate multi-second delays.
  static Duration stagger(
    BuildContext context,
    int index, {
    Duration step = const Duration(milliseconds: 40),
    int maxItems = 12,
  }) {
    if (reduced(context)) return Duration.zero;
    final i = index.clamp(0, maxItems);
    return step * i;
  }
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

  // ---- Numbered shadow levels (0–5), for when a surface has no obvious
  // semantic role. level0 = flat, level5 = modal/dialog. ----

  static const List<BoxShadow> level0 = [];

  static List<BoxShadow> level(AppPalette p, int n) {
    switch (n.clamp(0, 5)) {
      case 0:
        return level0;
      case 1:
        return _shadow(p, blur: 10, spread: -4, dy: 4, darkA: 0.40, lightA: 0.06);
      case 2:
        return card(p);
      case 3:
        return _shadow(p, blur: 24, spread: -6, dy: 12, darkA: 0.55, lightA: 0.10);
      case 4:
        return raised(p);
      default:
        return _shadow(p, blur: 48, spread: -12, dy: 24, darkA: 0.65, lightA: 0.16);
    }
  }

  static List<BoxShadow> _shadow(
    AppPalette p, {
    required double blur,
    required double spread,
    required double dy,
    required double darkA,
    required double lightA,
  }) =>
      [
        BoxShadow(
          color: p.isDark
              ? const Color(0xFF000000).withValues(alpha: darkA)
              : const Color(0xFF181330).withValues(alpha: lightA),
          blurRadius: blur,
          spreadRadius: spread,
          offset: Offset(0, dy),
        ),
      ];
}

/// Surface elevation tiers — the *fill* that pairs with a shadow level.
///
/// Material 3 conveys elevation with tonal surface color as well as shadow;
/// these give the matching fill so a raised card reads correctly in both
/// themes without hardcoding a surface color.
class Surfaces {
  Surfaces._();

  /// Page background.
  static Color level0(AppPalette p) => p.bg;

  /// Resting card / list tile.
  static Color level1(AppPalette p) => p.surface;

  /// Raised card, input field, selected row.
  static Color level2(AppPalette p) => p.surface2;

  /// Menu, popover, bottom sheet.
  static Color level3(AppPalette p) =>
      Color.lerp(p.surface2, p.isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
          p.isDark ? 0.04 : 0.02)!;

  /// Dialog / modal — the topmost opaque tier.
  static Color level4(AppPalette p) =>
      Color.lerp(p.surface2, p.isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
          p.isDark ? 0.07 : 0.04)!;
}

/// Glassmorphism tiers — blur + fill + border, resolved per theme.
///
/// Pair with a `BackdropFilter(filter: ImageFilter.blur(sigmaX: t.blur, …))`.
class Glass {
  const Glass._(this.blur, this.fillAlpha, this.borderAlpha);

  final double blur;
  final double fillAlpha;
  final double borderAlpha;

  /// Barely-there frost — sticky headers over scrolling content.
  static const Glass subtle = Glass._(Blurs.subtle, 0.55, 0.10);

  /// Standard glass card / panel.
  static const Glass standard = Glass._(Blurs.glass, 0.70, 0.16);

  /// Heavy frost — modal scrims, nav bars over vivid backdrops.
  static const Glass heavy = Glass._(Blurs.heavy, 0.82, 0.22);

  /// The translucent fill for this tier.
  Color fill(AppPalette p) => p.surface.withValues(
        alpha: p.isDark ? fillAlpha : (fillAlpha + 0.18).clamp(0.0, 1.0),
      );

  /// The hairline border for this tier.
  Color border(AppPalette p) => (p.isDark
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF181330))
      .withValues(alpha: borderAlpha);
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
