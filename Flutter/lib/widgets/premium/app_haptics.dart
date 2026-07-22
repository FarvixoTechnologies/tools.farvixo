/// Farvixo haptic vocabulary — one named pattern per UI moment so the whole
/// app "feels" consistent. Feature code calls `AppHaptics.success()` instead
/// of picking a raw [HapticFeedback] primitive, which keeps the physical
/// language as unified as the visual one.
library;

import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

class AppHaptics {
  AppHaptics._();

  /// Master switch — settings can flip this off without touching call sites.
  static bool enabled = true;

  /// Light tick — chip select, toggle, slider detent, tab change.
  static void tick() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  /// Soft tap — card press, list item tap.
  static void tap() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Firm thud — file dropped into a drop zone, item snapped into place.
  static void drop() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy hit — destructive confirm, long-press pickup.
  static void heavy() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Double-pulse celebration — conversion finished, task complete.
  static Future<void> success() async {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(Motion.hapticGap);
    HapticFeedback.lightImpact();
  }

  /// Triple-buzz error — failed conversion, invalid input.
  static Future<void> error() async {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(Motion.instant);
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(Motion.instant);
    HapticFeedback.mediumImpact();
  }

  /// Continuous progress tick — call at milestone percents (25/50/75).
  static void milestone() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }
}
