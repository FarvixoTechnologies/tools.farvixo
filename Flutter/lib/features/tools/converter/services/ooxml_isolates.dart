import 'package:flutter/foundation.dart';

import 'docx_writer.dart';
import 'xlsx_writer.dart';

/// Isolate-friendly OOXML builders (avoid janking UI on large docs).
class OoxmlIsolates {
  const OoxmlIsolates._();

  static Future<Uint8List> buildDocx({
    required List<String> paragraphs,
    List<List<List<String>>> tables = const [],
  }) {
    return compute(_docxWorker, {
      'paragraphs': paragraphs,
      'tables': tables,
    });
  }

  static Future<Uint8List> buildXlsx(List<List<String>> rows) {
    return compute(_xlsxWorker, rows);
  }
}

Uint8List _docxWorker(Map<String, Object?> payload) {
  final paragraphs =
      (payload['paragraphs'] as List<dynamic>).cast<String>();
  final rawTables = (payload['tables'] as List<dynamic>?) ?? const [];
  final tables = rawTables
      .map((t) => (t as List<dynamic>)
          .map((r) => (r as List<dynamic>).cast<String>().toList())
          .toList())
      .toList();
  return const DocxWriter().build(paragraphs: paragraphs, tables: tables);
}

Uint8List _xlsxWorker(List<List<String>> rows) {
  return const XlsxWriter().build(rows);
}
