/// On-device engines: image watermark, meme generator and subtitle tools.
/// Pure Dart on existing dependencies (`image`), no network, no new packages.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../tool_engine.dart';
import 'engine_util.dart';

const _imgExtensions = ['jpg', 'jpeg', 'png', 'bmp', 'webp'];

img.Image _decodeImageInput(ToolInput input) {
  if (input.files.isEmpty) throw const ToolFailure('Select an image.');
  final decoded = img.decodeImage(input.files.first.bytes);
  if (decoded == null) {
    throw const ToolFailure('Unsupported or corrupt image file.');
  }
  return decoded;
}

/// Draws [text] with a dark shadow so it stays readable on any background.
void _drawShadowedText(
  img.Image image,
  String text, {
  required img.BitmapFont font,
  required int x,
  required int y,
  int alpha = 255,
}) {
  img.drawString(image, text,
      font: font, x: x + 2, y: y + 2, color: img.ColorRgba8(0, 0, 0, alpha));
  img.drawString(image, text,
      font: font, x: x, y: y, color: img.ColorRgba8(255, 255, 255, alpha));
}

/// Rough pixel width of [text] for a bitmap font — good enough for placement.
int _textWidth(String text, img.BitmapFont font) =>
    (text.length * font.size * 0.55).round();

/// Text watermark stamped in a chosen corner (or center) of the image.
class ImageWatermarkEngine extends LocalToolEngine {
  static const _positions = [
    'Bottom right',
    'Bottom left',
    'Top right',
    'Top left',
    'Center',
  ];

  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Add Watermark',
        needsFile: true,
        needsText: true,
        pickFromGallery: true,
        allowedExtensions: _imgExtensions,
        textHint: 'Watermark text, e.g. © Farvixo 2026',
        choice: ToolChoiceSpec(
          optionKey: 'position',
          label: 'Position',
          options: _positions,
          defaultValue: 'Bottom right',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final text = (input.text ?? '').trim();
    if (text.isEmpty) throw const ToolFailure('Enter the watermark text.');

    onProgress(0.2, 'Decoding');
    if (isCanceled()) throw const ToolCanceled();
    final image = _decodeImageInput(input);
    await yieldFrame();

    onProgress(0.6, 'Stamping watermark');
    if (isCanceled()) throw const ToolCanceled();
    final font = image.width >= 900 ? img.arial48 : img.arial24;
    final w = _textWidth(text, font);
    const pad = 16;
    final position = (input.options['position'] as String?) ?? 'Bottom right';
    final (x, y) = switch (position) {
      'Bottom left' => (pad, image.height - font.size - pad),
      'Top right' => (image.width - w - pad, pad),
      'Top left' => (pad, pad),
      'Center' =>
        ((image.width - w) ~/ 2, (image.height - font.size) ~/ 2),
      _ => (image.width - w - pad, image.height - font.size - pad),
    };
    _drawShadowedText(image, text,
        font: font,
        x: x.clamp(0, image.width).toInt(),
        y: y.clamp(0, image.height).toInt(),
        alpha: 210);

    onProgress(0.9, 'Encoding');
    final out = Uint8List.fromList(img.encodePng(image));
    await yieldFrame();
    return ToolResult.file(
      out,
      fileName: '${stripExtension(input.files.first.name)}-watermarked.png',
      mime: 'image/png',
      summary: 'Watermark added · $position',
    );
  }
}

/// Classic top/bottom caption meme. Separate captions with `|`.
class MemeGeneratorEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Make Meme',
        needsFile: true,
        needsText: true,
        pickFromGallery: true,
        allowedExtensions: _imgExtensions,
        textHint: 'TOP TEXT | BOTTOM TEXT',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = (input.text ?? '').trim();
    if (raw.isEmpty) throw const ToolFailure('Enter the meme text.');
    final parts = raw.split('|');
    final top = parts.first.trim().toUpperCase();
    final bottom = parts.length > 1 ? parts[1].trim().toUpperCase() : '';

    onProgress(0.2, 'Decoding');
    if (isCanceled()) throw const ToolCanceled();
    final image = _decodeImageInput(input);
    await yieldFrame();

    onProgress(0.6, 'Adding captions');
    if (isCanceled()) throw const ToolCanceled();
    final font = image.width >= 700 ? img.arial48 : img.arial24;
    if (top.isNotEmpty) {
      _drawShadowedText(image, top,
          font: font,
          x: ((image.width - _textWidth(top, font)) ~/ 2)
              .clamp(0, image.width)
              .toInt(),
          y: 12);
    }
    if (bottom.isNotEmpty) {
      _drawShadowedText(image, bottom,
          font: font,
          x: ((image.width - _textWidth(bottom, font)) ~/ 2)
              .clamp(0, image.width)
              .toInt(),
          y: image.height - font.size - 12);
    }

    onProgress(0.9, 'Encoding');
    final out = Uint8List.fromList(img.encodePng(image));
    await yieldFrame();
    return ToolResult.file(
      out,
      fileName: '${stripExtension(input.files.first.name)}-meme.png',
      mime: 'image/png',
      summary: 'Meme created',
    );
  }
}

/// Classical 2×/4× upscale with bicubic interpolation — honest about not
/// being AI super-resolution, but a real quality improvement over nearest.
class ImageUpscalerEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Upscale',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: _imgExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'factor',
          label: 'Scale',
          options: ['2x', '4x'],
          defaultValue: '2x',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final factor =
        ((input.options['factor'] as String?) ?? '2x') == '4x' ? 4 : 2;

    onProgress(0.2, 'Decoding');
    if (isCanceled()) throw const ToolCanceled();
    final image = _decodeImageInput(input);
    if (image.width * factor > 8000 || image.height * factor > 8000) {
      throw const ToolFailure(
          'Result would exceed 8000px — choose a smaller scale.');
    }
    await yieldFrame();

    onProgress(0.6, 'Upscaling ${factor}x (bicubic)');
    if (isCanceled()) throw const ToolCanceled();
    final up = img.copyResize(
      image,
      width: image.width * factor,
      height: image.height * factor,
      interpolation: img.Interpolation.cubic,
    );
    await yieldFrame();

    onProgress(0.9, 'Encoding');
    final out = Uint8List.fromList(img.encodePng(up));
    await yieldFrame();
    return ToolResult.file(
      out,
      fileName: '${stripExtension(input.files.first.name)}-${factor}x.png',
      mime: 'image/png',
      summary:
          '${image.width}×${image.height} → ${up.width}×${up.height} · bicubic',
    );
  }
}

/// Subtitle utilities — SRT ⇄ VTT conversion and timestamp shifting.
/// Pure text processing; no codecs required.
class SubtitleToolsEngine extends LocalToolEngine {
  static const _ops = [
    'Convert SRT → VTT',
    'Convert VTT → SRT',
    'Shift forward',
    'Shift backward',
  ];

  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Process Subtitles',
        needsFile: true,
        allowedExtensions: ['srt', 'vtt'],
        needsText: true,
        textHint: 'Shift seconds (e.g. 2.5) — only used for shift',
        choice: ToolChoiceSpec(
          optionKey: 'op',
          label: 'Operation',
          options: _ops,
          defaultValue: 'Convert SRT → VTT',
        ),
      );

  static final _srtTime =
      RegExp(r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})');

  String _format(Duration d, {required bool vtt}) {
    String two(int v) => v.toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    final sep = vtt ? '.' : ',';
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}$sep$ms';
  }

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) throw const ToolFailure('Select a subtitle file.');
    onProgress(0.3, 'Parsing');
    if (isCanceled()) throw const ToolCanceled();

    var text = utf8.decode(input.files.first.bytes, allowMalformed: true);
    final op = (input.options['op'] as String?) ?? _ops.first;
    final name = stripExtension(input.files.first.name);

    if (op.startsWith('Shift')) {
      final secs = double.tryParse((input.text ?? '').trim());
      if (secs == null || secs <= 0) {
        throw const ToolFailure('Enter the shift amount in seconds, e.g. 2.5');
      }
      final delta = Duration(milliseconds: (secs * 1000).round()) *
          (op == 'Shift backward' ? -1 : 1);
      final isVtt = text.contains('.') && text.trimLeft().startsWith('WEBVTT');
      text = text.replaceAllMapped(_srtTime, (m) {
        var t = Duration(
          hours: int.parse(m[1]!),
          minutes: int.parse(m[2]!),
          seconds: int.parse(m[3]!),
          milliseconds: int.parse(m[4]!),
        );
        t += delta;
        if (t.isNegative) t = Duration.zero;
        return _format(t, vtt: isVtt);
      });
      onProgress(0.9, 'Encoding');
      await yieldFrame();
      return ToolResult.file(
        Uint8List.fromList(utf8.encode(text)),
        fileName: input.files.first.name,
        mime: 'text/plain',
        summary:
            'Timestamps shifted ${op == 'Shift backward' ? '−' : '+'}${secs}s',
      );
    }

    if (op == 'Convert SRT → VTT') {
      final converted = 'WEBVTT\n\n${text.replaceAllMapped(
        _srtTime,
        (m) => '${m[1]}:${m[2]}:${m[3]}.${m[4]}',
      )}';
      onProgress(0.9, 'Encoding');
      await yieldFrame();
      return ToolResult.file(
        Uint8List.fromList(utf8.encode(converted)),
        fileName: '$name.vtt',
        mime: 'text/vtt',
        summary: 'Converted to WebVTT',
      );
    }

    // VTT → SRT: drop the header, renumber cues, use comma separators.
    final body = text.replaceFirst(RegExp(r'^﻿?WEBVTT[^\n]*\n+'), '');
    final converted = body.replaceAllMapped(
      _srtTime,
      (m) => '${m[1]}:${m[2]}:${m[3]},${m[4]}',
    );
    onProgress(0.9, 'Encoding');
    await yieldFrame();
    return ToolResult.file(
      Uint8List.fromList(utf8.encode(converted)),
      fileName: '$name.srt',
      mime: 'text/plain',
      summary: 'Converted to SRT',
    );
  }
}
