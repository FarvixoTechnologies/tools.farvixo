import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/document_structure.dart';
import '../models/target_format.dart';

/// Local document intelligence — port of web `pdf-intelligence` concepts.
class PdfAnalyzer {
  const PdfAnalyzer();

  DocumentStructure analyzeBytes(List<int> bytes, {String? password}) {
    PdfDocument? document;
    try {
      document = password == null || password.isEmpty
          ? PdfDocument(inputBytes: bytes)
          : PdfDocument(inputBytes: bytes, password: password);
    } catch (_) {
      throw StateError('Could not open this PDF (password or corrupt file).');
    }

    try {
      final pageCount = document.pages.count;
      final pages = <PageStrategy>[];
      final buffer = StringBuffer();
      var totalChars = 0;
      var tableCount = 0;
      var imageCount = 0;

      final extractor = PdfTextExtractor(document);

      for (var i = 0; i < pageCount; i++) {
        final pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        final cleaned = pageText.trim();
        final chars = cleaned.length;
        totalChars += chars;
        if (i < 3 && cleaned.isNotEmpty) {
          buffer.writeln(cleaned.length > 400 ? cleaned.substring(0, 400) : cleaned);
        }

        final tableScore = _tableScore(cleaned);
        if (tableScore >= 0.45) tableCount++;

        // Syncfusion does not expose a cheap embedded-image count per page;
        // approximate from near-empty text pages as image-heavy.
        final imgGuess = chars < 40 ? 1 : 0;
        imageCount += imgGuess;

        final density = (chars / 1800).clamp(0.0, 1.0);
        final kind = _pageKind(density, tableScore, imgGuess);
        pages.add(PageStrategy(
          pageIndex: i,
          kind: kind,
          textDensity: density,
          charCount: chars,
          tableScore: tableScore,
          imageCount: imgGuess,
          confidence: _pageConfidence(density, tableScore),
        ));
      }

      final words = RegExp(r'\S+')
          .allMatches(buffer.toString())
          .length
          .clamp(0, 1 << 30);
      // Better word estimate from full char count.
      final estimatedWords =
          totalChars == 0 ? 0 : (totalChars / 5).round().clamp(0, 1 << 30);

      final isScanned = pageCount > 0 &&
          pages.every((p) => p.charCount < 30) &&
          totalChars < pageCount * 40;

      final script = _detectScript(buffer.toString());
      final docType = _detectType(
        pages: pages,
        isScanned: isScanned,
        tableCount: tableCount,
        sample: buffer.toString(),
      );
      final typeConf = _typeConfidence(docType, pages, isScanned, tableCount);
      final recommendation = recommendFormat(
        isScanned: isScanned,
        tableCount: tableCount,
        pageCount: pageCount,
        imagePages: pages.where((p) => p.kind == PageKind.image).length,
        totalChars: totalChars,
        docType: docType,
      );
      final overall = isScanned
          ? 35
          : (55 +
                  (totalChars > 200 ? 20 : 0) +
                  (tableCount > 0 ? 10 : 0) -
                  (pageCount > 80 ? 10 : 0))
              .clamp(20, 96);

      return DocumentStructure(
        pageCount: pageCount,
        totalWords: estimatedWords > 0 ? estimatedWords : words,
        totalChars: totalChars,
        pages: pages,
        documentType: docType,
        documentTypeConfidence: typeConf,
        recommendation: recommendation,
        overallConfidence: overall,
        isScanned: isScanned,
        scriptHint: script,
        tableCount: tableCount,
        imageCount: imageCount,
        sampleText: buffer.toString().trim(),
      );
    } finally {
      document.dispose();
    }
  }

  /// Confidence that converting [structure] to [target] will look good.
  ConfidenceBreakdown confidenceFor(
    DocumentStructure structure,
    TargetFormat target,
  ) {
    final issues = <String>[];
    var textExt = structure.isScanned
        ? 15
        : (structure.totalChars / (structure.pageCount * 800 + 1) * 100)
            .round()
            .clamp(20, 98);
    var layout = 80;
    var tables = structure.tableCount > 0 ? 75 : 50;

    if (structure.isScanned) {
      issues.add('Scanned PDF — run OCR first for Word/Excel text.');
      if (target.isOffice || target.isTextual) textExt = 20;
    }
    if (target == TargetFormat.xlsx || target == TargetFormat.csv) {
      if (structure.tableCount == 0) {
        tables = 25;
        issues.add('No clear tables detected — spreadsheet may be sparse.');
      } else {
        tables = 88;
      }
    }
    if (target == TargetFormat.pptx && structure.pageCount > 40) {
      layout = 55;
      issues.add('Many pages — PowerPoint export may be large.');
    }
    if (target.isImage) {
      textExt = 90;
      layout = 92;
      tables = 70;
      issues.removeWhere((e) => e.contains('OCR'));
    }
    if (structure.pageCount > 100) {
      layout -= 15;
      issues.add('Large document — conversion may take longer.');
    }

    final overall = ((textExt * 0.45) + (layout * 0.3) + (tables * 0.25))
        .round()
        .clamp(10, 98);

    return ConfidenceBreakdown(
      overall: overall,
      textExtractability: textExt,
      layoutComplexity: layout,
      tableQuality: tables,
      issues: issues,
    );
  }

  FormatRecommendation recommendFormat({
    required bool isScanned,
    required int tableCount,
    required int pageCount,
    required int imagePages,
    required int totalChars,
    required DocumentType docType,
  }) {
    if (isScanned) {
      return const FormatRecommendation(
        format: TargetFormat.png,
        reason: 'Scanned pages render best as images (or run OCR first).',
      );
    }
    if (docType == DocumentType.spreadsheet || tableCount >= (pageCount / 2).ceil()) {
      return const FormatRecommendation(
        format: TargetFormat.xlsx,
        reason: 'Table-heavy layout — Excel preserves columns best.',
      );
    }
    if (totalChars >= 80) {
      return const FormatRecommendation(
        format: TargetFormat.docx,
        reason: 'Prose document — Word is the best editable target.',
      );
    }
    if (docType == DocumentType.presentation ||
        (imagePages > pageCount * 0.5 && pageCount <= 30 && totalChars < 80)) {
      return const FormatRecommendation(
        format: TargetFormat.pptx,
        reason: 'Visual / slide-like pages — PowerPoint keeps one page per slide.',
      );
    }
    if (totalChars < 200 && pageCount > 0) {
      return const FormatRecommendation(
        format: TargetFormat.jpg,
        reason: 'Low selectable text — image export is safer.',
      );
    }
    return const FormatRecommendation(
      format: TargetFormat.docx,
      reason: 'Prose document — Word is the best editable target.',
    );
  }

  double _tableScore(String text) {
    if (text.isEmpty) return 0;
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 3) return 0;
    var tabby = 0;
    var numeric = 0;
    for (final line in lines) {
      final gaps = RegExp(r'\s{2,}').allMatches(line).length;
      final pipes = '|'.allMatches(line).length;
      if (gaps >= 2 || pipes >= 2) tabby++;
      if (RegExp(r'\d').hasMatch(line) && gaps >= 1) numeric++;
    }
    final ratio = (tabby + numeric * 0.5) / lines.length;
    return ratio.clamp(0.0, 1.0);
  }

  PageKind _pageKind(double density, double tableScore, int images) {
    if (tableScore >= 0.45) return PageKind.table;
    if (density < 0.02 && images > 0) return PageKind.image;
    if (density < 0.015) return PageKind.image;
    if (tableScore >= 0.25 && density > 0.1) return PageKind.mixed;
    return PageKind.text;
  }

  double _pageConfidence(double density, double tableScore) {
    if (density < 0.05) return 0.4;
    return (0.5 + density * 0.4 + tableScore * 0.1).clamp(0.3, 0.98);
  }

  ScriptHint _detectScript(String sample) {
    if (sample.isEmpty) return ScriptHint.unknown;
    var bn = 0, dv = 0, cjk = 0, lat = 0;
    for (final cu in sample.runes) {
      if (cu >= 0x0980 && cu <= 0x09FF) {
        bn++;
      } else if (cu >= 0x0900 && cu <= 0x097F) {
        dv++;
      } else if ((cu >= 0x4E00 && cu <= 0x9FFF) ||
          (cu >= 0x3040 && cu <= 0x30FF)) {
        cjk++;
      } else if ((cu >= 0x41 && cu <= 0x7A) || (cu >= 0xC0 && cu <= 0x024F)) {
        lat++;
      }
    }
    final total = bn + dv + cjk + lat;
    if (total == 0) return ScriptHint.unknown;
    final hits = [bn, dv, cjk, lat].where((n) => n > total * 0.15).length;
    if (hits > 1) return ScriptHint.mixed;
    if (bn >= dv && bn >= cjk && bn >= lat) return ScriptHint.bengali;
    if (dv >= cjk && dv >= lat) return ScriptHint.devanagari;
    if (cjk >= lat) return ScriptHint.cjk;
    return ScriptHint.latin;
  }

  DocumentType _detectType({
    required List<PageStrategy> pages,
    required bool isScanned,
    required int tableCount,
    required String sample,
  }) {
    if (isScanned) return DocumentType.scanned;
    final lower = sample.toLowerCase();
    if (lower.contains('invoice') || lower.contains('gst') || lower.contains('bill to')) {
      return DocumentType.invoice;
    }
    if (lower.contains('resume') || lower.contains('curriculum vitae') || lower.contains('experience')) {
      return DocumentType.resume;
    }
    if (lower.contains('agreement') || lower.contains('hereinafter') || lower.contains('party')) {
      return DocumentType.contract;
    }
    if (tableCount >= 2 && tableCount >= pages.length * 0.4) {
      return DocumentType.spreadsheet;
    }
    if (pages.length <= 20 &&
        pages.where((p) => p.kind == PageKind.image).length > pages.length * 0.4) {
      return DocumentType.presentation;
    }
    if (lower.contains('abstract') || lower.contains('references')) {
      return DocumentType.academic;
    }
    return DocumentType.report;
  }

  int _typeConfidence(
    DocumentType type,
    List<PageStrategy> pages,
    bool isScanned,
    int tableCount,
  ) {
    if (type == DocumentType.scanned) return isScanned ? 90 : 40;
    if (type == DocumentType.spreadsheet) return tableCount > 0 ? 78 : 45;
    if (type == DocumentType.unknown) return 40;
    return 62;
  }
}
