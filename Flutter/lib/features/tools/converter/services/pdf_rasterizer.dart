import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../models/convert_settings.dart';
import '../models/target_format.dart';
import 'converter_lifecycle_gate.dart';
import 'converter_perf.dart';
import 'webp_encoder_service.dart';

/// PDFium-backed page rasterizer (pdfrx).
class PdfRasterizer {
  PdfRasterizer({WebpEncoderService? webp})
      : _webp = webp ?? const WebpEncoderService();

  final WebpEncoderService _webp;
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await pdfrxFlutterInitialize();
    _initialized = true;
  }

  /// Render every page to encoded image bytes for [format].
  Future<List<Uint8List>> renderAll(
    Uint8List pdfBytes, {
    required TargetFormat format,
    ConvertSettings settings = const ConvertSettings(),
    void Function(int done, int total)? onProgress,
    bool Function()? isCanceled,
  }) async {
    await ensureInitialized();
    ConverterLifecycleGate.instance.attach();
    final doc = await PdfDocument.openData(pdfBytes);
    try {
      final out = <Uint8List>[];
      final total = doc.pages.length.clamp(0, ConverterPerf.maxPagesHardCap);
      if (doc.pages.length > ConverterPerf.maxPagesHardCap) {
        // Soft truncate — callers still get a usable pack.
      }
      for (var i = 0; i < total; i++) {
        if (isCanceled?.call() == true) throw const _Canceled();
        await ConverterPerf.breathe(
          isCanceled: isCanceled ?? () => false,
          waitIfPaused: ConverterLifecycleGate.instance.waitIfPaused,
        );
        if (isCanceled?.call() == true) throw const _Canceled();

        final page = doc.pages[i];
        final scale = settings.resolution;
        var w = (page.width * scale).round();
        var h = (page.height * scale).round();
        final clamped = ConverterPerf.clampRenderSize(w, h);
        w = clamped.$1;
        h = clamped.$2;

        final rendered = await page.render(
          fullWidth: w.toDouble(),
          fullHeight: h.toDouble(),
        );
        if (rendered == null) {
          throw StateError('Failed to render page ${i + 1}');
        }
        try {
          final image = img.Image.fromBytes(
            width: rendered.width,
            height: rendered.height,
            bytes: rendered.pixels.buffer,
            order: img.ChannelOrder.bgra,
          );
          // Convert BGRA→RGBA for WebP; JPG/PNG tolerate channel order via encode.
          out.add(await _encode(image, format, settings.imageQuality));
        } finally {
          rendered.dispose();
        }
        onProgress?.call(i + 1, total);
      }
      return out;
    } finally {
      await doc.dispose();
    }
  }

  /// First-page thumbnail PNG (for review UI).
  Future<Uint8List?> thumbnail(
    Uint8List pdfBytes, {
    double maxWidth = 180,
  }) async {
    try {
      await ensureInitialized();
      final doc = await PdfDocument.openData(pdfBytes);
      try {
        if (doc.pages.isEmpty) return null;
        final page = doc.pages.first;
        final scale = maxWidth / page.width;
        final w = (page.width * scale).round().clamp(1, 512);
        final h = (page.height * scale).round().clamp(1, 720);
        final rendered = await page.render(
          fullWidth: w.toDouble(),
          fullHeight: h.toDouble(),
        );
        if (rendered == null) return null;
        try {
          final image = img.Image.fromBytes(
            width: rendered.width,
            height: rendered.height,
            bytes: rendered.pixels.buffer,
            order: img.ChannelOrder.bgra,
          );
          return Uint8List.fromList(img.encodePng(image));
        } finally {
          rendered.dispose();
        }
      } finally {
        await doc.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _encode(
    img.Image image,
    TargetFormat format,
    double quality,
  ) async {
    final q = (quality.clamp(0.5, 1.0) * 100).round();
    switch (format) {
      case TargetFormat.webp:
        return _webp.encode(image, quality: quality);
      case TargetFormat.jpg:
        return Uint8List.fromList(img.encodeJpg(image, quality: q));
      case TargetFormat.png:
      default:
        return Uint8List.fromList(img.encodePng(image));
    }
  }
}

class _Canceled implements Exception {
  const _Canceled();
}

/// Convert a Flutter [ui.Image] to PNG bytes (utility for tests/previews).
Future<Uint8List> uiImageToPng(ui.Image image) async {
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}
