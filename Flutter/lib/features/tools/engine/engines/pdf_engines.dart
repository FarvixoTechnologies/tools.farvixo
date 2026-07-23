import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../tool_engine.dart';
import 'engine_util.dart';

/// Combine multiple images into a single PDF (one image per page).
class ImageToPdfEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Create PDF',
        needsFile: true,
        multiFile: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'gif'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) throw const ToolFailure('Select at least one image.');
    final document = PdfDocument();
    try {
      for (var i = 0; i < input.files.length; i++) {
        if (isCanceled()) throw const ToolCanceled();
        onProgress(i / input.files.length, 'Adding image ${i + 1}');
        await yieldFrame();
        final page = document.pages.add();
        final PdfBitmap image = PdfBitmap(input.files[i].bytes);
        final size = page.getClientSize();
        page.graphics.drawImage(image, Rect.fromLTWH(0, 0, size.width, size.height));
      }
      onProgress(1, 'Saving');
      final bytes = Uint8List.fromList(document.saveSync());
      return ToolResult.file(
        bytes,
        fileName: 'farvixo-${input.files.length}-images.pdf',
        mime: 'application/pdf',
        summary: '${input.files.length} image(s) → 1 PDF',
      );
    } finally {
      document.dispose();
    }
  }
}

/// Merge multiple PDF files into one.
class MergePdfEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Merge PDFs',
        needsFile: true,
        multiFile: true,
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.length < 2) {
      throw const ToolFailure('Select at least two PDF files to merge.');
    }
    // Optional per-file page selection, aligned to [input.files]. Each entry is
    // a range string like "1-3,5" (1-based); null/empty = all pages.
    final ranges = input.option<List<String?>>('pageRanges');
    final output = PdfDocument();
    var totalPages = 0;
    try {
      // 27.x has no PdfDocument.merge — copy every source page as a template
      // onto a fresh page in the output document.
      for (var i = 0; i < input.files.length; i++) {
        if (isCanceled()) throw const ToolCanceled();
        onProgress(i / input.files.length, 'Merging file ${i + 1}');
        await yieldFrame();
        final source = PdfDocument(inputBytes: input.files[i].bytes);
        try {
          final rangeStr = (ranges != null && i < ranges.length) ? ranges[i] : null;
          final selected = parsePageRange(rangeStr, source.pages.count);
          for (final p in selected) {
            final srcPage = source.pages[p];
            final template = srcPage.createTemplate();
            final newPage = output.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              Offset.zero,
              srcPage.getClientSize(),
            );
            totalPages++;
          }
        } finally {
          source.dispose();
        }
      }
      if (totalPages == 0) {
        throw const ToolFailure('No pages selected. Adjust the page ranges.');
      }
      onProgress(1, 'Saving');
      final bytes = Uint8List.fromList(output.saveSync());
      return ToolResult.file(
        bytes,
        fileName: 'farvixo-merged.pdf',
        mime: 'application/pdf',
        summary: '${input.files.length} PDFs · $totalPages pages merged',
      );
    } finally {
      output.dispose();
    }
  }

  /// Parse a 1-based page-range string ("1-3,5,8-10") into a sorted, de-duped
  /// list of 0-based page indices, clamped to [0, count). Null/blank = all pages.
  static List<int> parsePageRange(String? spec, int count) {
    if (spec == null || spec.trim().isEmpty) {
      return List<int>.generate(count, (i) => i);
    }
    final result = <int>{};
    for (final partRaw in spec.split(',')) {
      final part = partRaw.trim();
      if (part.isEmpty) continue;
      if (part.contains('-')) {
        final bits = part.split('-');
        if (bits.length != 2) continue;
        final a = int.tryParse(bits[0].trim());
        final b = int.tryParse(bits[1].trim());
        if (a == null || b == null) continue;
        final lo = a < b ? a : b;
        final hi = a < b ? b : a;
        for (var n = lo; n <= hi; n++) {
          if (n >= 1 && n <= count) result.add(n - 1);
        }
      } else {
        final n = int.tryParse(part);
        if (n != null && n >= 1 && n <= count) result.add(n - 1);
      }
    }
    final list = result.toList()..sort();
    return list;
  }
}

/// Password-protect a PDF (AES-256).
class ProtectPdfEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Protect PDF',
        needsFile: true,
        needsText: true,
        textHint: 'Set a password',
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) throw const ToolFailure('Select a PDF file.');
    final password = input.text?.trim() ?? '';
    if (password.isEmpty) throw const ToolFailure('Enter a password to protect the PDF.');

    onProgress(null, 'Encrypting');
    if (isCanceled()) throw const ToolCanceled();
    await yieldFrame();

    final PdfDocument document = PdfDocument(inputBytes: input.files.first.bytes);
    try {
      document.security
        ..userPassword = password
        ..algorithm = PdfEncryptionAlgorithm.aesx256Bit;
      final bytes = Uint8List.fromList(document.saveSync());
      final base = stripExtension(input.files.first.name);
      return ToolResult.file(
        bytes,
        fileName: '$base-protected.pdf',
        mime: 'application/pdf',
        summary: 'Password protected',
      );
    } finally {
      document.dispose();
    }
  }
}
