
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'webp_encoder_impl_stub.dart'
    if (dart.library.ffi) 'webp_encoder_impl_native.dart';

/// Encodes an [img.Image] to WebP on native platforms (`swipelab_webp`).
/// On web, falls back to JPEG (no dart:ffi).
class WebpEncoderService {
  const WebpEncoderService();

  /// Quality 0.5–1.0 → libwebp 0–100 (native) or JPEG quality.
  Future<Uint8List> encode(
    img.Image image, {
    double quality = 0.85,
  }) async {
    final q = (quality.clamp(0.5, 1.0) * 100);
    final rgbaImage =
        image.numChannels == 4 ? image : image.convert(numChannels: 4);
    final rgba = rgbaImage.getBytes(order: img.ChannelOrder.rgba);

    try {
      final encoded = await encodeWebpRgba(
        rgba: rgba,
        width: rgbaImage.width,
        height: rgbaImage.height,
        quality: q,
      );
      if (encoded != null && encoded.isNotEmpty) return encoded;
    } catch (e) {
      debugPrint('WebP encode failed, falling back to JPEG: $e');
    }

    return Uint8List.fromList(
      img.encodeJpg(image, quality: q.round()),
    );
  }

  /// True when the returned bytes look like a WebP (RIFF….WEBP).
  static bool isWebpMagic(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }
}
