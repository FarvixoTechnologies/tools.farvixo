
import 'package:flutter/foundation.dart';
import 'package:swipelab_webp/swipelab_webp.dart';

/// Native libwebp encode (mobile / desktop with dart:ffi).
Future<Uint8List?> encodeWebpRgba({
  required Uint8List rgba,
  required int width,
  required int height,
  required double quality,
}) async {
  return compute(
    encodeWebP,
    WebPEncodeInput(
      rgba: rgba,
      width: width,
      height: height,
      quality: quality,
      lossless: false,
    ),
  );
}
