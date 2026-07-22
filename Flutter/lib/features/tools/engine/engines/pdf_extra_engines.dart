import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../tool_engine.dart';
import 'engine_util.dart';

/// Parse "1-3,7,9-10" (1-based, inclusive) into 0-based page indices.
List<int> _parsePageRange(String raw, int pageCount) {
  final indices = <int>[];
  for (final part in raw.split(',')) {
    final p = part.trim();
    if (p.isEmpty) continue;
    final range = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(p);
    if (range != null) {
      final a = int.parse(range.group(1)!);
      final b = int.parse(range.group(2)!);
      for (var i = a; i <= b; i++) {
        indices.add(i - 1);
      }
    } else {
      final n = int.tryParse(p);
      if (n == null) throw ToolFailure('"$p" is not a page number.');
      indices.add(n - 1);
    }
  }
  if (indices.isEmpty) {
    throw const ToolFailure('Enter pages like 1-3,7');
  }
  for (final i in indices) {
    if (i < 0 || i >= pageCount) {
      throw ToolFailure('Page ${i + 1} is out of range (1–$pageCount).');
    }
  }
  return indices;
}

/// Copy selected pages of [source] into a fresh document (template copy).
Uint8List _copyPages(PdfDocument source, List<int> pageIndices) {
  final output = PdfDocument();
  try {
    for (final i in pageIndices) {
      final srcPage = source.pages[i];
      final template = srcPage.createTemplate();
      final newPage = output.pages.add();
      newPage.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        srcPage.getClientSize(),
      );
    }
    return Uint8List.fromList(output.saveSync());
  } finally {
    output.dispose();
  }
}

PdfDocument _open(ToolInput input) {
  if (input.files.isEmpty) throw const ToolFailure('Select a PDF file.');
  try {
    return PdfDocument(inputBytes: input.files.first.bytes);
  } catch (_) {
    throw const ToolFailure(
        'Could not open this PDF (is it password-protected?).');
  }
}

/// Extract a page range into a new PDF.
class SplitPdfEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Extract Pages',
        needsFile: true,
        needsText: true,
        textHint: 'Pages to keep — e.g. 1-3,7',
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final document = _open(input);
    try {
      onProgress(null, 'Reading pages');
      await yieldFrame();
      if (isCanceled()) throw const ToolCanceled();
      final pages =
          _parsePageRange(input.text?.trim() ?? '', document.pages.count);
      onProgress(0.5, 'Extracting ${pages.length} page(s)');
      await yieldFrame();
      final bytes = _copyPages(document, pages);
      return ToolResult.file(
        bytes,
        fileName: '${stripExtension(input.files.first.name)}-pages.pdf',
        mime: 'application/pdf',
        summary:
            '${pages.length} of ${document.pages.count} pages extracted',
      );
    } finally {
      document.dispose();
    }
  }
}

/// Extract all text from a PDF.
class PdfToTextEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Extract Text',
        needsFile: true,
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final document = _open(input);
    try {
      onProgress(null, 'Extracting text');
      await yieldFrame();
      if (isCanceled()) throw const ToolCanceled();
      final text = PdfTextExtractor(document).extractText();
      final cleaned = text.trim();
      if (cleaned.isEmpty) {
        throw const ToolFailure(
            'No selectable text found — this looks like a scanned PDF. '
            'Try the PDF OCR tool instead.');
      }
      return ToolResult.text(
        cleaned,
        summary:
            '${document.pages.count} page(s) • ${cleaned.length} characters',
      );
    } finally {
      document.dispose();
    }
  }
}

/// PDF facts: pages, size, security, metadata.
class PdfInfoEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Inspect',
        needsFile: true,
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final file = input.files.first;
    final document = _open(input);
    try {
      onProgress(null, 'Reading metadata');
      await yieldFrame();
      final info = document.documentInformation;
      final size = document.pages.count > 0
          ? document.pages[0].getClientSize()
          : null;
      String meta(String label, String? v) =>
          v == null || v.isEmpty ? '' : '$label $v\n';
      return ToolResult.text(
        'File        ${file.name}\n'
        'Pages       ${document.pages.count}\n'
        'Size        ${formatBytes(file.sizeBytes)}\n'
        '${size != null ? 'Page size   ${size.width.round()} × ${size.height.round()} pt\n' : ''}'
        '${meta('Title      ', info.title)}'
        '${meta('Author     ', info.author)}'
        '${meta('Creator    ', info.creator)}',
        summary:
            '${document.pages.count} pages • ${formatBytes(file.sizeBytes)}',
      );
    } finally {
      document.dispose();
    }
  }
}

/// Rotate every page of a PDF.
class PdfRotateEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Rotate PDF',
        needsFile: true,
        allowedExtensions: ['pdf'],
        choice: ToolChoiceSpec(
          optionKey: 'angle',
          label: 'Rotate',
          options: ['90° right', '180°', '90° left'],
          defaultValue: '90° right',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final document = _open(input);
    try {
      final label = input.option<String>('angle') ?? '90° right';
      final rotation = switch (label) {
        '180°' => PdfPageRotateAngle.rotateAngle180,
        '90° left' => PdfPageRotateAngle.rotateAngle270,
        _ => PdfPageRotateAngle.rotateAngle90,
      };
      for (var i = 0; i < document.pages.count; i++) {
        if (isCanceled()) throw const ToolCanceled();
        onProgress(i / document.pages.count, 'Rotating page ${i + 1}');
        document.pages[i].rotation = rotation;
      }
      await yieldFrame();
      final bytes = Uint8List.fromList(document.saveSync());
      return ToolResult.file(
        bytes,
        fileName: '${stripExtension(input.files.first.name)}-rotated.pdf',
        mime: 'application/pdf',
        summary: '${document.pages.count} page(s) rotated $label',
      );
    } finally {
      document.dispose();
    }
  }
}

/// Stamp a diagonal text watermark on every page.
class PdfWatermarkEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Add Watermark',
        needsFile: true,
        needsText: true,
        textHint: 'Watermark text — e.g. CONFIDENTIAL',
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final text = input.text?.trim() ?? '';
    if (text.isEmpty) throw const ToolFailure('Enter watermark text.');
    final document = _open(input);
    try {
      final font = PdfStandardFont(PdfFontFamily.helvetica, 40,
          style: PdfFontStyle.bold);
      for (var i = 0; i < document.pages.count; i++) {
        if (isCanceled()) throw const ToolCanceled();
        onProgress(i / document.pages.count, 'Stamping page ${i + 1}');
        final page = document.pages[i];
        final size = page.getClientSize();
        final g = page.graphics;
        g.save();
        g.setTransparency(0.18);
        g.translateTransform(size.width / 2, size.height / 2);
        g.rotateTransform(-40);
        final width = font.measureString(text).width;
        g.drawString(
          text,
          font,
          brush: PdfBrushes.gray,
          bounds: Rect.fromLTWH(-width / 2, -20, width, 40),
        );
        g.restore();
        if (i % 5 == 0) await yieldFrame();
      }
      final bytes = Uint8List.fromList(document.saveSync());
      return ToolResult.file(
        bytes,
        fileName: '${stripExtension(input.files.first.name)}-watermarked.pdf',
        mime: 'application/pdf',
        summary: '"$text" on ${document.pages.count} page(s)',
      );
    } finally {
      document.dispose();
    }
  }
}

/// Remove a known password from a PDF.
class UnlockPdfEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Unlock PDF',
        needsFile: true,
        needsText: true,
        textHint: 'Current password',
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) throw const ToolFailure('Select a PDF file.');
    final password = input.text ?? '';
    if (password.isEmpty) {
      throw const ToolFailure('Enter the current password.');
    }
    onProgress(null, 'Unlocking');
    await yieldFrame();
    final PdfDocument document;
    try {
      document =
          PdfDocument(inputBytes: input.files.first.bytes, password: password);
    } catch (_) {
      throw const ToolFailure('Wrong password for this PDF.');
    }
    try {
      document.security
        ..userPassword = ''
        ..ownerPassword = '';
      final bytes = Uint8List.fromList(document.saveSync());
      return ToolResult.file(
        bytes,
        fileName: '${stripExtension(input.files.first.name)}-unlocked.pdf',
        mime: 'application/pdf',
        summary: 'Password removed',
      );
    } finally {
      document.dispose();
    }
  }
}

/// Re-save a PDF with maximum content-stream compression.
class CompressPdfEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Compress PDF',
        needsFile: true,
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final before = input.files.first.sizeBytes;
    final document = _open(input);
    try {
      onProgress(null, 'Optimizing');
      await yieldFrame();
      if (isCanceled()) throw const ToolCanceled();
      document.compressionLevel = PdfCompressionLevel.best;
      final bytes = Uint8List.fromList(document.saveSync());
      if (bytes.length >= before) {
        return ToolResult.file(
          Uint8List.fromList(input.files.first.bytes),
          fileName: input.files.first.name,
          mime: 'application/pdf',
          summary: 'Already optimized — no further savings possible on-device',
        );
      }
      return ToolResult.file(
        bytes,
        fileName: '${stripExtension(input.files.first.name)}-compressed.pdf',
        mime: 'application/pdf',
        summary: sizeDeltaSummary(before, bytes.length),
      );
    } finally {
      document.dispose();
    }
  }
}

/// Stamp "Page X of N" in the footer of every page.
class PdfPageNumberEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Add Page Numbers',
        needsFile: true,
        allowedExtensions: ['pdf'],
        choice: ToolChoiceSpec(
          optionKey: 'position',
          label: 'Position',
          options: ['Bottom center', 'Bottom right', 'Bottom left'],
          defaultValue: 'Bottom center',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final document = _open(input);
    try {
      final font = PdfStandardFont(PdfFontFamily.helvetica, 10);
      final total = document.pages.count;
      final position = input.option<String>('position') ?? 'Bottom center';
      for (var i = 0; i < total; i++) {
        if (isCanceled()) throw const ToolCanceled();
        onProgress(i / total, 'Numbering page ${i + 1}');
        final page = document.pages[i];
        final size = page.getClientSize();
        final label = 'Page ${i + 1} of $total';
        final width = font.measureString(label).width;
        final x = switch (position) {
          'Bottom right' => size.width - width - 24,
          'Bottom left' => 24.0,
          _ => (size.width - width) / 2,
        };
        page.graphics.drawString(
          label,
          font,
          brush: PdfBrushes.gray,
          bounds: Rect.fromLTWH(x, size.height - 24, width + 4, 14),
        );
        if (i % 10 == 0) await yieldFrame();
      }
      final bytes = Uint8List.fromList(document.saveSync());
      return ToolResult.file(
        bytes,
        fileName: '${stripExtension(input.files.first.name)}-numbered.pdf',
        mime: 'application/pdf',
        summary: '$total page(s) numbered',
      );
    } finally {
      document.dispose();
    }
  }
}

/// Reverse the page order of a PDF.
class ReversePdfEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Reverse Pages',
        needsFile: true,
        allowedExtensions: ['pdf'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final document = _open(input);
    try {
      onProgress(null, 'Reversing');
      await yieldFrame();
      if (isCanceled()) throw const ToolCanceled();
      final order =
          List<int>.generate(document.pages.count, (i) => i).reversed.toList();
      final bytes = _copyPages(document, order);
      return ToolResult.file(
        bytes,
        fileName: '${stripExtension(input.files.first.name)}-reversed.pdf',
        mime: 'application/pdf',
        summary: '${document.pages.count} pages reversed',
      );
    } finally {
      document.dispose();
    }
  }
}
