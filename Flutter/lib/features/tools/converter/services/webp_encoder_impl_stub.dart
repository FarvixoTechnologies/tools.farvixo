import 'dart:typed_data';

/// Web has no dart:ffi — native WebP encode is unavailable.
Future<Uint8List?> encodeWebpRgba({
  required Uint8List rgba,
  required int width,
  required int height,
  required double quality,
}) async =>
    null;
