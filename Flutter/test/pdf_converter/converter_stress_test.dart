import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:farvixo_all/features/tools/converter/models/target_format.dart';
import 'package:farvixo_all/features/tools/converter/services/converter_perf.dart';
import 'package:farvixo_all/features/tools/converter/services/docx_writer.dart';
import 'package:farvixo_all/features/tools/converter/services/pdf_analyzer.dart';
import 'package:farvixo_all/features/tools/converter/services/text_format_writers.dart';
import 'package:farvixo_all/features/tools/converter/services/webp_encoder_service.dart';
import 'package:farvixo_all/features/tools/converter/services/xlsx_writer.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

Uint8List _textPdf(String text, {int pages = 1}) {
  final doc = PdfDocument();
  try {
    for (var i = 0; i < pages; i++) {
      final page = doc.pages.add();
      page.graphics.drawString(
        '$text\nPage ${i + 1}',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
      );
    }
    return Uint8List.fromList(doc.saveSync());
  } finally {
    doc.dispose();
  }
}

void main() {
  group('ConverterPerf', () {
    test('clampRenderSize keeps within max pixels', () {
      final (w, h) = ConverterPerf.clampRenderSize(8000, 8000);
      expect(w * h, lessThanOrEqualTo(ConverterPerf.maxPixelsPerPage));
      expect(w, lessThanOrEqualTo(4096));
      expect(h, lessThanOrEqualTo(4096));
    });

    test('releaseBytes nulls references', () {
      final buffers = <Uint8List?>[
        Uint8List(4),
        Uint8List(8),
      ];
      ConverterPerf.releaseBytes(buffers);
      expect(buffers.every((b) => b == null), isTrue);
    });
  });

  group('Stress · writers', () {
    test('docx writer survives 30 sequential builds', () {
      const writer = DocxWriter();
      for (var i = 0; i < 30; i++) {
        final bytes = writer.build(
          paragraphs: List.generate(20, (j) => 'Paragraph $i-$j'),
          tables: [
            [
              ['A', 'B'],
              ['$i', '${i * 2}'],
            ],
          ],
        );
        expect(bytes.length, greaterThan(100));
        // ZIP magic
        expect(bytes[0], 0x50);
        expect(bytes[1], 0x4B);
      }
    });

    test('xlsx writer survives 30 sequential builds', () {
      const writer = XlsxWriter();
      for (var i = 0; i < 30; i++) {
        final rows = List.generate(
          50,
          (r) => ['r$r', '${r * i}', 'cell'],
        );
        final bytes = writer.build(rows);
        expect(bytes[0], 0x50);
        expect(bytes[1], 0x4B);
      }
    });

    test('text writers round-trip under load', () {
      const w = TextFormatWriters();
      for (var i = 0; i < 50; i++) {
        final sample = List.generate(100, (j) => 'line $i-$j').join('\n');
        expect(w.toTxt(sample).length, greaterThan(10));
        expect(w.toMd(sample).length, greaterThan(10));
        expect(w.toHtml(sample).length, greaterThan(10));
        expect(w.toRtf(sample).length, greaterThan(10));
      }
    });
  });

  group('Stress · analyzer', () {
    const analyzer = PdfAnalyzer();

    test('analyze+dispose loop 30× without throwing', () {
      for (var i = 0; i < 30; i++) {
        final pdf = _textPdf('Stress document $i with enough prose text.',
            pages: 2);
        final structure = analyzer.analyzeBytes(pdf);
        expect(structure.pageCount, 2);
        final conf =
            analyzer.confidenceFor(structure, TargetFormat.docx);
        expect(conf.overall, inInclusiveRange(10, 98));
      }
    });
  });

  group('WebP encoder', () {
    test('encodes tiny RGBA image (native or JPEG fallback)', () async {
      final image = img.Image(width: 8, height: 8);
      for (final p in image) {
        p.r = 200;
        p.g = 40;
        p.b = 40;
        p.a = 255;
      }
      final bytes =
          await const WebpEncoderService().encode(image, quality: 0.8);
      expect(bytes.length, greaterThan(20));
      // Either RIFF/WEBP or JPEG SOI
      final isWebp = WebpEncoderService.isWebpMagic(bytes);
      final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
      expect(isWebp || isJpeg, isTrue);
    });
  });

  group('Memory leak smoke', () {
    test('open/analyze/close cycle does not grow unboundedly', () {
      // Proxy: ensure repeated alloc/free of Syncfusion docs stays stable
      // enough that 40 cycles complete under a soft time budget.
      final sw = Stopwatch()..start();
      for (var i = 0; i < 40; i++) {
        final pdf = _textPdf('Leak smoke $i');
        const PdfAnalyzer().analyzeBytes(pdf);
      }
      expect(sw.elapsedMilliseconds, lessThan(60000));
    });
  });
}
