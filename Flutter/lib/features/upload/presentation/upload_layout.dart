import 'package:flutter/widgets.dart';

/// Device size classes for the upload experience.
///
/// Derived from the **shortest side** rather than width, so a phone in
/// landscape stays a phone and a tablet in portrait stays a tablet. Using raw
/// width here is the classic bug that makes a landscape phone render the
/// desktop layout on a 5-inch screen.
enum UploadSizeClass {
  /// < 360 shortest side — small/older phones, and foldables while folded.
  compactPhone,

  /// 360–600 — mainstream phones.
  phone,

  /// 600–840 — large foldables unfolded, small tablets.
  foldable,

  /// 840–1024 — tablets.
  tablet,

  /// 1024–1440 — laptops, tablet + keyboard, small desktop windows.
  laptop,

  /// 1440–1920 — desktops.
  desktop,

  /// ≥ 1920 — ultrawide.
  ultrawide;

  static UploadSizeClass of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final short = size.shortestSide;
    // Width still matters for pane count — a narrow desktop *window* should
    // behave like a tablet even on a large display.
    final width = size.width;

    if (short < 360) return UploadSizeClass.compactPhone;
    if (short < 600) return UploadSizeClass.phone;
    if (width < 840) return UploadSizeClass.foldable;
    if (width < 1024) return UploadSizeClass.tablet;
    if (width < 1440) return UploadSizeClass.laptop;
    if (width < 1920) return UploadSizeClass.desktop;
    return UploadSizeClass.ultrawide;
  }

  bool get isHandset =>
      this == compactPhone || this == phone;
  bool get isTabletClass => this == foldable || this == tablet;
  bool get isDesktopClass =>
      this == laptop || this == desktop || this == ultrawide;

  /// How many panes the workspace shows.
  ///
  /// 1 — hero over queue (handset)
  /// 2 — hero | queue (tablet)
  /// 3 — sources | hero | queue (desktop)
  int get panes {
    if (isHandset) return 1;
    if (isTabletClass) return 2;
    return 3;
  }
}

/// Per-size-class measurements for the upload workspace.
///
/// Every dimension the layout needs lives here rather than being sprinkled
/// through the widget tree, so "different size on each device" is one table
/// you can read and tune, not a scavenger hunt through build methods.
@immutable
class UploadMetrics {
  const UploadMetrics({
    required this.sizeClass,
    required this.heroMaxWidth,
    required this.heroMinHeight,
    required this.heroMaxHeight,
    required this.heroFlex,
    required this.queueFlex,
    required this.railWidth,
    required this.queuePanelWidth,
    required this.showStatsStrip,
    required this.showSourceRail,
    required this.showExtendedFab,
  });

  final UploadSizeClass sizeClass;

  /// Hard cap on stage width — the art stops growing past this so it never
  /// dominates an ultrawide display.
  final double heroMaxWidth;

  /// Floor and ceiling on stage height.
  final double heroMinHeight;
  final double heroMaxHeight;

  /// Flex weights when hero and queue share an axis.
  final int heroFlex;
  final int queueFlex;

  /// Fixed widths for the desktop chrome.
  final double railWidth;
  final double queuePanelWidth;

  final bool showStatsStrip;
  final bool showSourceRail;
  final bool showExtendedFab;

  static UploadMetrics of(BuildContext context) =>
      forClass(UploadSizeClass.of(context));

  static UploadMetrics forClass(UploadSizeClass c) {
    switch (c) {
      case UploadSizeClass.compactPhone:
        return const UploadMetrics(
          sizeClass: UploadSizeClass.compactPhone,
          heroMaxWidth: 300,
          heroMinHeight: 200,
          heroMaxHeight: 300,
          heroFlex: 4,
          queueFlex: 5,
          railWidth: 0,
          queuePanelWidth: 0,
          showStatsStrip: false,
          showSourceRail: false,
          showExtendedFab: true,
        );
      case UploadSizeClass.phone:
        return const UploadMetrics(
          sizeClass: UploadSizeClass.phone,
          heroMaxWidth: 380,
          heroMinHeight: 260,
          heroMaxHeight: 400,
          heroFlex: 5,
          queueFlex: 4,
          railWidth: 0,
          queuePanelWidth: 0,
          showStatsStrip: false,
          showSourceRail: false,
          showExtendedFab: true,
        );
      case UploadSizeClass.foldable:
        return const UploadMetrics(
          sizeClass: UploadSizeClass.foldable,
          heroMaxWidth: 420,
          heroMinHeight: 300,
          heroMaxHeight: 480,
          heroFlex: 5,
          queueFlex: 4,
          railWidth: 0,
          queuePanelWidth: 0,
          showStatsStrip: true,
          showSourceRail: false,
          showExtendedFab: true,
        );
      case UploadSizeClass.tablet:
        return const UploadMetrics(
          sizeClass: UploadSizeClass.tablet,
          heroMaxWidth: 460,
          heroMinHeight: 320,
          heroMaxHeight: 540,
          heroFlex: 5,
          queueFlex: 4,
          railWidth: 0,
          queuePanelWidth: 0,
          showStatsStrip: true,
          showSourceRail: false,
          showExtendedFab: false,
        );
      case UploadSizeClass.laptop:
        return const UploadMetrics(
          sizeClass: UploadSizeClass.laptop,
          heroMaxWidth: 480,
          heroMinHeight: 340,
          heroMaxHeight: 600,
          heroFlex: 5,
          queueFlex: 4,
          railWidth: 216,
          queuePanelWidth: 340,
          showStatsStrip: true,
          showSourceRail: true,
          showExtendedFab: false,
        );
      case UploadSizeClass.desktop:
        return const UploadMetrics(
          sizeClass: UploadSizeClass.desktop,
          heroMaxWidth: 540,
          heroMinHeight: 380,
          heroMaxHeight: 680,
          heroFlex: 5,
          queueFlex: 4,
          railWidth: 232,
          queuePanelWidth: 380,
          showStatsStrip: true,
          showSourceRail: true,
          showExtendedFab: false,
        );
      case UploadSizeClass.ultrawide:
        return const UploadMetrics(
          sizeClass: UploadSizeClass.ultrawide,
          heroMaxWidth: 600,
          heroMinHeight: 420,
          heroMaxHeight: 760,
          heroFlex: 4,
          queueFlex: 3,
          railWidth: 260,
          queuePanelWidth: 440,
          showStatsStrip: true,
          showSourceRail: true,
          showExtendedFab: false,
        );
    }
  }

  /// Metrics for the hero when embedded in a tool screen rather than filling
  /// the upload workspace — deliberately smaller so it frames the tool's own
  /// controls instead of competing with them.
  UploadMetrics get embedded => UploadMetrics(
        sizeClass: sizeClass,
        heroMaxWidth: sizeClass.isHandset ? 240 : 300,
        heroMinHeight: sizeClass.isHandset ? 160 : 200,
        heroMaxHeight: sizeClass.isHandset ? 220 : 280,
        heroFlex: heroFlex,
        queueFlex: queueFlex,
        railWidth: 0,
        queuePanelWidth: 0,
        showStatsStrip: false,
        showSourceRail: false,
        showExtendedFab: false,
      );
}
