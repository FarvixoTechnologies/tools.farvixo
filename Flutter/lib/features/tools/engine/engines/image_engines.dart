import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../tool_engine.dart';
import 'engine_util.dart';

/// Decode the first picked file into an [img.Image] or fail clearly.
img.Image _decodeFirst(ToolInput input) {
  if (input.files.isEmpty) throw const ToolFailure('Select an image.');
  final decoded = img.decodeImage(input.files.first.bytes);
  if (decoded == null) {
    throw const ToolFailure('Unsupported or corrupt image file.');
  }
  return decoded;
}

const _imageExtensions = ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'];

/// Compress an image to JPEG at a target quality (default 70).
class ImageCompressEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Compress',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _imageExtensions,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final before = input.files.first.sizeBytes;
    onProgress(null, 'Decoding');
    if (isCanceled()) throw const ToolCanceled();
    final image = _decodeFirst(input);
    await yieldFrame();

    onProgress(0.6, 'Compressing');
    if (isCanceled()) throw const ToolCanceled();
    final quality = (input.option<int>('quality') ?? 70).clamp(10, 95);
    final out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    await yieldFrame();

    return ToolResult.file(
      out,
      fileName: '${stripExtension(input.files.first.name)}-compressed.jpg',
      mime: 'image/jpeg',
      summary: sizeDeltaSummary(before, out.length),
    );
  }
}

/// Resize an image so its longest edge fits a target (default 1080px).
class ImageResizeEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Resize',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _imageExtensions,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(null, 'Decoding');
    if (isCanceled()) throw const ToolCanceled();
    final image = _decodeFirst(input);
    await yieldFrame();

    final maxEdge = (input.option<int>('maxEdge') ?? 1080).clamp(64, 8000);
    final resized = image.width >= image.height
        ? img.copyResize(image, width: maxEdge)
        : img.copyResize(image, height: maxEdge);

    onProgress(0.7, 'Encoding');
    if (isCanceled()) throw const ToolCanceled();
    final out = Uint8List.fromList(img.encodePng(resized));
    await yieldFrame();

    return ToolResult.file(
      out,
      fileName: '${stripExtension(input.files.first.name)}-resized.png',
      mime: 'image/png',
      summary: '${image.width}×${image.height} → ${resized.width}×${resized.height}',
    );
  }
}

/// Convert an image to another raster format (default PNG).
class ImageConvertEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _imageExtensions,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(null, 'Decoding');
    if (isCanceled()) throw const ToolCanceled();
    final image = _decodeFirst(input);
    await yieldFrame();

    final format = (input.option<String>('format') ?? 'png').toLowerCase();
    onProgress(0.7, 'Encoding $format');
    if (isCanceled()) throw const ToolCanceled();

    final (Uint8List bytes, String mime, String ext) = switch (format) {
      'jpg' || 'jpeg' => (
          Uint8List.fromList(img.encodeJpg(image, quality: 90)),
          'image/jpeg',
          'jpg'
        ),
      'bmp' => (Uint8List.fromList(img.encodeBmp(image)), 'image/bmp', 'bmp'),
      'gif' => (Uint8List.fromList(img.encodeGif(image)), 'image/gif', 'gif'),
      _ => (Uint8List.fromList(img.encodePng(image)), 'image/png', 'png'),
    };
    await yieldFrame();

    return ToolResult.file(
      bytes,
      fileName: '${stripExtension(input.files.first.name)}.$ext',
      mime: mime,
      summary: 'Converted to ${ext.toUpperCase()}',
    );
  }
}

/// Rotate (default 90°) or flip an image.
class ImageRotateFlipEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Rotate',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _imageExtensions,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(null, 'Decoding');
    if (isCanceled()) throw const ToolCanceled();
    var image = _decodeFirst(input);
    await yieldFrame();

    onProgress(0.6, 'Transforming');
    if (isCanceled()) throw const ToolCanceled();
    final flip = input.option<String>('flip');
    if (flip == 'horizontal') {
      image = img.flipHorizontal(image);
    } else if (flip == 'vertical') {
      image = img.flipVertical(image);
    } else {
      final angle = (input.option<int>('angle') ?? 90).toDouble();
      image = img.copyRotate(image, angle: angle);
    }

    final out = Uint8List.fromList(img.encodePng(image));
    await yieldFrame();
    return ToolResult.file(
      out,
      fileName: '${stripExtension(input.files.first.name)}-edited.png',
      mime: 'image/png',
      summary: 'Transformed',
    );
  }
}
