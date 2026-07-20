import 'package:farvixo_all/features/tools/scanner/models/qr_type.dart';
import 'package:farvixo_all/features/tools/scanner/models/scan_history_entry.dart';
import 'package:farvixo_all/features/tools/scanner/services/qr_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScanHistoryEntry e(String id, String title, QrType type,
          {String raw = 'raw', bool fav = false, bool deleted = false}) =>
      ScanHistoryEntry(
        id: id,
        raw: raw,
        typeIndex: type.index,
        title: title,
        source: 'camera',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1737000000000),
        favorite: fav,
        deletedAt: deleted ? DateTime.now() : null,
      );

  group('CSV', () {
    test('has header + one row per live entry', () {
      final csv = QrExport.toCsv([
        e('1', 'farvixo.com', QrType.url),
        e('2', 'gone', QrType.text, deleted: true),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.first, QrExport.csvHeader);
      expect(lines.length, 2); // header + 1 (deleted skipped)
    });

    test('quotes cells containing commas/quotes', () {
      final csv = QrExport.toCsv([e('1', 'a, "b"', QrType.text)]);
      expect(csv, contains('"a, ""b"""'));
    });
  });

  group('JSON round-trip', () {
    test('toJson → fromJson preserves fields', () {
      final original = [
        e('1', 'farvixo.com', QrType.url, raw: 'https://farvixo.com', fav: true),
        e('2', 'note', QrType.text, raw: 'hello'),
      ];
      final restored = QrExport.fromJson(QrExport.toJson(original));
      expect(restored.length, 2);
      expect(restored[0].id, '1');
      expect(restored[0].type, QrType.url);
      expect(restored[0].favorite, isTrue);
      expect(restored[0].createdAt, original[0].createdAt);
      expect(restored[1].raw, 'hello');
    });
  });

  group('import tolerance', () {
    test('malformed json → empty list, no throw', () {
      expect(QrExport.fromJson('not json'), isEmpty);
      expect(QrExport.fromJson('{}'), isEmpty);
      expect(QrExport.fromJson('{"entries": "x"}'), isEmpty);
    });

    test('skips bad rows but keeps good ones', () {
      const json = '''
      {"entries":[
        {"id":"ok","raw":"hello","typeIndex":11,"createdAtMs":1737000000000},
        {"nope":true},
        {"raw":"missing id"}
      ]}''';
      final out = QrExport.fromJson(json);
      expect(out.length, 1);
      expect(out.single.id, 'ok');
    });
  });
}
