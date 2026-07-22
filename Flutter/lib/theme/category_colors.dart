/// Farvixo Enterprise Design System v10 — per-category color identity.
///
/// Every tool category owns a **completely distinct visual identity**: its own
/// hue band, gradient, tint, border and glow, resolved separately for light and
/// dark themes. Screens never read a raw `Color` — they resolve an identity and
/// ask it for the exact role they need:
///
/// ```dart
/// final id = CategoryColors.of(tool.categoryId);
/// final accent = id.accentOf(context);
/// Container(
///   decoration: BoxDecoration(
///     gradient: id.surfaceGradient(context),
///     border: Border.all(color: id.border(context)),
///     boxShadow: id.glow(context),
///   ),
/// );
/// ```
///
/// Unknown / future category ids fall back to a deterministic slot on the hue
/// wheel, so a backend-added category still gets a stable, unique color instead
/// of a grey default.
///
/// Pure tokens — importing this file changes no runtime behavior on its own.
library;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_palette.dart';

/// The full color identity for one tool category.
@immutable
class CategoryIdentity {
  const CategoryIdentity({
    required this.id,
    required this.label,
    required this.dark,
    required this.light,
    required this.deep,
    required this.companion,
  });

  /// Category slug (`pdf`, `image`, `ai`, …) — matches `ToolCategory.id`.
  final String id;

  /// Human-readable identity name (`Crimson`, `Emerald`, …) for docs/debug.
  final String label;

  /// Base hue, tuned for dark surfaces.
  final Color dark;

  /// Darkened twin that holds AA contrast on light surfaces.
  final Color light;

  /// Gradient end / pressed / deepest stop.
  final Color deep;

  /// Second gradient stop — a neighbouring hue that keeps each category's
  /// gradient unique even when two bases are adjacent.
  final Color companion;

  // ---------------------------------------------------------------------
  // Brightness-aware resolvers
  // ---------------------------------------------------------------------

  /// Primary accent for the given brightness.
  Color accent(bool isDark) => isDark ? dark : light;

  /// Primary accent resolved from context.
  Color accentOf(BuildContext context) => accent(AppPalette.of(context).isDark);

  /// Icon / label color — same as [accent], named for intent.
  Color ink(BuildContext context) => accentOf(context);

  /// Low-alpha fill for icon chips, badges and pills.
  Color tint(BuildContext context) {
    final isDark = AppPalette.of(context).isDark;
    return accent(isDark).withValues(alpha: isDark ? 0.16 : 0.10);
  }

  /// Even softer wash for large surfaces (hero headers, section backgrounds).
  Color wash(BuildContext context) {
    final isDark = AppPalette.of(context).isDark;
    return accent(isDark).withValues(alpha: isDark ? 0.08 : 0.05);
  }

  /// Hairline border that reads as "this belongs to the category".
  Color border(BuildContext context) {
    final isDark = AppPalette.of(context).isDark;
    return accent(isDark).withValues(alpha: isDark ? 0.34 : 0.24);
  }

  /// Strong two-stop gradient for CTAs, hero icons and progress fills.
  LinearGradient gradient(
    BuildContext context, {
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    final isDark = AppPalette.of(context).isDark;
    return LinearGradient(
      begin: begin,
      end: end,
      colors: isDark
          ? [dark, companion]
          : [light, deep],
    );
  }

  /// Translucent gradient for card / panel backgrounds — carries the category
  /// identity without fighting the text on top.
  LinearGradient surfaceGradient(
    BuildContext context, {
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    final isDark = AppPalette.of(context).isDark;
    final a = accent(isDark);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        a.withValues(alpha: isDark ? 0.18 : 0.10),
        companion.withValues(alpha: isDark ? 0.06 : 0.03),
      ],
    );
  }

  /// Colored ambient glow used under cards, FABs and hero icons.
  List<BoxShadow> glow(BuildContext context, {double strength = 1}) {
    final isDark = AppPalette.of(context).isDark;
    final a = accent(isDark);
    return [
      BoxShadow(
        color: a.withValues(alpha: (isDark ? 0.28 : 0.18) * strength),
        blurRadius: 28 * strength,
        spreadRadius: -10,
        offset: Offset(0, 12 * strength),
      ),
    ];
  }

  /// Subtle resting shadow for grid tiles (cheaper than [glow]).
  List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = AppPalette.of(context).isDark;
    return [
      BoxShadow(
        color: accent(isDark).withValues(alpha: isDark ? 0.10 : 0.07),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  /// Foreground color guaranteed readable on top of [gradient].
  Color onGradient(BuildContext context) => const Color(0xFFFFFFFF);
}

/// Registry + resolver for every category identity.
class CategoryColors {
  CategoryColors._();

  // ---------------------------------------------------------------------
  // Core 8 — the shipped catalog
  // ---------------------------------------------------------------------

  static const CategoryIdentity pdf = CategoryIdentity(
    id: 'pdf',
    label: 'Crimson',
    dark: AppColors.accentPdf,
    light: AppColors.accentPdfLight,
    deep: AppColors.accentPdfDeep,
    companion: AppColors.accentSecurity, // red → rose
  );

  static const CategoryIdentity image = CategoryIdentity(
    id: 'image',
    label: 'Emerald',
    dark: AppColors.accentImage,
    light: AppColors.accentImageLight,
    deep: AppColors.accentImageDeep,
    companion: AppColors.accentOcr, // emerald → teal
  );

  static const CategoryIdentity video = CategoryIdentity(
    id: 'video',
    label: 'Amethyst',
    dark: AppColors.accentVideo,
    light: AppColors.accentVideoLight,
    deep: AppColors.accentVideoDeep,
    companion: AppColors.accentQr, // purple → indigo
  );

  static const CategoryIdentity audio = CategoryIdentity(
    id: 'audio',
    label: 'Ember',
    dark: AppColors.accentAudio,
    light: AppColors.accentAudioLight,
    deep: AppColors.accentAudioDeep,
    companion: AppColors.accentPdf, // orange → red
  );

  static const CategoryIdentity ai = CategoryIdentity(
    id: 'ai',
    label: 'Fuchsia',
    dark: AppColors.accentAi,
    light: AppColors.accentAiLight,
    deep: AppColors.accentAiDeep,
    companion: AppColors.accentVideo, // fuchsia → purple
  );

  static const CategoryIdentity dev = CategoryIdentity(
    id: 'dev',
    label: 'Azure',
    dark: AppColors.accentDev,
    light: AppColors.accentDevLight,
    deep: AppColors.accentDevDeep,
    companion: AppColors.accentScanner, // blue → sky
  );

  static const CategoryIdentity text = CategoryIdentity(
    id: 'text',
    label: 'Cyan',
    dark: AppColors.accentText,
    light: AppColors.accentTextLight,
    deep: AppColors.accentTextDeep,
    companion: AppColors.accentOcr, // cyan → teal
  );

  static const CategoryIdentity utility = CategoryIdentity(
    id: 'utility',
    label: 'Graphite',
    dark: AppColors.accentUtility,
    light: AppColors.accentUtilityLight,
    deep: AppColors.accentUtilityDeep,
    companion: AppColors.accentCloud, // slate → mist
  );

  // ---------------------------------------------------------------------
  // Extended set — pending / future categories
  // ---------------------------------------------------------------------

  static const CategoryIdentity ocr = CategoryIdentity(
    id: 'ocr',
    label: 'Teal',
    dark: AppColors.accentOcr,
    light: AppColors.accentOcrLight,
    deep: AppColors.accentOcrDeep,
    companion: AppColors.accentText,
  );

  static const CategoryIdentity qr = CategoryIdentity(
    id: 'qr',
    label: 'Indigo',
    dark: AppColors.accentQr,
    light: AppColors.accentQrLight,
    deep: AppColors.accentQrDeep,
    companion: AppColors.accentCalculator,
  );

  static const CategoryIdentity scanner = CategoryIdentity(
    id: 'scanner',
    label: 'Sky',
    dark: AppColors.accentScanner,
    light: AppColors.accentScannerLight,
    deep: AppColors.accentScannerDeep,
    companion: AppColors.accentText,
  );

  static const CategoryIdentity security = CategoryIdentity(
    id: 'security',
    label: 'Rose',
    dark: AppColors.accentSecurity,
    light: AppColors.accentSecurityLight,
    deep: AppColors.accentSecurityDeep,
    companion: AppColors.accentAi,
  );

  static const CategoryIdentity finance = CategoryIdentity(
    id: 'finance',
    label: 'Jade',
    dark: AppColors.accentFinance,
    light: AppColors.accentFinanceLight,
    deep: AppColors.accentFinanceDeep,
    companion: AppColors.accentConverter,
  );

  static const CategoryIdentity business = CategoryIdentity(
    id: 'business',
    label: 'Amber',
    dark: AppColors.accentBusiness,
    light: AppColors.accentBusinessLight,
    deep: AppColors.accentBusinessDeep,
    companion: AppColors.accentAudio,
  );

  static const CategoryIdentity government = CategoryIdentity(
    id: 'government',
    label: 'Navy',
    dark: AppColors.accentGovernment,
    light: AppColors.accentGovernmentLight,
    deep: AppColors.accentGovernmentDeep,
    companion: AppColors.accentQr,
  );

  static const CategoryIdentity converter = CategoryIdentity(
    id: 'converter',
    label: 'Lime',
    dark: AppColors.accentConverter,
    light: AppColors.accentConverterLight,
    deep: AppColors.accentConverterDeep,
    companion: AppColors.accentFinance,
  );

  static const CategoryIdentity calculator = CategoryIdentity(
    id: 'calculator',
    label: 'Violet',
    dark: AppColors.accentCalculator,
    light: AppColors.accentCalculatorLight,
    deep: AppColors.accentCalculatorDeep,
    companion: AppColors.accentQr,
  );

  static const CategoryIdentity notes = CategoryIdentity(
    id: 'notes',
    label: 'Blossom',
    dark: AppColors.accentNotes,
    light: AppColors.accentNotesLight,
    deep: AppColors.accentNotesDeep,
    companion: AppColors.accentAi,
  );

  static const CategoryIdentity cloud = CategoryIdentity(
    id: 'cloud',
    label: 'Stone',
    dark: AppColors.accentCloud,
    light: AppColors.accentCloudLight,
    deep: AppColors.accentCloudDeep,
    companion: AppColors.accentBusiness,
  );

  /// Lightning Upload — electric blue with a lightning-orange companion.
  ///
  /// This is a **component** identity, not a tool category: it is intentionally
  /// excluded from [_wheel] so it never gets auto-assigned to a backend slug.
  static const CategoryIdentity upload = CategoryIdentity(
    id: 'upload',
    label: 'Lightning',
    dark: AppColors.accentUpload,
    light: AppColors.accentUploadLight,
    deep: AppColors.accentUploadDeep,
    companion: AppColors.lightningOrange,
  );

  // ---------------------------------------------------------------------
  // Brand component identities — app surfaces, not tool categories.
  //
  // Like [upload], these are excluded from [registry] and [_wheel] so a
  // backend slug can never be auto-assigned a brand colour. Reference them as
  // constants: `CategoryColors.favorite.accentOf(context)`.
  // ---------------------------------------------------------------------

  /// Farvixo violet — brand shortcuts, recent activity, generic app surfaces.
  static const CategoryIdentity brand = CategoryIdentity(
    id: 'brand',
    label: 'Farvixo Violet',
    dark: AppColors.accentBrand,
    light: AppColors.accentBrandLight,
    deep: AppColors.accentBrandDeep,
    companion: AppColors.accentFavorite,
  );

  /// Favorites / saved collections.
  static const CategoryIdentity favorite = CategoryIdentity(
    id: 'favorite',
    label: 'Magenta',
    dark: AppColors.accentFavorite,
    light: AppColors.accentFavoriteLight,
    deep: AppColors.accentFavoriteDeep,
    companion: AppColors.accentNotes,
  );

  /// Premium / Pro / upgrade surfaces.
  static const CategoryIdentity premium = CategoryIdentity(
    id: 'premium',
    label: 'Gold',
    dark: AppColors.accentPremium,
    light: AppColors.accentPremiumLight,
    deep: AppColors.accentPremiumDeep,
    companion: AppColors.lightningOrange,
  );

  /// Every registered identity, keyed by category slug.
  static const Map<String, CategoryIdentity> registry = {
    'pdf': pdf,
    'image': image,
    'video': video,
    'audio': audio,
    'ai': ai,
    'dev': dev,
    'text': text,
    'utility': utility,
    'ocr': ocr,
    'qr': qr,
    'scanner': scanner,
    'security': security,
    'finance': finance,
    'business': business,
    'government': government,
    'converter': converter,
    'calculator': calculator,
    'notes': notes,
    'cloud': cloud,
    'upload': upload,
  };

  /// Aliases so backend slugs, legacy ids and accent tokens all resolve.
  static const Map<String, String> _aliases = {
    'accent-pdf': 'pdf',
    'accent-image': 'image',
    'accent-video': 'video',
    'accent-audio': 'audio',
    'accent-ai': 'ai',
    'accent-dev': 'dev',
    'accent-text': 'text',
    'accent-utility': 'utility',
    'documents': 'pdf',
    'document': 'pdf',
    'photo': 'image',
    'images': 'image',
    'media': 'video',
    'music': 'audio',
    'sound': 'audio',
    'artificial-intelligence': 'ai',
    'developer': 'dev',
    'developer-tools': 'dev',
    'code': 'dev',
    'writing': 'text',
    'utilities': 'utility',
    'misc': 'utility',
    'other': 'utility',
    'privacy': 'security',
    'encryption': 'security',
    'money': 'finance',
    'tax': 'finance',
    'gov': 'government',
    'legal': 'government',
    'office': 'business',
    'convert': 'converter',
    'converters': 'converter',
    'math': 'calculator',
    'notebook': 'notes',
    'storage': 'cloud',
    'drive': 'cloud',
    'barcode': 'qr',
    'scan': 'scanner',
  };

  /// Deterministic hue wheel for categories the registry has never seen —
  /// a backend-added slug still lands on a stable, distinct color.
  static const List<CategoryIdentity> _wheel = [
    security,
    business,
    converter,
    ocr,
    scanner,
    qr,
    calculator,
    notes,
    finance,
    government,
  ];

  /// Resolve the identity for a category slug. Never returns null.
  static CategoryIdentity of(String? categoryId) {
    final key = categoryId?.trim().toLowerCase() ?? '';
    if (key.isEmpty) return utility;

    final direct = registry[key];
    if (direct != null) return direct;

    final aliased = _aliases[key];
    if (aliased != null) return registry[aliased] ?? utility;

    // Stable FNV-1a hash → fixed wheel slot.
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = (hash ^ unit) * 0x01000193;
      hash &= 0xFFFFFFFF;
    }
    return _wheel[hash % _wheel.length];
  }

  /// Convenience: primary accent for a slug, resolved against the theme.
  static Color accentOf(BuildContext context, String? categoryId) =>
      of(categoryId).accentOf(context);
}

/// Ergonomic sugar: `context.categoryColor('pdf')`.
extension CategoryColorContext on BuildContext {
  CategoryIdentity categoryIdentity(String? categoryId) =>
      CategoryColors.of(categoryId);

  Color categoryColor(String? categoryId) =>
      CategoryColors.of(categoryId).accentOf(this);
}
