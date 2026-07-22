import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../tool_engine.dart';
import 'engine_util.dart';

import '../../../../theme/app_colors.dart';

/// Local hashing — MD5 / SHA-1 / SHA-256 / SHA-512, fully offline.
class HashEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Hash',
        needsText: true,
        textHint: 'Enter text to hash…',
        choice: ToolChoiceSpec(
          optionKey: 'algorithm',
          label: 'Algorithm',
          options: ['MD5', 'SHA1', 'SHA256', 'SHA512'],
          defaultValue: 'SHA256',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter text to hash.');
    final algo = (input.option<String>('algorithm') ?? 'SHA256').toUpperCase();

    onProgress(null, 'Hashing');
    await yieldFrame();
    final bytes = utf8.encode(raw);
    final digest = switch (algo) {
      'MD5' => md5.convert(bytes),
      'SHA1' => sha1.convert(bytes),
      'SHA512' => sha512.convert(bytes),
      _ => sha256.convert(bytes),
    };
    final hex = digest.toString();
    return ToolResult.text(hex, summary: '$algo • ${digest.bytes.length * 8}-bit');
  }
}

/// Local UUID v4 generation (cryptographically random), fully offline.
class UuidEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(actionLabel: 'Generate');

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(null, 'Generating');
    return ToolResult.text(_uuidV4(), summary: 'UUID v4');
  }

  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10xx
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
        '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }
}

/// Local QR-code generation to a PNG (white background), fully offline.
/// Supports Text / URL / Email / Phone payload shaping.
class QrEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Generate QR',
        needsText: true,
        textHint: 'Text, URL, email or phone…',
        choice: ToolChoiceSpec(
          optionKey: 'type',
          label: 'Type',
          options: ['Text', 'URL', 'Email', 'Phone'],
          defaultValue: 'Text',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter content for the QR code.');
    final type = input.option<String>('type') ?? 'Text';

    final payload = switch (type) {
      'URL' =>
        raw.startsWith('http://') || raw.startsWith('https://') ? raw : 'https://$raw',
      'Email' => 'mailto:$raw',
      'Phone' => 'tel:${raw.replaceAll(' ', '')}',
      _ => raw,
    };

    onProgress(null, 'Rendering QR');
    await yieldFrame();
    final bytes = await _renderQrPng(payload, 720);
    return ToolResult.file(
      bytes,
      fileName: 'farvixo-qr.png',
      mime: 'image/png',
      summary: '$type QR code',
      copyText: payload,
    );
  }

  Future<Uint8List> _renderQrPng(String data, int size) async {
    final QrCode qr;
    try {
      qr = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
    } catch (e) {
      throw const ToolFailure('That content is too long for a QR code.');
    }
    final painter = QrPainter.withQr(
      qr: qr,
      gapless: true,
      // Pure black on pure white is a scannability requirement, not a design
      // choice — a themed QR code fails to decode at low contrast.
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.scrim,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.scrim,
      ),
    );

    final recorder = ui.PictureRecorder();
    final dim = size.toDouble();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, dim, dim),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, dim, dim),
      ui.Paint()..color = AppColors.onAccent,
    );
    painter.paint(canvas, ui.Size(dim, dim));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (byteData == null) throw const ToolFailure('QR rendering failed.');
    return byteData.buffer.asUint8List();
  }
}
