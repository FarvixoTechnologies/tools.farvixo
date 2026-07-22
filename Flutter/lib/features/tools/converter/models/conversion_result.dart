import 'dart:typed_data';

import 'target_format.dart';

class ConversionResult {
  const ConversionResult({
    required this.format,
    required this.bytes,
    required this.fileName,
    required this.mime,
    required this.confidence,
    required this.durationMs,
    required this.originalSize,
    this.previewBytes,
    this.previewText,
    this.summary,
  });

  final TargetFormat format;
  final Uint8List bytes;
  final String fileName;
  final String mime;
  final int confidence;
  final int durationMs;
  final int originalSize;
  final Uint8List? previewBytes;
  final String? previewText;
  final String? summary;

  int get outputSize => bytes.length;
}
