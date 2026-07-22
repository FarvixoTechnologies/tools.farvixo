import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../tool_engine.dart';
import 'engine_util.dart';

const _fxExtensions = ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'];

img.Image _decodeFirst(ToolInput input) {
  if (input.files.isEmpty) throw const ToolFailure('Select an image.');
  final decoded = img.decodeImage(input.files.first.bytes);
  if (decoded == null) {
    throw const ToolFailure('Unsupported or corrupt image file.');
  }
  return decoded;
}

Future<ToolResult> _encodePng(
  img.Image image,
  ToolInput input,
  String suffix,
  String summary,
) async {
  final out = Uint8List.fromList(img.encodePng(image));
  await yieldFrame();
  return ToolResult.file(
    out,
    fileName: '${stripExtension(input.files.first.name)}-$suffix.png',
    mime: 'image/png',
    summary: summary,
  );
}

/// One-shot colour filter (grayscale / sepia / invert) — instantiated once
/// per catalog tool so each tool keeps its own identity.
class ImageFilterEngine extends LocalToolEngine {
  ImageFilterEngine(this.filter);

  /// 'grayscale' | 'sepia' | 'invert'
  final String filter;

  @override
  ToolSpec get spec => ToolSpec(
        actionLabel: 'Apply ${filter[0].toUpperCase()}${filter.substring(1)}',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _fxExtensions,
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

    onProgress(0.6, 'Applying filter');
    if (isCanceled()) throw const ToolCanceled();
    final filtered = switch (filter) {
      'sepia' => img.sepia(image),
      'invert' => img.invert(image),
      _ => img.grayscale(image),
    };
    return _encodePng(filtered, input, filter, '${filter[0].toUpperCase()}${filter.substring(1)} applied');
  }
}

/// Gaussian blur with strength presets.
class ImageBlurEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Blur',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _fxExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'strength',
          label: 'Strength',
          options: ['Light', 'Medium', 'Strong'],
          defaultValue: 'Medium',
        ),
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

    final strength = input.option<String>('strength') ?? 'Medium';
    final radius = switch (strength) {
      'Light' => 3,
      'Strong' => 14,
      _ => 7,
    };
    onProgress(0.5, 'Blurring');
    if (isCanceled()) throw const ToolCanceled();
    final blurred = img.gaussianBlur(image, radius: radius);
    return _encodePng(blurred, input, 'blur', '$strength blur');
  }
}

/// Pixelate (mosaic) an image — quick way to censor details.
class ImagePixelateEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Pixelate',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _fxExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'strength',
          label: 'Block size',
          options: ['Small', 'Medium', 'Large'],
          defaultValue: 'Medium',
        ),
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

    final strength = input.option<String>('strength') ?? 'Medium';
    final size = switch (strength) {
      'Small' => (image.width / 64).round().clamp(2, 64),
      'Large' => (image.width / 16).round().clamp(4, 256),
      _ => (image.width / 32).round().clamp(3, 128),
    };
    onProgress(0.5, 'Pixelating');
    if (isCanceled()) throw const ToolCanceled();
    final result = img.pixelate(image, size: size);
    return _encodePng(result, input, 'pixelated', '$strength blocks');
  }
}

/// Quick photo enhancement presets (brightness / contrast / saturation).
class ImageEnhanceEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Enhance',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _fxExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'preset',
          label: 'Preset',
          options: ['Brighten', 'Darken', 'Pop', 'Soft'],
          defaultValue: 'Pop',
        ),
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

    final preset = input.option<String>('preset') ?? 'Pop';
    onProgress(0.5, 'Enhancing');
    if (isCanceled()) throw const ToolCanceled();
    final result = switch (preset) {
      'Brighten' => img.adjustColor(image, brightness: 1.15, gamma: 0.95),
      'Darken' => img.adjustColor(image, brightness: 0.85),
      'Soft' => img.adjustColor(image, contrast: 0.92, saturation: 0.9),
      _ => img.adjustColor(image, contrast: 1.12, saturation: 1.18),
    };
    return _encodePng(result, input, 'enhanced', '$preset preset');
  }
}

/// Center-crop to a fixed aspect ratio.
class ImageCropRatioEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Crop',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _fxExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'ratio',
          label: 'Aspect ratio',
          options: ['Square 1:1', 'Wide 16:9', 'Classic 4:3', 'Photo 3:2'],
          defaultValue: 'Square 1:1',
        ),
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

    final ratioLabel = input.option<String>('ratio') ?? 'Square 1:1';
    final (rw, rh) = switch (ratioLabel) {
      'Wide 16:9' => (16, 9),
      'Classic 4:3' => (4, 3),
      'Photo 3:2' => (3, 2),
      _ => (1, 1),
    };
    var w = image.width;
    var h = w * rh ~/ rw;
    if (h > image.height) {
      h = image.height;
      w = h * rw ~/ rh;
    }
    onProgress(0.5, 'Cropping');
    if (isCanceled()) throw const ToolCanceled();
    final cropped = img.copyCrop(
      image,
      x: (image.width - w) ~/ 2,
      y: (image.height - h) ~/ 2,
      width: w,
      height: h,
    );
    return _encodePng(cropped, input, 'cropped',
        '$ratioLabel • ${cropped.width}×${cropped.height}');
  }
}

/// Image facts: dimensions, megapixels, aspect ratio, file size.
class ImageInfoEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Inspect',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _fxExtensions,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(null, 'Reading');
    if (isCanceled()) throw const ToolCanceled();
    final file = input.files.first;
    final image = _decodeFirst(input);
    await yieldFrame();

    int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
    final g = gcd(image.width, image.height);
    final mp = image.width * image.height / 1000000;
    return ToolResult.text(
      'File        ${file.name}\n'
      'Dimensions  ${image.width} × ${image.height} px\n'
      'Megapixels  ${mp.toStringAsFixed(1)} MP\n'
      'Aspect      ${image.width ~/ g}:${image.height ~/ g}\n'
      'Size        ${formatBytes(file.sizeBytes)}\n'
      'Channels    ${image.numChannels}',
      summary: '${image.width}×${image.height} • ${formatBytes(file.sizeBytes)}',
    );
  }
}

/// Image → Base64 data URI (for embedding in HTML/CSS).
class ImageBase64Engine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Encode',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _fxExtensions,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final file = input.files.first;
    if (file.sizeBytes > 2 * 1024 * 1024) {
      throw const ToolFailure(
          'Image is too large for Base64 (max 2 MB). Compress it first.');
    }
    onProgress(null, 'Encoding');
    await yieldFrame();
    final ext = file.name.split('.').last.toLowerCase();
    final mime = ext == 'jpg' ? 'jpeg' : ext;
    final uri = 'data:image/$mime;base64,${base64Encode(file.bytes)}';
    return ToolResult.text(uri,
        summary: '${formatBytes(file.sizeBytes)} → ${formatBytes(uri.length)} of text');
  }
}

/// Extract the dominant colours of an image as hex swatches.
class DominantColorsEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Extract Palette',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _fxExtensions,
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

    onProgress(0.4, 'Sampling colours');
    if (isCanceled()) throw const ToolCanceled();
    // Downscale for speed, then bucket to 4-bit per channel.
    image = img.copyResize(image, width: 64);
    final counts = <int, int>{};
    for (final p in image) {
      final key = ((p.r.toInt() >> 4) << 8) |
          ((p.g.toInt() >> 4) << 4) |
          (p.b.toInt() >> 4);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = image.width * image.height;
    final buf = StringBuffer();
    for (final e in sorted.take(6)) {
      final r = ((e.key >> 8) & 0xF) * 17;
      final g = ((e.key >> 4) & 0xF) * 17;
      final b = (e.key & 0xF) * 17;
      final hex =
          '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
              .toUpperCase();
      buf.writeln('$hex  ${(e.value / total * 100).toStringAsFixed(1)}%');
    }
    return ToolResult.text(buf.toString().trimRight(),
        summary: 'Top ${sorted.take(6).length} colours');
  }
}
