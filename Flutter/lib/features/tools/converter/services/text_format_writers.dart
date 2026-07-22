import 'dart:convert';
import 'dart:typed_data';

/// Pure-Dart writers for txt / md / html / rtf / csv.
class TextFormatWriters {
  const TextFormatWriters();

  Uint8List toTxt(String text) => Uint8List.fromList(utf8.encode(text));

  Uint8List toMd(String text) {
    final lines = text.split('\n');
    final out = StringBuffer();
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        out.writeln();
        continue;
      }
      final upper = line == line.toUpperCase() &&
          line.length > 3 &&
          RegExp(r'[A-Z]').hasMatch(line);
      if (upper) {
        out.writeln('## $line');
      } else {
        out.writeln(line);
      }
    }
    return Uint8List.fromList(utf8.encode(out.toString()));
  }

  Uint8List toHtml(String text, {String title = 'Farvixo Export'}) {
    final escaped = _escapeHtml(text);
    final paragraphs = escaped
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => '<p>${p.replaceAll('\n', '<br/>')}</p>')
        .join('\n');
    final html = '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>${_escapeHtml(title)}</title>
<style>
body{font-family:system-ui,Segoe UI,sans-serif;line-height:1.55;max-width:720px;margin:2rem auto;padding:0 1rem;color:#1a1a28}
table{border-collapse:collapse;width:100%;margin:1rem 0}
td,th{border:1px solid #ccc;padding:.4rem .6rem}
</style>
</head>
<body>
$paragraphs
</body>
</html>
''';
    return Uint8List.fromList(utf8.encode(html));
  }

  Uint8List toRtf(String text) {
    final buf = StringBuffer(r'{\rtf1\ansi\deff0');
    buf.write(r'{\fonttbl{\f0 Arial;}}');
    buf.write(r'\f0\fs22 ');
    for (final line in text.split('\n')) {
      buf.write(_escapeRtf(line));
      buf.write(r'\par ');
    }
    buf.write('}');
    return Uint8List.fromList(utf8.encode(buf.toString()));
  }

  Uint8List toCsv(List<List<String>> rows) {
    final buf = StringBuffer();
    for (final row in rows) {
      buf.writeln(row.map(_escapeCsv).join(','));
    }
    return Uint8List.fromList(utf8.encode(buf.toString()));
  }

  /// Heuristic: split lines that look tabular into CSV rows.
  List<List<String>> tablesFromText(String text) {
    final rows = <List<String>>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      List<String> cells;
      if (trimmed.contains('\t')) {
        cells = trimmed.split('\t');
      } else if (trimmed.contains('|')) {
        cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
      } else if (RegExp(r'\s{2,}').hasMatch(trimmed)) {
        cells = trimmed.split(RegExp(r'\s{2,}'));
      } else {
        continue;
      }
      if (cells.length >= 2) rows.add(cells);
    }
    return rows;
  }

  String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _escapeRtf(String s) {
    final buf = StringBuffer();
    for (final cu in s.runes) {
      if (cu == 0x5C) {
        buf.write(r'\\');
      } else if (cu == 0x7B) {
        buf.write(r'\{');
      } else if (cu == 0x7D) {
        buf.write(r'\}');
      } else if (cu > 127) {
        buf.write('\\u$cu?');
      } else {
        buf.writeCharCode(cu);
      }
    }
    return buf.toString();
  }

  String _escapeCsv(String cell) {
    if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }
}
