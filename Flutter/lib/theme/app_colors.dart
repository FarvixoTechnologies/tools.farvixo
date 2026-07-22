import 'package:flutter/material.dart';

/// Farvixo design tokens — deep-space dark, violet primary, gold premium.
class AppColors {
  AppColors._();

  // Base surfaces (dark)
  static const Color bgBase = Color(0xFF0A0A12);
  static const Color bgSurface = Color(0xFF12121C);

  /// [bgSurface] at 75% opacity — translucent "glass" card surface used on
  /// screens with an animated background (Home hero/cards).
  static const Color bgSurfaceGlass = Color(0xBF12121C);
  static const Color bgSurface2 = Color(0xFF1A1A28);
  static const Color borderSubtle = Color(0xFF2A2A3C);

  // Base surfaces + text (light) — single source for the light theme, shared by
  // AppTheme.light() and AppPalette so Light/Dark/Custom stay consistent.
  static const Color lightBg = Color(0xFFF6F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFEFEFF7);
  static const Color lightBorder = Color(0xFFE3E3F0);
  static const Color lightTextPrimary = Color(0xFF1A1330);
  static const Color lightTextSecondary = Color(0xFF5A5876);
  static const Color lightTextMuted = Color(0xFF8A88A3);

  /// Dark ink for text and icons on a bright gold / premium surface, where
  /// [onAccent] white would wash out. ~87% black.
  static const Color onPremium = Color(0xDE000000);

  /// Muted dark ink on gold — captions on the premium banner. ~54% black.
  static const Color onPremiumMuted = Color(0x8A000000);

  /// Opaque black backdrop — camera viewfinders, QR canvases, modal scrims.
  ///
  /// Not theme-adaptive on purpose: a camera preview needs true black behind
  /// it in both light and dark mode, and a QR code must be pure black on pure
  /// white to stay scannable.
  static const Color scrim = Color(0xFF000000);

  /// Foreground on top of a saturated accent, gradient or shader fill.
  ///
  /// Not a "white" literal — this is the semantic on-colour. Under a
  /// [ShaderMask] the glyph colour must be opaque so the shader can replace
  /// it; this token carries that intent.
  static const Color onAccent = Color(0xFFFFFFFF);

  // Brand
  static const Color brandPrimary = Color(0xFF7C3AED);
  static const Color brandPrimaryHover = Color(0xFF8B5CF6);
  static const Color brandMagenta = Color(0xFFC026D3);
  static const Color goldPremium = Color(0xFFF5B93D);

  // Text (dark theme)
  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textSecondary = Color(0xFFA0A0B8);
  static const Color textMuted = Color(0xFF6B6B85);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  /// Destructive-action rose (sign out, delete account confirmations).
  static const Color destructive = Color(0xFFF43F5E);

  /// Deep near-black violet backdrop for immersive full-bleed screens
  /// (auth, onboarding).
  static const Color bgDeep = Color(0xFF05010F);

  // Violet tint/shade scale — decorative ink on deep violet surfaces.
  static const Color violet200 = Color(0xFFD4C4F7);
  static const Color violet300 = Color(0xFFC4B5FD);
  static const Color violet400 = Color(0xFFA78BFA);
  static const Color violet700 = Color(0xFF6D28D9);
  static const Color violet800 = Color(0xFF5B21B6);
  static const Color violet900 = Color(0xFF3B1D6E);

  // Extended hue set (accent presets, decorative gradients).
  static const Color indigo = Color(0xFF6366F1);
  static const Color teal = Color(0xFF14B8A6);
  static const Color lime = Color(0xFF84CC16);
  static const Color pinkDeep = Color(0xFFBE185D);
  static const Color blueDeep = Color(0xFF1D4ED8);
  static const Color slateMuted = Color(0xFF6B6F8E);
  static const Color silver = Color(0xFFE2E8F0);

  // Vivid hero accents — intentionally hotter than the category tokens,
  // used by the Profile hero design.
  static const Color vividPurple = Color(0xFF7B3FF2);
  static const Color vividBlue = Color(0xFF4D8DFF);
  static const Color vividPink = Color(0xFFFF4FD8);
  static const Color vividOrange = Color(0xFFFF7A3D);

  /// Soft gold tint for logo glow effects.
  static const Color goldSoft = Color(0xFFFDE68A);

  // Dark input-field neutrals (edit forms on dark surfaces).
  static const Color inputDark = Color(0xFF18181D);
  static const Color inputDarkBorder = Color(0xFF2E2E36);
  static const Color inputDarkHint = Color(0xFF71717A);

  // Zinc neutrals for the edit-profile dark layout.
  static const Color zincBase = Color(0xFF09090B);
  static const Color zincSurface = Color(0xFF15151B);

  /// Fuchsia companion to [brandPrimaryHover] in edit-profile gradients.
  static const Color fuchsia = Color(0xFFD946EF);

  /// Deep violet night tone blended into the splash background.
  static const Color violetNight = Color(0xFF1A1040);

  /// Full-spectrum hue ring for the custom accent-colour picker.
  ///
  /// A user-facing colour tool, not app theming — these are the actual hues a
  /// user drags across to choose a custom accent, so they are pure primaries.
  static const List<Color> hueWheel = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  /// Foreground swatches offered by the QR generator.
  ///
  /// A user-facing palette, not a theme: these are the actual ink colours a
  /// generated code can be printed in, so they stay identical in both themes.
  /// Dark-on-light is required for scannability — no light swatches here.
  static const List<Color> qrSwatches = [
    bgBase,
    brandPrimary,
    accentDevLight,
    accentImageLight,
    error,
  ];

  // Official file-format brand colors (converter format grid, result cards).
  //
  // Fixed like the social-brand colors below: Word is Word-blue on every
  // theme. These are identity, not palette — do not theme them.
  static const Color formatWord = Color(0xFF2B579A);
  static const Color formatExcel = Color(0xFF217346);
  static const Color formatPowerPoint = Color(0xFFC43E1C);
  static const Color formatHtml = Color(0xFFE34F26);
  static const Color formatMarkdown = Color(0xFF6366F1);
  static const Color formatRtf = Color(0xFF7C3AED);
  static const Color formatCsv = Color(0xFF0D9488);
  static const Color formatPlainText = Color(0xFF6B7280);

  // Official social-brand colors (login buttons, share sheet).
  static const Color socialGoogle = Color(0xFFEA4335);
  static const Color socialGoogleBlue = Color(0xFF4285F4);
  static const Color socialDiscord = Color(0xFF5865F2);
  static const Color socialLinkedIn = Color(0xFF0A66C2);

  // ---------------------------------------------------------------------
  // CATEGORY ACCENTS — hue-separated identity ramp.
  //
  // Every tool category owns a distinct hue band so no two categories ever
  // read the same. Each has three stops:
  //   accentX      — base hue, tuned for DARK surfaces
  //   accentXLight — darkened/saturated twin, AA-contrast on LIGHT surfaces
  //   accentXDeep  — gradient end / pressed state
  // Compose them via [CategoryIdentity] in `category_colors.dart`; never read
  // a raw accent straight into a widget.
  // ---------------------------------------------------------------------

  // — Core 8 —
  static const Color accentPdf = Color(0xFFEF4444); // crimson    ~0°
  static const Color accentPdfLight = Color(0xFFDC2626);
  static const Color accentPdfDeep = Color(0xFFB91C1C);

  static const Color accentImage = Color(0xFF10B981); // emerald  ~160°
  static const Color accentImageLight = Color(0xFF059669);
  static const Color accentImageDeep = Color(0xFF047857);

  static const Color accentVideo = Color(0xFFA855F7); // purple   ~271°
  static const Color accentVideoLight = Color(0xFF9333EA);
  static const Color accentVideoDeep = Color(0xFF7E22CE);

  static const Color accentAudio = Color(0xFFF97316); // orange    ~25°
  static const Color accentAudioLight = Color(0xFFEA580C);
  static const Color accentAudioDeep = Color(0xFFC2410C);

  static const Color accentAi = Color(0xFFD946EF); // fuchsia    ~292°
  static const Color accentAiLight = Color(0xFFC026D3);
  static const Color accentAiDeep = Color(0xFFA21CAF);

  static const Color accentDev = Color(0xFF3B82F6); // blue       ~217°
  static const Color accentDevLight = Color(0xFF2563EB);
  static const Color accentDevDeep = Color(0xFF1D4ED8);

  static const Color accentText = Color(0xFF06B6D4); // cyan      ~189°
  static const Color accentTextLight = Color(0xFF0891B2);
  static const Color accentTextDeep = Color(0xFF0E7490);

  static const Color accentUtility = Color(0xFF64748B); // slate  ~215° (low sat)
  static const Color accentUtilityLight = Color(0xFF475569);
  static const Color accentUtilityDeep = Color(0xFF334155);

  // — Extended set (OCR, QR, scanner, security, finance, business, …) —
  //
  // Nineteen categories do not fit on one hue wheel while keeping semantic
  // meaning (finance = green, security = red-family, …). So the extended set
  // separates on a SECOND axis: where a hue family is shared with a core
  // category, the extended member takes a clearly different lightness tier.
  // Verified: no two categories are confusable in either theme, and every
  // accent clears 3:1 against its own surface. See docs/CATEGORY_COLORS.md.

  static const Color accentOcr = Color(0xFF5EEAD4); // teal, light tier ~173°
  static const Color accentOcrLight = Color(0xFF115E59);
  static const Color accentOcrDeep = Color(0xFF134E4A);

  static const Color accentQr = Color(0xFF6366F1); // indigo      ~239°
  static const Color accentQrLight = Color(0xFF4F46E5);
  static const Color accentQrDeep = Color(0xFF4338CA);

  static const Color accentScanner = Color(0xFF7DD3FC); // sky, light tier ~199°
  static const Color accentScannerLight = Color(0xFF0C4A6E);
  static const Color accentScannerDeep = Color(0xFF082F49);

  static const Color accentSecurity = Color(0xFFFDA4AF); // rose, light tier ~350°
  static const Color accentSecurityLight = Color(0xFF9F1239);
  static const Color accentSecurityDeep = Color(0xFF881337);

  static const Color accentFinance = Color(0xFF22C55E); // green   ~142°
  static const Color accentFinanceLight = Color(0xFF16A34A);
  static const Color accentFinanceDeep = Color(0xFF15803D);

  static const Color accentBusiness = Color(0xFFFCD34D); // gold    ~45°
  static const Color accentBusinessLight = Color(0xFFB45309);
  static const Color accentBusinessDeep = Color(0xFF92400E);

  static const Color accentGovernment = Color(0xFFD6B25E); // bronze ~42° (low sat)
  static const Color accentGovernmentLight = Color(0xFF8A6A16);
  static const Color accentGovernmentDeep = Color(0xFF6B5210);

  static const Color accentConverter = Color(0xFF84CC16); // lime    ~84°
  static const Color accentConverterLight = Color(0xFF4D7C0F);
  static const Color accentConverterDeep = Color(0xFF3F6212);

  static const Color accentCalculator =
      Color(0xFFC4B5FD); // violet, light tier ~255°
  static const Color accentCalculatorLight = Color(0xFF5B21B6);
  static const Color accentCalculatorDeep = Color(0xFF4C1D95);

  static const Color accentNotes = Color(0xFFEC4899); // pink      ~330°
  static const Color accentNotesLight = Color(0xFFDB2777);
  static const Color accentNotesDeep = Color(0xFFBE185D);

  static const Color accentCloud = Color(0xFFA8A29E); // warm stone (low sat)
  static const Color accentCloudLight = Color(0xFF57534E);
  static const Color accentCloudDeep = Color(0xFF44403C);

  /// Lightning Upload — electric blue base with a lightning-orange companion.
  static const Color accentUpload = Color(0xFF38BDF8);
  static const Color accentUploadLight = Color(0xFF0369A1);
  static const Color accentUploadDeep = Color(0xFF075985);
  static const Color lightningOrange = Color(0xFFFFA31A);
  static const Color neonCyan = Color(0xFF22D3EE);

  // — Brand component accents —
  //
  // App-level surfaces (favorites, downloads, premium, brand shortcuts) are
  // not tool categories, but still need brightness-aware stops. The flat brand
  // colors above ([brandPrimary], [brandMagenta], [goldPremium]) render
  // identically in both themes and go muddy on light surfaces; these are their
  // theme-aware equivalents.

  static const Color accentBrand = Color(0xFFA78BFA); // violet on dark
  static const Color accentBrandLight = Color(0xFF6D28D9);
  static const Color accentBrandDeep = Color(0xFF5B21B6);

  static const Color accentFavorite = Color(0xFFE879F9); // magenta on dark
  static const Color accentFavoriteLight = Color(0xFFA21CAF);
  static const Color accentFavoriteDeep = Color(0xFF86198F);

  static const Color accentPremium = Color(0xFFFBBF24); // gold on dark
  static const Color accentPremiumLight = Color(0xFF92400E);
  static const Color accentPremiumDeep = Color(0xFF78350F);

  // Secondary spectrum accents (RGB ring, aurora headline gradient).
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentCyanBright = Color(0xFF22D3EE);

  // Lavender text/ink scale used on dark violet surfaces (hero, premium
  // banner) where the standard grey text scale reads too cold.
  static const Color lavender100 = Color(0xFFE0D5FF); // pill text
  static const Color lavender200 = Color(0xFFD8CCFF); // small icons
  static const Color lavender300 = Color(0xFFB9B2DA); // body copy
  static const Color lavender400 = Color(0xFFA9A3CC); // subtitles
  static const Color lavender500 = Color(0xFF9BA0C2); // captions / stats

  // Hero (galaxy) card surfaces.
  static const Color heroDarkTop = Color(0xFF160A33);
  static const Color heroDarkBottom = Color(0xFF0A0518);
  static const Color heroLightTop = Color(0xFFF1EBFF);
  static const Color heroLightBottom = Color(0xFFFBF7FF);

  // Premium banner surfaces.
  static const Color bannerDark1 = Color(0xFF2A0F55);
  static const Color bannerDark2 = Color(0xFF1B1040);
  static const Color bannerDark3 = Color(0xFF3A2408);
  static const Color bannerLight1 = Color(0xFFF3ECFF);
  static const Color bannerLight2 = Color(0xFFEDE7FF);
  static const Color bannerLight3 = Color(0xFFFCF3E4);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPrimary, brandMagenta],
  );

  /// Primary call-to-action sweep — violet → magenta → azure. Wider than
  /// [brandGradient] so it reads across a full-width button.
  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandPrimary, brandMagenta, accentDev],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5B93D), Color(0xFFD97706)],
  );

  /// Gold → magenta wordmark gradient (FARVIXO logotype, avatar ring).
  static const LinearGradient goldMagentaGradient = LinearGradient(
    colors: [goldPremium, brandMagenta],
  );

  /// Gold → pink premium headline gradient ("Farvixo Pro").
  static const LinearGradient goldPinkGradient = LinearGradient(
    colors: [goldPremium, accentPink],
  );

  /// Violet → pink → blue aurora gradient for highlighted headline words.
  static const LinearGradient auroraGradient = LinearGradient(
    colors: [brandPrimaryHover, accentPink, accentDev],
  );

  /// Violet → fuchsia → blue ring behind the profile avatar.
  static const LinearGradient profileAvatarGradient = LinearGradient(
    colors: [brandPrimaryHover, fuchsia, accentDev],
  );

  /// Same stops, diagonal — profile hero backdrop.
  static const LinearGradient profileHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPrimaryHover, fuchsia, accentDev],
  );

  /// Full-spectrum sweep for the rotating RGB ring.
  static const List<Color> rgbRingColors = [
    goldPremium,
    accentPink,
    brandPrimaryHover,
    accentDev,
    accentCyanBright,
    goldPremium,
  ];

  /// Hero galaxy card gradient per brightness.
  static const List<Color> heroCardDark = [heroDarkTop, heroDarkBottom];
  static const List<Color> heroCardLight = [heroLightTop, heroLightBottom];

  /// Premium banner gradient per brightness.
  static const List<Color> premiumBannerDark = [
    bannerDark1,
    bannerDark2,
    bannerDark3,
  ];
  static const List<Color> premiumBannerLight = [
    bannerLight1,
    bannerLight2,
    bannerLight3,
  ];
}
