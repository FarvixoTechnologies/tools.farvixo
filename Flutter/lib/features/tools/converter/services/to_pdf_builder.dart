import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

/// Convert non-PDF inputs into a Syncfusion PDF.
class ToPdfBuilder {
  const ToPdfBuilder();

  Uint8List fromImages(List<Uint8List> images) {
    final document = PdfDocument();
    try {
      for (final bytes in images) {
        final page = document.pages.add();
        final bitmap = PdfBitmap(bytes);
        final size = page.getClientSize();
        page.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
      }
      return Uint8List.fromList(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  Uint8List fromPlainText(String text, {String title = 'Document'}) {
    final document = PdfDocument();
    try {
      final page = document.pages.add();
      final size = page.getClientSize();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
      final format = PdfTextElement(
        text: text.isEmpty ? ' ' : text,
        font: font,
      );
      format.draw(
        page: page,
        bounds: Rect.fromLTWH(40, 40, size.width - 80, size.height - 80),
      );
      return Uint8List.fromList(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  Uint8List fromHtmlish(String raw) {
    final stripped = raw
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return fromPlainText(stripped);
  }

  Uint8List fromMarkdown(String md) {
    final plain = md
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*|__'), '')
        .replaceAll(RegExp(r'\*|_'), '')
        .replaceAll(RegExp(r'`+'), '');
    return fromPlainText(plain);
  }

  /// Extract paragraphs from a DOCX (OOXML) and draw as PDF text.
  Uint8List fromDocx(Uint8List docxBytes) {
    final archive = ZipDecoder().decodeBytes(docxBytes);
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      throw StateError('Invalid DOCX — missing word/document.xml');
    }
    final xml = XmlDocument.parse(utf8.decode(docFile.content as List<int>));
    final paragraphs = <String>[];
    for (final p in xml.findAllElements('w:t', namespace: '*')) {
      // Collect at run level — group by parent paragraph later.
      paragraphs.add(p.innerText);
    }
    // Better: walk w:p nodes
    final lines = <String>[];
    for (final p in xml.findAllElements('w:p', namespace: '*')) {
      final texts = p.findAllElements('w:t', namespace: '*').map((e) => e.innerText);
      final line = texts.join();
      if (line.trim().isNotEmpty) lines.add(line);
    }
    final body = lines.isNotEmpty ? lines.join('\n\n') : paragraphs.join(' ');
    return fromPlainText(body.isEmpty ? ' ' : body);
  }

  /// Simple CSV/XLSX → PDF table layout (CSV path for xlsx: extract shared strings).
  Uint8List fromCsv(String csv) {
    final rows = csv
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map(_parseCsvLine)
        .toList();
    return _tablePdf(rows);
  }

  Uint8List fromXlsx(Uint8List xlsxBytes) {
    final archive = ZipDecoder().decodeBytes(xlsxBytes);
    final shared = <String>[];
    final ss = archive.findFile('xl/sharedStrings.xml');
    if (ss != null) {
      final xml = XmlDocument.parse(utf8.decode(ss.content as List<int>));
      for (final si in xml.findAllElements('si', namespace: '*')) {
        final t = si.findAllElements('t', namespace: '*').map((e) => e.innerText).join();
        shared.add(t);
      }
    }
    final sheet = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheet == null) return fromPlainText('Empty spreadsheet');
    final xml = XmlDocument.parse(utf8.decode(sheet.content as List<int>));
    final rows = <List<String>>[];
    for (final row in xml.findAllElements('row', namespace: '*')) {
      final cells = <String>[];
      for (final c in row.findAllElements('c', namespace: '*')) {
        final t = c.getAttribute('t');
        final v = c.getElement('v', namespace: '*')?.innerText ??
            c.findAllElements('t', namespace: '*').map((e) => e.innerText).join();
        if (t == 's' && v.isNotEmpty) {
          final idx = int.tryParse(v) ?? 0;
          cells.add(idx < shared.length ? shared[idx] : v);
        } else if (t == 'inlineStr') {
          cells.add(
            c.findAllElements('t', namespace: '*').map((e) => e.innerText).join(),
          );
        } else {
          cells.add(v);
        }
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return _tablePdf(rows);
  }

  Uint8List _tablePdf(List<List<String>> rows) {
    final document = PdfDocument();
    try {
      if (rows.isEmpty) {
        return fromPlainText(' ');
      }
      var page = document.pages.add();
      var y = 40.0;
      final size = page.getClientSize();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 9);
      final colCount = rows.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);
      final colW = (size.width - 80) / colCount.clamp(1, 12);

      for (final row in rows) {
        if (y > size.height - 60) {
          page = document.pages.add();
          y = 40;
        }
        var x = 40.0;
        for (var i = 0; i < colCount; i++) {
          final cell = i < row.length ? row[i] : '';
          page.graphics.drawString(
            cell.length > 40 ? '${cell.substring(0, 40)}…' : cell,
            font,
            bounds: Rect.fromLTWH(x, y, colW - 4, 16),
          );
          x += colW;
        }
        y += 18;
      }
      return Uint8List.fromList(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    cells.add(buf.toString());
    return cells;
  }

  /// Decode common image bytes; re-encode as PNG if Syncfusion needs it.
  Uint8List normalizeImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      return Uint8List.fromList(img.encodePng(decoded));
    } catch (_) {
      return bytes;
    }
  }
}
