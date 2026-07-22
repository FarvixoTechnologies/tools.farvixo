/// Farvixo Premium UI Kit — one import for every shared "ultra" building
/// block. New tool screens should import this barrel (plus `premium_kit.dart`
/// for the legacy widgets) and compose, never re-implement.
///
/// ```dart
/// import 'package:farvixo/widgets/premium/premium.dart';
/// ```
library;

export '../../theme/motion_springs.dart';
export '../../theme/tool_identity.dart';
export '../animations.dart' show FadeSlideIn, PressableScale, AppPageRoute;
export '../glass_surface.dart' show GlassPanel;
export 'animated_count.dart';
export 'app_haptics.dart';
export 'before_after_slider.dart';
export 'command_palette.dart';
export 'confetti_burst.dart';
export 'progress_ring.dart';
export 'tilt_card.dart';
export 'typewriter_text.dart';
export 'waveform_bars.dart';
