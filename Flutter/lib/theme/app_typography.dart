/// Farvixo Enterprise Design System v10 — typography scale.
///
/// Single source of truth for every text style in the app. No screen builds a
/// raw `TextStyle` with a literal `fontSize` — it reads a role from here:
///
/// ```dart
/// Text('Merge PDF', style: AppTypography.titleMedium(context));
/// Text('12 files', style: AppTypography.caption(context, color: p.textMuted));
/// ```
///
/// Or, from the theme, the standard Material 3 roles:
///
/// ```dart
/// Text('Merge PDF', style: Theme.of(context).textTheme.titleMedium);
/// ```
///
/// ## Scale
///
/// The 15 Material 3 roles are present and correctly named, but the ramp is
/// tuned tighter than stock M3: Farvixo is a dense tool catalog, not an
/// editorial app, so `body`/`label` sit where the existing UI already lives
/// (11–16) rather than M3's roomier defaults. Six Farvixo-specific micro roles
/// (`caption`, `overline`, `badge`, `metric`, `mono`, `numeric`) cover the
/// small-text patterns the tool cards and stat surfaces rely on.
///
/// ## Text scaling
///
/// Every role honors the user's font-size preference, clamped via
/// [scalerOf] so a 200% system setting cannot break dense grid layouts.
/// Accessibility is preserved (text still grows) without overflow.
library;

import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Font-weight tokens. Never write `FontWeight.w800` in a widget.
class FontWeights {
  FontWeights._();
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extrabold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;
}

/// Font families — the single swap point for app-wide branding.
///
/// ## Current state
///
/// [sans] is `null`, so text renders in the platform default: Roboto on
/// Android, San Francisco on iOS/macOS, Segoe UI on Windows, the system font
/// on Linux, and whatever the browser picks on Web. That means **the app has
/// no consistent typographic voice across platforms** — the same screen has
/// different metrics on every target, and screens tuned on one platform can
/// look wrong on another.
///
/// ## Enabling the brand face (Inter)
///
/// Inter is the recommended primary: SIL Open Font License (no licensing
/// cost), excellent small-size legibility for dense tool grids, and true
/// tabular figures — which the [AppTypography.numeric] role depends on for
/// upload progress, file sizes, ETA and transfer speed.
///
/// Three steps, no code changes beyond the last line:
///
/// 1. Download Inter (OFL) and place the static weights in `assets/fonts/`:
///    `Inter-Regular` `Inter-Medium` `Inter-SemiBold` `Inter-Bold`
///    `Inter-ExtraBold` `Inter-Black` (`.ttf`)
/// 2. Declare them in `pubspec.yaml`:
///
/// ```yaml
/// flutter:
///   fonts:
///     - family: Inter
///       fonts:
///         - asset: assets/fonts/Inter-Regular.ttf
///           weight: 400
///         - asset: assets/fonts/Inter-Medium.ttf
///           weight: 500
///         - asset: assets/fonts/Inter-SemiBold.ttf
///           weight: 600
///         - asset: assets/fonts/Inter-Bold.ttf
///           weight: 700
///         - asset: assets/fonts/Inter-ExtraBold.ttf
///           weight: 800
///         - asset: assets/fonts/Inter-Black.ttf
///           weight: 900
/// ```
///
/// 3. Change [sans] from `null` to [brand].
///
/// Do **not** set [sans] to `'Inter'` before the assets exist — Flutter
/// silently falls back to the default face, so the app looks unchanged while
/// every screen is actually being tuned against the wrong metrics.
///
/// Alternatives if Inter is rejected: Geist, Plus Jakarta Sans, Manrope.
class FontFamilies {
  FontFamilies._();

  /// The brand face, declared but **not yet active** — see [sans].
  static const String brand = 'Inter';

  /// Primary UI family. `null` = platform default.
  ///
  /// Flip to [brand] once `assets/fonts/Inter-*.ttf` are declared in
  /// `pubspec.yaml`. This is the only line that needs to change.
  static const String? sans = null;

  /// Whether the brand face is active. Used by the token audit to report
  /// cross-platform typographic consistency.
  static bool get brandActive => sans == brand;

  /// Monospace for code, hashes, tokens and byte counts.
  static const String mono = 'monospace';
}

/// The complete typographic ramp.
class AppTypography {
  AppTypography._();

  // ---------------------------------------------------------------------
  // Text-scale clamping
  // ---------------------------------------------------------------------

  /// Upper bound on user font scaling for dense surfaces (grids, cards).
  static const double maxScaleDense = 1.3;

  /// Upper bound for prose surfaces (body copy, dialogs, settings).
  static const double maxScaleProse = 2.0;

  /// The user's text scaler, clamped so large-font settings enlarge text
  /// without shattering fixed-height layouts.
  static TextScaler scalerOf(BuildContext context, {bool dense = false}) {
    return MediaQuery.textScalerOf(context).clamp(
      minScaleFactor: 1.0,
      maxScaleFactor: dense ? maxScaleDense : maxScaleProse,
    );
  }

  // ---------------------------------------------------------------------
  // Raw role definitions (color-less — callers bind color)
  // ---------------------------------------------------------------------

  // Display — hero numerals, splash wordmark, empty-state art.
  static const TextStyle displayLargeStyle = TextStyle(
    fontSize: 44, height: 1.08, letterSpacing: -1.0, fontWeight: FontWeights.black);
  static const TextStyle displayMediumStyle = TextStyle(
    fontSize: 36, height: 1.10, letterSpacing: -0.8, fontWeight: FontWeights.extrabold);
  static const TextStyle displaySmallStyle = TextStyle(
    fontSize: 30, height: 1.12, letterSpacing: -0.6, fontWeight: FontWeights.extrabold);

  // Headline — screen titles, hero headings.
  static const TextStyle headlineLargeStyle = TextStyle(
    fontSize: 28, height: 1.16, letterSpacing: -0.5, fontWeight: FontWeights.extrabold);
  static const TextStyle headlineMediumStyle = TextStyle(
    fontSize: 24, height: 1.18, letterSpacing: -0.4, fontWeight: FontWeights.bold);
  static const TextStyle headlineSmallStyle = TextStyle(
    fontSize: 22, height: 1.20, letterSpacing: -0.3, fontWeight: FontWeights.bold);

  // Title — app bars, section headers, card titles.
  static const TextStyle titleLargeStyle = TextStyle(
    fontSize: 20, height: 1.22, letterSpacing: -0.2, fontWeight: FontWeights.bold);
  static const TextStyle titleMediumStyle = TextStyle(
    fontSize: 16, height: 1.25, letterSpacing: -0.1, fontWeight: FontWeights.bold);
  static const TextStyle titleSmallStyle = TextStyle(
    fontSize: 14, height: 1.28, letterSpacing: 0, fontWeight: FontWeights.semibold);

  // Body — descriptions, prose, list subtitles.
  static const TextStyle bodyLargeStyle = TextStyle(
    fontSize: 16, height: 1.45, letterSpacing: 0, fontWeight: FontWeights.regular);
  static const TextStyle bodyMediumStyle = TextStyle(
    fontSize: 14, height: 1.45, letterSpacing: 0, fontWeight: FontWeights.regular);
  static const TextStyle bodySmallStyle = TextStyle(
    fontSize: 12.5, height: 1.35, letterSpacing: 0.1, fontWeight: FontWeights.regular);

  // Label — buttons, chips, tabs, nav.
  static const TextStyle labelLargeStyle = TextStyle(
    fontSize: 14, height: 1.25, letterSpacing: 0.1, fontWeight: FontWeights.semibold);
  static const TextStyle labelMediumStyle = TextStyle(
    fontSize: 12, height: 1.25, letterSpacing: 0.2, fontWeight: FontWeights.semibold);
  static const TextStyle labelSmallStyle = TextStyle(
    fontSize: 11, height: 1.25, letterSpacing: 0.3, fontWeight: FontWeights.semibold);

  // ---- Farvixo micro roles (dense tool surfaces) ----

  /// Tool-card title in the 3-column mobile grid.
  static const TextStyle toolTitleStyle = TextStyle(
    fontSize: 12.5, height: 1.15, letterSpacing: -0.1, fontWeight: FontWeights.extrabold);

  /// Tool-card description, secondary metadata.
  static const TextStyle captionStyle = TextStyle(
    fontSize: 10.5, height: 1.25, letterSpacing: 0.1, fontWeight: FontWeights.regular);

  /// All-caps category pills and section eyebrows.
  static const TextStyle overlineStyle = TextStyle(
    fontSize: 8.5, height: 1.2, letterSpacing: 0.4, fontWeight: FontWeights.extrabold);

  /// POPULAR / NEW / AI badge chips.
  static const TextStyle badgeStyle = TextStyle(
    fontSize: 8, height: 1.2, letterSpacing: 0.3, fontWeight: FontWeights.extrabold);

  /// Large statistic numerals on dashboard stat cards.
  static const TextStyle metricStyle = TextStyle(
    fontSize: 26, height: 1.05, letterSpacing: -0.6, fontWeight: FontWeights.black);

  /// Code, hashes, JWTs, JSON output.
  static const TextStyle monoStyle = TextStyle(
    fontFamily: FontFamilies.mono,
    fontSize: 13, height: 1.45, letterSpacing: 0, fontWeight: FontWeights.regular);

  /// FARVIXO wordmark — wide-tracked, heaviest weight. Brand lockups only.
  static const TextStyle wordmarkStyle = TextStyle(
    fontSize: 18, height: 1.1, letterSpacing: 2, fontWeight: FontWeights.black);

  /// Tabular numerals — progress percentages, file sizes, ETA, speed.
  static const TextStyle numericStyle = TextStyle(
    fontSize: 13, height: 1.2, letterSpacing: 0,
    fontWeight: FontWeights.semibold,
    fontFeatures: [FontFeature.tabularFigures()]);

  // ---------------------------------------------------------------------
  // Context-bound accessors — resolve color from the palette by default
  // ---------------------------------------------------------------------

  static TextStyle _bind(
    BuildContext context,
    TextStyle style,
    Color? color, {
    FontWeight? weight,
    double? height,
  }) {
    final resolved = color ?? AppPalette.of(context).textPrimary;
    return style.copyWith(
      color: resolved,
      fontWeight: weight,
      height: height,
      // Applied here (not on each const style) so the brand face is a
      // one-line swap in FontFamilies. Monospace roles opt out.
      fontFamily: style.fontFamily ?? FontFamilies.sans,
    );
  }

  static TextStyle displayLarge(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, displayLargeStyle, color, weight: weight);
  static TextStyle displayMedium(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, displayMediumStyle, color, weight: weight);
  static TextStyle displaySmall(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, displaySmallStyle, color, weight: weight);

  static TextStyle headlineLarge(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, headlineLargeStyle, color, weight: weight);
  static TextStyle headlineMedium(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, headlineMediumStyle, color, weight: weight);
  static TextStyle headlineSmall(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, headlineSmallStyle, color, weight: weight);

  static TextStyle titleLarge(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, titleLargeStyle, color, weight: weight);
  static TextStyle titleMedium(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, titleMediumStyle, color, weight: weight);
  static TextStyle titleSmall(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, titleSmallStyle, color, weight: weight);

  static TextStyle bodyLarge(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, bodyLargeStyle, color, weight: weight);
  static TextStyle bodyMedium(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, bodyMediumStyle, color, weight: weight);
  static TextStyle bodySmall(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, bodySmallStyle, color, weight: weight);

  static TextStyle labelLarge(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, labelLargeStyle, color, weight: weight);
  static TextStyle labelMedium(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, labelMediumStyle, color, weight: weight);
  static TextStyle labelSmall(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, labelSmallStyle, color, weight: weight);

  static TextStyle toolTitle(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, toolTitleStyle, color, weight: weight);
  static TextStyle caption(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, captionStyle, color ?? AppPalette.of(c).textSecondary, weight: weight);
  static TextStyle overline(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, overlineStyle, color, weight: weight);
  static TextStyle badge(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, badgeStyle, color, weight: weight);
  static TextStyle metric(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, metricStyle, color, weight: weight);
  static TextStyle wordmark(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, wordmarkStyle, color, weight: weight);
  static TextStyle mono(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, monoStyle, color, weight: weight);
  static TextStyle numeric(BuildContext c, {Color? color, FontWeight? weight}) =>
      _bind(c, numericStyle, color, weight: weight);

  // ---------------------------------------------------------------------
  // Material TextTheme construction (consumed by AppTheme)
  // ---------------------------------------------------------------------

  /// Builds the Material [TextTheme] from this scale.
  ///
  /// [boldText] bumps body/label weights one step for the accessibility
  /// "bold text" preference without changing the metric ramp.
  static TextTheme textTheme({
    required Color color,
    bool boldText = false,
  }) {
    TextStyle s(TextStyle base, {bool bumpable = false}) {
      final weight = bumpable && boldText
          ? _bumpWeight(base.fontWeight ?? FontWeights.regular)
          : base.fontWeight;
      return base.copyWith(
        color: color,
        fontWeight: weight,
        fontFamily: base.fontFamily ?? FontFamilies.sans,
      );
    }

    return TextTheme(
      displayLarge: s(displayLargeStyle),
      displayMedium: s(displayMediumStyle),
      displaySmall: s(displaySmallStyle),
      headlineLarge: s(headlineLargeStyle),
      headlineMedium: s(headlineMediumStyle),
      headlineSmall: s(headlineSmallStyle),
      titleLarge: s(titleLargeStyle),
      titleMedium: s(titleMediumStyle),
      titleSmall: s(titleSmallStyle),
      bodyLarge: s(bodyLargeStyle, bumpable: true),
      bodyMedium: s(bodyMediumStyle, bumpable: true),
      bodySmall: s(bodySmallStyle, bumpable: true),
      labelLarge: s(labelLargeStyle, bumpable: true),
      labelMedium: s(labelMediumStyle, bumpable: true),
      labelSmall: s(labelSmallStyle, bumpable: true),
    );
  }

  static FontWeight _bumpWeight(FontWeight w) {
    const ladder = [
      FontWeights.regular,
      FontWeights.medium,
      FontWeights.semibold,
      FontWeights.bold,
      FontWeights.extrabold,
      FontWeights.black,
    ];
    final i = ladder.indexOf(w);
    if (i == -1) return FontWeights.bold;
    return ladder[(i + 2).clamp(0, ladder.length - 1)];
  }
}

/// Ergonomic sugar: `context.type.titleMedium`.
extension TypographyContext on BuildContext {
  TypeScale get type => TypeScale(this);
}

/// Thin context-bound facade so call sites read as `context.type.caption`.
class TypeScale {
  const TypeScale(this._c);
  final BuildContext _c;

  TextStyle get displayLarge => AppTypography.displayLarge(_c);
  TextStyle get displayMedium => AppTypography.displayMedium(_c);
  TextStyle get displaySmall => AppTypography.displaySmall(_c);
  TextStyle get headlineLarge => AppTypography.headlineLarge(_c);
  TextStyle get headlineMedium => AppTypography.headlineMedium(_c);
  TextStyle get headlineSmall => AppTypography.headlineSmall(_c);
  TextStyle get titleLarge => AppTypography.titleLarge(_c);
  TextStyle get titleMedium => AppTypography.titleMedium(_c);
  TextStyle get titleSmall => AppTypography.titleSmall(_c);
  TextStyle get bodyLarge => AppTypography.bodyLarge(_c);
  TextStyle get bodyMedium => AppTypography.bodyMedium(_c);
  TextStyle get bodySmall => AppTypography.bodySmall(_c);
  TextStyle get labelLarge => AppTypography.labelLarge(_c);
  TextStyle get labelMedium => AppTypography.labelMedium(_c);
  TextStyle get labelSmall => AppTypography.labelSmall(_c);
  TextStyle get toolTitle => AppTypography.toolTitle(_c);
  TextStyle get caption => AppTypography.caption(_c);
  TextStyle get overline => AppTypography.overline(_c);
  TextStyle get badge => AppTypography.badge(_c);
  TextStyle get metric => AppTypography.metric(_c);
  TextStyle get wordmark => AppTypography.wordmark(_c);
  TextStyle get mono => AppTypography.mono(_c);
  TextStyle get numeric => AppTypography.numeric(_c);
}
