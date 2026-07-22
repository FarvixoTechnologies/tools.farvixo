import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../engine/engines/engine_util.dart';
import '../../engine/tool_engine.dart';
import '../models/convert_settings.dart';
import '../models/conversion_result.dart';
import '../models/document_structure.dart';
import '../models/target_format.dart';
import '../services/docx_writer.dart';
import '../services/ooxml_isolates.dart';
import '../services/pdf_analyzer.dart';
import '../services/pdf_rasterizer.dart';
import '../services/pptx_writer.dart';
import '../services/text_format_writers.dart';
import '../services/to_pdf_builder.dart';

enum ConverterInputKind { pdf, toPdf }

/// Unified PDF Converter — also powers locked-format alias tools.
class PdfConverterEngine extends LocalToolEngine {
  PdfConverterEngine({
    this.lockedTarget,
    this.expectExtension,
  });

  /// When set (alias tools), skip format picker / force this target.
  final TargetFormat? lockedTarget;

  /// Optional required input extension for aliases (e.g. `docx` for word-to-pdf).
  final String? expectExtension;

  final _analyzer = const PdfAnalyzer();
  final _text = const TextFormatWriters();
  final _docx = const DocxWriter();
  final _pptx = const PptxWriter();
  final _toPdf = const ToPdfBuilder();
  final _raster = PdfRasterizer();

  @override
  ToolSpec get spec {
    if (lockedTarget == TargetFormat.pdf) {
      return ToolSpec(
        actionLabel: 'Convert to PDF',
        needsFile: true,
        multiFile: expectExtension == null,
        allowedExtensions: expectExtension != null
            ? [expectExtension!]
            : const [
                'jpg',
                'jpeg',
                'png',
                'webp',
                'bmp',
                'gif',
                'docx',
                'xlsx',
                'xls',
                'csv',
                'txt',
                'md',
                'html',
                'htm',
              ],
      );
    }
    if (lockedTarget != null && lockedTarget!.isImage) {
      return ToolSpec(
        actionLabel: 'Export ${lockedTarget!.label}',
        needsFile: true,
        allowedExtensions: const ['pdf'],
        choice: ToolChoiceSpec(
          optionKey: 'resolution',
          label: 'Resolution',
          options: const ['1.5', '2.0', '3.0'],
          defaultValue: '2.0',
        ),
      );
    }
    if (lockedTarget == TargetFormat.docx) {
      return const ToolSpec(
        actionLabel: 'Convert to Word',
        needsFile: true,
        allowedExtensions: ['pdf'],
      );
    }
    if (lockedTarget == TargetFormat.xlsx) {
      return const ToolSpec(
        actionLabel: 'Convert to Excel',
        needsFile: true,
        allowedExtensions: ['pdf'],
      );
    }
    return const ToolSpec(
      actionLabel: 'Convert',
      needsFile: true,
      allowedExtensions: [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'bmp',
        'gif',
        'docx',
        'xlsx',
        'xls',
        'csv',
        'txt',
        'md',
        'html',
        'htm',
      ],
    );
  }

  static ConverterInputKind detectKind(String fileName) {
    final ext = _ext(fileName);
    if (ext == 'pdf') return ConverterInputKind.pdf;
    return ConverterInputKind.toPdf;
  }

  static String _ext(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  }

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) {
      throw const ToolFailure('Select a file to convert.');
    }
    final file = input.files.first;
    if (file.bytes.isEmpty) {
      throw const ToolFailure('File is empty.');
    }

    final target = lockedTarget ??
        TargetFormatX.tryParse(input.option<String>('target')) ??
        TargetFormatX.tryParse(input.option<String>('format'));
    if (target == null) {
      throw const ToolFailure('Choose an output format.');
    }

    final quality = (input.option<num>('imageQuality')?.toDouble() ?? 0.85)
        .clamp(0.5, 1.0);
    final resolution = double.tryParse(
          input.option<String>('resolution') ?? '',
        ) ??
        (input.option<num>('resolution')?.toDouble() ?? 2.0);
    final zipMulti = input.option<bool>('zipMultiPageImages') ?? true;
    final settings = ConvertSettings(
      imageQuality: quality,
      resolution: resolution.clamp(1.0, 3.0),
      zipMultiPageImages: zipMulti,
    );

    final password = input.option<String>('password') ?? input.text?.trim();
    final result = await convert(
      bytes: file.bytes,
      fileName: file.name,
      extraFiles: input.files.skip(1).map((f) => f.bytes).toList(),
      target: target,
      settings: settings,
      password: password,
      onProgress: onProgress,
      isCanceled: isCanceled,
    );

    if (result.format.isTextual && result.previewText != null) {
      // Text targets can also surface as ToolResult.text for copy UX.
      if (result.format == TargetFormat.txt ||
          result.format == TargetFormat.md) {
        return ToolResult.text(
          result.previewText!,
          summary: result.summary,
        );
      }
    }

    return ToolResult.file(
      result.bytes,
      fileName: result.fileName,
      mime: result.mime,
      summary: result.summary,
      copyText: result.previewText,
    );
  }

  Future<ConversionResult> convert({
    required Uint8List bytes,
    required String fileName,
    List<Uint8List> extraFiles = const [],
    required TargetFormat target,
    ConvertSettings settings = const ConvertSettings(),
    String? password,
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final sw = Stopwatch()..start();
    final kind = detectKind(fileName);
    final stem = stripExtension(fileName);
    final originalSize = bytes.length;

    void check() {
      if (isCanceled()) throw const ToolCanceled();
    }

    if (kind == ConverterInputKind.toPdf || target == TargetFormat.pdf) {
      onProgress(0.1, 'Building PDF');
      check();
      final pdfBytes = await _toPdfFromInput(
        bytes: bytes,
        fileName: fileName,
        extraFiles: extraFiles,
        onProgress: onProgress,
        isCanceled: isCanceled,
      );
      check();
      onProgress(1, 'Done');
      return ConversionResult(
        format: TargetFormat.pdf,
        bytes: pdfBytes,
        fileName: '$stem.pdf',
        mime: TargetFormat.pdf.mime,
        confidence: 92,
        durationMs: sw.elapsedMilliseconds,
        originalSize: originalSize,
        summary: '${formatBytes(originalSize)} → PDF',
      );
    }

    // PDF → target
    onProgress(0.05, 'Analyzing document');
    check();
    final DocumentStructure structure;
    try {
      structure = _analyzer.analyzeBytes(bytes, password: password);
    } catch (_) {
      throw const ToolFailure(
        'Could not open this PDF. If it is password-protected, enter the password.',
      );
    }
    final conf = _analyzer.confidenceFor(structure, target);

    if (structure.isScanned &&
        (target.isOffice || target.isTextual) &&
        target != TargetFormat.pdf) {
      throw const ToolFailure(
        'This looks like a scanned PDF with little selectable text. '
        'Export as Image, or run PDF OCR first.',
      );
    }

    onProgress(0.15, 'Extracting content');
    check();
    final text = _extractText(bytes, password: password);

    late Uint8List outBytes;
    late String outName;
    String? previewText;
    Uint8List? previewBytes;

    switch (target) {
      case TargetFormat.txt:
        onProgress(0.6, 'Writing text');
        outBytes = _text.toTxt(text);
        outName = '$stem.txt';
        previewText = text;
      case TargetFormat.md:
        onProgress(0.6, 'Writing Markdown');
        outBytes = _text.toMd(text);
        outName = '$stem.md';
        previewText = utf8.decode(outBytes);
      case TargetFormat.html:
        onProgress(0.6, 'Writing HTML');
        outBytes = _text.toHtml(text, title: stem);
        outName = '$stem.html';
        previewText = text;
      case TargetFormat.rtf:
        onProgress(0.6, 'Writing RTF');
        outBytes = _text.toRtf(text);
        outName = '$stem.rtf';
        previewText = text;
      case TargetFormat.csv:
        onProgress(0.5, 'Detecting tables');
        final csvRows = _text.tablesFromText(text);
        if (csvRows.isEmpty) {
          throw const ToolFailure(
            'No table-like rows found. Try Excel or Word instead.',
          );
        }
        outBytes = _text.toCsv(csvRows);
        outName = '$stem.csv';
        previewText = utf8.decode(outBytes);
      case TargetFormat.docx:
        onProgress(0.55, 'Building Word document');
        final paras = _docx.paragraphsFromText(text);
        final tables = _text.tablesFromText(text);
        outBytes = await OoxmlIsolates.buildDocx(
          paragraphs: paras,
          tables: tables.isEmpty ? const [] : [tables],
        );
        outName = '$stem.docx';
        previewText = text.length > 2000 ? text.substring(0, 2000) : text;
      case TargetFormat.xlsx:
        onProgress(0.55, 'Building Excel workbook');
        var xRows = _text.tablesFromText(text);
        if (xRows.isEmpty) {
          xRows = text
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .map((l) => [l])
              .toList();
        }
        if (xRows.isEmpty) {
          throw const ToolFailure('No content to put into Excel.');
        }
        outBytes = await OoxmlIsolates.buildXlsx(xRows);
        outName = '$stem.xlsx';
      case TargetFormat.jpg:
      case TargetFormat.png:
      case TargetFormat.webp:
        onProgress(0.2, 'Rendering pages');
        final pages = await _raster.renderAll(
          bytes,
          format: target,
          settings: settings,
          onProgress: (done, total) {
            onProgress(
              0.2 + 0.7 * (done / total),
              'Rendering page $done/$total',
            );
          },
          isCanceled: isCanceled,
        );
        check();
        if (pages.isEmpty) {
          throw const ToolFailure('No pages could be rendered.');
        }
        previewBytes = pages.first;
        final ext = target.extension;
        if (pages.length == 1) {
          outBytes = pages.first;
          outName = '$stem.$ext';
        } else {
          outBytes = _zipImages(stem, pages, ext);
          outName = '$stem-pages.zip';
        }
      case TargetFormat.pptx:
        onProgress(0.2, 'Rendering slides');
        final slides = await _raster.renderAll(
          bytes,
          format: TargetFormat.jpg,
          settings: settings,
          onProgress: (done, total) {
            onProgress(0.2 + 0.6 * (done / total), 'Slide $done/$total');
          },
          isCanceled: isCanceled,
        );
        check();
        onProgress(0.85, 'Building PowerPoint');
        outBytes = _pptx.build(slides);
        outName = '$stem.pptx';
        previewBytes = slides.isNotEmpty ? slides.first : null;
      case TargetFormat.pdf:
        throw const ToolFailure('Already a PDF.');
    }

    check();
    onProgress(1, 'Done');
    final mime = outName.endsWith('.zip')
        ? 'application/zip'
        : target.mime;

    return ConversionResult(
      format: target,
      bytes: outBytes,
      fileName: outName,
      mime: mime,
      confidence: conf.overall,
      durationMs: sw.elapsedMilliseconds,
      originalSize: originalSize,
      previewBytes: previewBytes,
      previewText: previewText,
      summary:
          '${structure.pageCount} page(s) → ${target.label} · ${conf.overall}% · ${formatBytes(outBytes.length)}',
    );
  }

  Uint8List _zipImages(String stem, List<Uint8List> pages, String ext) {
    final archive = Archive();
    for (var i = 0; i < pages.length; i++) {
      final name = '$stem-page${(i + 1).toString().padLeft(3, '0')}.$ext';
      archive.addFile(ArchiveFile(name, pages[i].length, pages[i]));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  String _extractText(Uint8List bytes, {String? password}) {
    PdfDocument? doc;
    try {
      doc = password == null || password.isEmpty
          ? PdfDocument(inputBytes: bytes)
          : PdfDocument(inputBytes: bytes, password: password);
      return PdfTextExtractor(doc).extractText().trim();
    } finally {
      doc?.dispose();
    }
  }

  Future<Uint8List> _toPdfFromInput({
    required Uint8List bytes,
    required String fileName,
    required List<Uint8List> extraFiles,
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final ext = _ext(fileName);
    if (isCanceled()) throw const ToolCanceled();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'bmp':
      case 'gif':
        onProgress(0.4, 'Adding images');
        final images = <Uint8List>[
          _toPdf.normalizeImage(bytes),
          ...extraFiles.map(_toPdf.normalizeImage),
        ];
        return _toPdf.fromImages(images);
      case 'docx':
        onProgress(0.4, 'Reading Word document');
        return _toPdf.fromDocx(bytes);
      case 'xlsx':
      case 'xls':
        onProgress(0.4, 'Reading spreadsheet');
        return _toPdf.fromXlsx(bytes);
      case 'csv':
        onProgress(0.4, 'Reading CSV');
        return _toPdf.fromCsv(utf8.decode(bytes));
      case 'txt':
        onProgress(0.4, 'Laying out text');
        return _toPdf.fromPlainText(utf8.decode(bytes));
      case 'md':
        onProgress(0.4, 'Converting Markdown');
        return _toPdf.fromMarkdown(utf8.decode(bytes));
      case 'html':
      case 'htm':
        onProgress(0.4, 'Converting HTML');
        return _toPdf.fromHtmlish(utf8.decode(bytes));
      case 'pdf':
        return bytes;
      default:
        throw ToolFailure('Unsupported file type: .$ext');
    }
  }
}
