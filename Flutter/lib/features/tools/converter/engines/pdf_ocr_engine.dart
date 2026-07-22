import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../engine/engines/engine_util.dart';
import '../../engine/tool_engine.dart';
import '../models/target_format.dart';
import '../services/pdf_rasterizer.dart';

/// Makes PDFs more searchable on-device.
///
/// Digital PDFs: returns extracted text as a downloadable file.
/// Scanned PDFs: uses optional [ocrPageText] (ML Kit / remote). Without it,
/// returns a short guidance PDF explaining next steps.
class PdfOcrEngine extends LocalToolEngine {
  PdfOcrEngine({this.ocrPageText});

  /// Optional injectable OCR. Receives PNG page bytes → recognized text.
  final Future<String> Function(Uint8List pngBytes)? ocrPageText;

  final _raster = PdfRasterizer();

  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Run OCR',
        needsFile: true,
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) throw const ToolFailure('Select a PDF file.');
    final src = input.files.first;
    if (src.bytes.isEmpty) throw const ToolFailure('File is empty.');

    onProgress(0.05, 'Opening PDF');
    await yieldFrame();
    if (isCanceled()) throw const ToolCanceled();

    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: src.bytes);
    } catch (_) {
      throw const ToolFailure(
        'Could not open this PDF (password-protected or corrupt).',
      );
    }

    try {
      final pageCount = document.pages.count;
      final existing = PdfTextExtractor(document).extractText().trim();
      final looksScanned = existing.length < pageCount * 40;

      if (!looksScanned) {
        onProgress(0.6, 'Extracting searchable text');
        await yieldFrame();
        return ToolResult.file(
          Uint8List.fromList(utf8.encode(existing)),
          fileName: '${stripExtension(src.name)}-searchable.txt',
          mime: 'text/plain',
          summary:
              'Digital PDF · $pageCount page(s) · ${existing.length} chars',
          copyText: existing,
        );
      }

      final buffer = StringBuffer();
      var usedOcr = false;
      if (ocrPageText != null) {
        final pages = await _raster.renderAll(
          src.bytes,
          format: TargetFormat.png,
          onProgress: (done, total) {
            onProgress(0.1 + 0.7 * (done / total), 'OCR page $done/$total');
          },
          isCanceled: isCanceled,
        );
        for (var i = 0; i < pages.length; i++) {
          if (isCanceled()) throw const ToolCanceled();
          final text = (await ocrPageText!(pages[i])).trim();
          if (text.isNotEmpty) {
            usedOcr = true;
            buffer.writeln('--- Page ${i + 1} ---');
            buffer.writeln(text);
            buffer.writeln();
          }
        }
      }

      if (usedOcr && buffer.isNotEmpty) {
        onProgress(0.9, 'Building searchable PDF');
        final searchable = _textOverlayPdf(src.bytes, buffer.toString());
        return ToolResult.file(
          searchable,
          fileName: '${stripExtension(src.name)}-ocr.pdf',
          mime: 'application/pdf',
          summary: 'OCR complete · $pageCount page(s)',
          copyText: buffer.toString(),
        );
      }

      onProgress(0.85, 'Preparing guidance');
      await yieldFrame();
      return ToolResult.file(
        _guidancePdf(pageCount),
        fileName: '${stripExtension(src.name)}-ocr-guide.pdf',
        mime: 'application/pdf',
        summary:
            'Scanned PDF · export as images or enable ML Kit for live OCR.',
      );
    } finally {
      document.dispose();
    }
  }

  Uint8List _guidancePdf(int pageCount) {
    final doc = PdfDocument();
    try {
      final page = doc.pages.add();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      final bold = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );
      page.graphics.drawString(
        'Farvixo PDF OCR',
        bold,
        bounds: const Rect.fromLTWH(40, 40, 500, 28),
      );
      page.graphics.drawString(
        'This looks like a scanned document ($pageCount page(s)) with little '
        'selectable text.\n\n'
        'What you can do now:\n'
        '1. Open PDF Converter and export as PNG/JPG\n'
        '2. Enable on-device ML Kit OCR when available\n'
        '3. Re-run PDF to Word after text is available\n\n'
        'Your original file never left this device.',
        font,
        bounds: const Rect.fromLTWH(40, 80, 500, 400),
      );
      return Uint8List.fromList(doc.saveSync());
    } finally {
      doc.dispose();
    }
  }

  Uint8List _textOverlayPdf(Uint8List original, String ocrText) {
    final doc = PdfDocument(inputBytes: original);
    try {
      final page = doc.pages.add();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 10);
      final size = page.getClientSize();
      page.graphics.drawString(
        'OCR text layer\n\n$ocrText',
        font,
        bounds: Rect.fromLTWH(36, 36, size.width - 72, size.height - 72),
      );
      return Uint8List.fromList(doc.saveSync());
    } finally {
      doc.dispose();
    }
  }
}
