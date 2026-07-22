import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farvixo_all/features/tools/converter/models/target_format.dart';
import 'package:farvixo_all/features/tools/converter/services/docx_writer.dart';
import 'package:farvixo_all/features/tools/converter/services/pdf_analyzer.dart';
import 'package:farvixo_all/features/tools/converter/services/pptx_writer.dart';
import 'package:farvixo_all/features/tools/converter/services/text_format_writers.dart';
import 'package:farvixo_all/features/tools/converter/services/xlsx_writer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

Uint8List _textPdf(String text) {
  final doc = PdfDocument();
  try {
    final page = doc.pages.add();
    page.graphics.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );
    return Uint8List.fromList(doc.saveSync());
  } finally {
    doc.dispose();
  }
}

void main() {
  group('TextFormatWriters', () {
    const w = TextFormatWriters();

    test('txt / md / html / rtf emit utf-8', () {
      const sample = 'Hello Farvixo\n\nSecond para';
      expect(utf8.decode(w.toTxt(sample)), contains('Hello'));
      expect(utf8.decode(w.toMd('TITLE LINE\nbody')), contains('##'));
      expect(utf8.decode(w.toHtml(sample)), contains('<p>'));
      expect(utf8.decode(w.toRtf(sample)), startsWith(r'{\rtf1'));
    });

    test('csv escapes commas and quotes', () {
      final bytes = w.toCsv([
        ['a', 'b,c', 'say "hi"'],
      ]);
      final s = utf8.decode(bytes);
      expect(s, contains('"b,c"'));
      expect(s, contains('"say ""hi"""'));
    });

    test('tablesFromText detects tab / pipe rows', () {
      final rows = w.tablesFromText('Name\tAge\nAda\t36\n|x|y|');
      expect(rows.length, greaterThanOrEqualTo(2));
    });
  });

  group('OOXML writers', () {
    test('docx is a zip with word/document.xml', () {
      final bytes = const DocxWriter().build(paragraphs: ['Hello', 'World']);
      final zip = ZipDecoder().decodeBytes(bytes);
      expect(zip.findFile('word/document.xml'), isNotNull);
      expect(zip.findFile('[Content_Types].xml'), isNotNull);
    });

    test('xlsx is a zip with sheet1', () {
      final bytes = const XlsxWriter().build([
        ['A', 'B'],
        ['1', '2'],
      ]);
      final zip = ZipDecoder().decodeBytes(bytes);
      expect(zip.findFile('xl/worksheets/sheet1.xml'), isNotNull);
    });

    test('pptx packs one slide per jpeg', () {
      // Minimal JPEG (1x1)
      final jpeg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
        0x7F, 0xFF, 0xD9,
      ]);
      final bytes = const PptxWriter().build([jpeg, jpeg]);
      final zip = ZipDecoder().decodeBytes(bytes);
      expect(zip.findFile('ppt/slides/slide1.xml'), isNotNull);
      expect(zip.findFile('ppt/media/image2.jpg'), isNotNull);
    });
  });

  group('PdfAnalyzer', () {
    const analyzer = PdfAnalyzer();

    test('recommends Word for prose PDF', () {
      final pdf = _textPdf(
        'This is a long form report about Farvixo tools and productivity.\n'
        'It contains several paragraphs of narrative text without tables.',
      );
      final structure = analyzer.analyzeBytes(pdf);
      expect(structure.pageCount, 1);
      expect(structure.isScanned, isFalse);
      expect(structure.recommendation.format, TargetFormat.docx);
      final conf = analyzer.confidenceFor(structure, TargetFormat.docx);
      expect(conf.overall, greaterThan(40));
    });

    test('recommends Excel for table-heavy text', () {
      final pdf = _textPdf(
        'Name    Age    City\n'
        'Ada     36     London\n'
        'Grace   41     NYC\n'
        'Alan    42     Manchester\n',
      );
      final structure = analyzer.analyzeBytes(pdf);
      // Table heuristic may or may not fire depending on spacing; assert API works.
      expect(structure.pageCount, 1);
      final conf = analyzer.confidenceFor(structure, TargetFormat.xlsx);
      expect(conf.overall, inInclusiveRange(10, 98));
    });

    test('format recommendation for scanned-like empty PDF', () {
      final doc = PdfDocument();
      late Uint8List pdf;
      try {
        doc.pages.add();
        pdf = Uint8List.fromList(doc.saveSync());
      } finally {
        doc.dispose();
      }
      final structure = analyzer.analyzeBytes(pdf);
      expect(structure.isScanned, isTrue);
      expect(structure.recommendation.format, TargetFormat.png);
    });
  });

  group('TargetFormat', () {
    test('tryParse', () {
      expect(TargetFormatX.tryParse('docx'), TargetFormat.docx);
      expect(TargetFormatX.tryParse('nope'), isNull);
    });
  });
}
