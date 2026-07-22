import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import '../tool_engine.dart';
import 'engine_util.dart';

/// Human-readable description of a QR payload (URL / email / phone / Wi-Fi /
/// UPI / vCard / location / text). Shared by the photo engine and the live
/// camera scanner.
String describeQrPayload(String text) {
  final t = text.trim().toLowerCase();
  if (t.startsWith('http://') || t.startsWith('https://')) return 'URL detected';
  if (t.startsWith('mailto:')) return 'Email address detected';
  if (t.startsWith('tel:')) return 'Phone number detected';
  if (t.startsWith('wifi:')) return 'Wi-Fi network detected';
  if (t.startsWith('begin:vcard')) return 'Contact card detected';
  if (t.startsWith('upi:')) return 'UPI payment link detected';
  if (t.startsWith('geo:')) return 'Location detected';
  return 'Text content';
}

/// QR Scanner — decodes a QR code from a photo (camera shot or gallery
/// image), fully offline via the pure-Dart zxing2 port.
///
/// Detects the payload type (URL / email / phone / Wi-Fi / vCard / text) and
/// reports it in the summary so the result card can offer the right action.
class QrScanEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Scan QR',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) {
      throw const ToolFailure('Pick a photo of a QR code.');
    }

    onProgress(null, 'Decoding image');
    if (isCanceled()) throw const ToolCanceled();
    var image = img.decodeImage(input.files.first.bytes);
    if (image == null) {
      throw const ToolFailure('Unsupported or corrupt image file.');
    }
    await yieldFrame();

    // Downscale very large photos: faster and often *more* reliable because
    // sensor noise averages out.
    if (image.width > 1400 || image.height > 1400) {
      image = image.width >= image.height
          ? img.copyResize(image, width: 1400)
          : img.copyResize(image, height: 1400);
      await yieldFrame();
    }

    onProgress(0.5, 'Scanning for QR code');
    if (isCanceled()) throw const ToolCanceled();

    var text = _decode(image);
    if (text == null) {
      // Second pass on the inverted image (light-on-dark QR codes).
      await yieldFrame();
      if (isCanceled()) throw const ToolCanceled();
      text = _decode(img.invert(image));
    }
    if (text == null) {
      throw const ToolFailure(
        'No QR code found. Try a sharper, well-lit photo with the full '
        'code visible.',
      );
    }

    return ToolResult.text(text, summary: describeQrPayload(text));
  }

  /// Try the fast global binarizer first, then the hybrid one (better for
  /// uneven lighting).
  String? _decode(img.Image image) {
    final pixels = _argbPixels(image);
    final source = RGBLuminanceSource(image.width, image.height, pixels);
    final reader = QRCodeReader();
    for (final Binarizer binarizer in [
      GlobalHistogramBinarizer(source),
      HybridBinarizer(source),
    ]) {
      try {
        return reader.decode(BinaryBitmap(binarizer)).text;
      } catch (_) {
        // keep trying the next strategy
      }
    }
    return null;
  }

  Int32List _argbPixels(img.Image image) {
    final rgb = image.convert(format: img.Format.uint8, numChannels: 4);
    final out = Int32List(rgb.width * rgb.height);
    var i = 0;
    for (final p in rgb) {
      out[i++] = (0xFF << 24) |
          ((p.r.toInt() & 0xFF) << 16) |
          ((p.g.toInt() & 0xFF) << 8) |
          (p.b.toInt() & 0xFF);
    }
    return out;
  }

}
