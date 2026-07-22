/// Farvixo — Lightning Upload visual language.
///
/// The upload experience has its own tightly-art-directed palette taken from
/// the approved key art: a deep indigo night sky, a violet storm cloud, a gold
/// lightning strike, a black premium folder with a gold edge, an amber 3D
/// upload arrow, and a glowing gold ring on a dark metal platform.
///
/// These are **art-direction tokens**, not category tokens. They stay fixed
/// across light and dark themes because the hero is always rendered on its own
/// dark stage — a light-mode variant would destroy the lightning contrast.
/// Everything *around* the hero (queue, panels, text) uses the normal
/// [AppPalette] and is fully theme-aware.
library;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// The Lightning Upload stage palette.
class UploadPalette {
  UploadPalette._();

  // ---- Night sky backdrop ----
  static const Color skyTop = Color(0xFF1A1236);
  static const Color skyMid = Color(0xFF150F2C);
  static const Color skyDeep = Color(0xFF0B0818);

  /// Vignette that darkens the stage corners.
  static const Color vignette = Color(0xCC060410);

  // ---- Storm cloud ----
  static const Color cloudLight = Color(0xFF7A68B8);
  static const Color cloudMid = Color(0xFF574A85);
  static const Color cloudDark = Color(0xFF3A3160);
  static const Color cloudShadow = Color(0xFF241E42);

  // ---- Lightning ----
  static const Color boltCore = Color(0xFFFFF3C4);
  static const Color boltHot = Color(0xFFFFC53D);
  static const Color bolt = Color(0xFFFFA31A);
  static const Color boltDeep = Color(0xFFFF7A00);

  // ---- Folder ----
  static const Color folderTop = Color(0xFF1B1826);
  static const Color folderBottom = Color(0xFF0A0910);
  static const Color folderEdge = Color(0xFFC9A227);
  static const Color folderEdgeHot = Color(0xFFFFCE5C);

  /// Specular gloss sweep across the folder face.
  static const Color folderGloss = Color(0x2EFFFFFF);

  // ---- Upload arrow ----
  static const Color arrowTop = Color(0xFFFFC53D);
  static const Color arrowBottom = Color(0xFFFF8C1A);

  // ---- Ring + platform ----
  //
  // The ring has no colour of its own: it renders in the active status accent
  // (gold → green on success, rose on failure) so the stage reads state at a
  // glance. See LightningStagePainter._paintRing.
  static const Color platformTop = Color(0xFF2A2740);
  static const Color platformBottom = Color(0xFF14121F);
  static const Color platformEdge = Color(0xFF3D3A5C);
  static const Color platformSlot = Color(0xFF0A0912);

  // ---- Status tints on the stage ----
  static const Color success = Color(0xFF34D399);
  static const Color failure = Color(0xFFFB7185);
  static const Color paused = Color(0xFF94A3B8);

  /// Foreground on the stage — always light, the stage is always dark.
  static const Color onStage = AppColors.onAccent;
  static const Color onStageMuted = AppColors.lavender300;

  /// Fully transparent stop for radial falloffs.
  static const Color clear = Color(0x00000000);

  /// Contact shadow cast by the folder onto the platform.
  static const Color contactShadow = Color(0x99000000);

  // ---- Composed gradients ----

  static const LinearGradient sky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyMid, skyDeep],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient cloud = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cloudLight, cloudMid, cloudDark],
  );

  static const LinearGradient folder = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [folderTop, folderBottom],
  );

  static const LinearGradient arrow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [arrowTop, arrowBottom],
  );

  static const LinearGradient platform = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [platformTop, platformBottom],
  );

  static const LinearGradient lightning = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [boltCore, boltHot, bolt, boltDeep],
  );

  /// Gold rim sweep for the ring.
  static const SweepGradient ring = SweepGradient(
    colors: [boltDeep, bolt, boltHot, boltCore, boltHot, bolt, boltDeep],
  );
}

/// Geometry + motion constants for the hero stage.
///
/// All positions are expressed as fractions of the stage box so the hero
/// scales identically from a 320px phone to an ultrawide desktop panel.
class UploadStage {
  UploadStage._();

  /// Stage aspect ratio (width : height) — matches the key art.
  static const double aspect = 0.78;

  // Vertical bands, as fractions of stage height.
  static const double cloudTop = 0.06;
  static const double cloudHeight = 0.26;
  static const double boltTop = 0.26;
  static const double boltBottom = 0.46;
  static const double folderTop = 0.38;
  static const double folderHeight = 0.34;
  static const double ringCenter = 0.74;
  static const double platformTop = 0.78;

  // Horizontal insets, as fractions of stage width.
  static const double folderInset = 0.16;
  static const double platformInset = 0.10;

  /// Idle float travel of the folder, in logical pixels at 1× stage scale.
  static const double floatTravel = 10;

  /// Ring stroke width relative to stage width.
  static const double ringStroke = 0.012;

  // ---- Motion ----

  /// Folder rise-and-fall loop.
  static const Duration float = Duration(milliseconds: 3600);

  /// One lightning strike: flash in, decay out.
  static const Duration strike = Duration(milliseconds: 520);

  /// Gap between idle ambient strikes.
  static const Duration strikeGap = Duration(milliseconds: 4200);

  /// Ring rotation while transferring.
  static const Duration ringSpin = Duration(milliseconds: 2400);

  /// Completion burst.
  static const Duration burst = Duration(milliseconds: 900);

  /// How often the transport reports a chunk. Small enough that progress
  /// reads as smooth, large enough not to flood the widget tree.
  static const Duration chunkTick = Duration(milliseconds: 80);

  /// Post-transfer integrity check dwell, so `verifying` is perceivable.
  static const Duration verifyDwell = Duration(milliseconds: 320);

  /// Base delay between auto-retry attempts; multiplied by attempt number.
  static const Duration retryBackoff = Duration(milliseconds: 400);
}
