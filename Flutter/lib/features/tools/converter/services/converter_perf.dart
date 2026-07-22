import 'dart:typed_data';

import '../../engine/engines/engine_util.dart';

/// Soft caps + helpers for converter performance / memory / battery.
class ConverterPerf {
  const ConverterPerf._();

  /// Max pages rendered in one free/Pro export pass (hard safety).
  static const maxPagesHardCap = 200;

  /// Max concurrent bitmap pixels (width*height) before downscaling further.
  static const maxPixelsPerPage = 4096 * 4096;

  /// Yield to UI + honor lifecycle pause between heavy steps.
  static Future<void> breathe({
    required bool Function() isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async {
    if (isCanceled()) return;
    await waitIfPaused?.call();
    await yieldFrame();
  }

  /// Clamp render dimensions for memory safety.
  static (int w, int h) clampRenderSize(int w, int h) {
    var width = w.clamp(1, 4096);
    var height = h.clamp(1, 4096);
    final pixels = width * height;
    if (pixels > maxPixelsPerPage) {
      final scale = (maxPixelsPerPage / pixels);
      width = (width * scale).floor().clamp(1, 4096);
      height = (height * scale).floor().clamp(1, 4096);
    }
    return (width, height);
  }

  /// Zero-out references after use (hint for GC on large buffers).
  static void releaseBytes(List<Uint8List?> buffers) {
    for (var i = 0; i < buffers.length; i++) {
      buffers[i] = null;
    }
  }
}
