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
    final output = PdfDocument();
    try {
      // 27.x has no PdfDocument.merge — copy every source page as a template
      // onto a fresh page in the output document.
      for (var i = 0; i < input.files.length; i++) {
        if (isCanceled()) throw const ToolCanceled();
        onProgress(i / input.files.length, 'Merging file ${i + 1}');
        await yieldFrame();
        final source = PdfDocument(inputBytes: input.files[i].bytes);
        try {
          for (var p = 0; p < source.pages.count; p++) {
            final srcPage = source.pages[p];
            final template = srcPage.createTemplate();
            final newPage = output.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              Offset.zero,
              srcPage.getClientSize(),
            );
          }
        } finally {
          source.dispose();
        }
      }
      onProgress(1, 'Saving');
      final bytes = Uint8List.fromList(output.saveSync());
      return ToolResult.file(
        bytes,
        fileName: 'farvixo-merged.pdf',
        mime: 'application/pdf',
        summary: '${input.files.length} PDFs merged',
      );
    } finally {
      output.dispose();
    }
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
