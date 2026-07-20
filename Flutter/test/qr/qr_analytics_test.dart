import 'package:farvixo_all/features/tools/scanner/models/qr_type.dart';
import 'package:farvixo_all/features/tools/scanner/models/scan_history_entry.dart';
import 'package:farvixo_all/features/tools/scanner/services/qr_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 15, 12);

  ScanHistoryEntry at(DateTime d,
          {QrType type = QrType.text, String raw = 'x', bool deleted = false}) =>
      ScanHistoryEntry(
        id: '${d.microsecondsSinceEpoch}-$raw',
        raw: raw,
        typeIndex: type.index,
        title: raw,
        createdAt: d,
        deletedAt: deleted ? d : null,
      );

  test('empty history → zeroed stats', () {
    final s = QrAnalytics.compute(const [], now: now);
    expect(s.isEmpty, isTrue);
    expect(s.total, 0);
    expect(s.dailyCounts, List.filled(7, 0));
    expect(s.topType, isNull);
  });

  test('counts today / week / month windows', () {
    final s = QrAnalytics.compute([
      at(now), // today
      at(now.subtract(const Duration(days: 3))), // this week + month
      at(now.subtract(const Duration(days: 10))), // this month only
      at(now.subtract(const Duration(days: 40))), // outside all windows
    ], now: now);
    expect(s.total, 4);
    expect(s.today, 1);
    expect(s.week, 2);
    expect(s.month, 3);
  });

  test('ignores deleted entries', () {
    final s = QrAnalytics.compute([
      at(now),
      at(now, deleted: true),
    ], now: now);
    expect(s.total, 1);
  });

  test('daily buckets map last 7 days with today last', () {
    final s = QrAnalytics.compute([
      at(now), // today → index 6
      at(now), // today → index 6
      at(now.subtract(const Duration(days: 6))), // index 0
    ], now: now);
    expect(s.dailyCounts[6], 2);
    expect(s.dailyCounts[0], 1);
    expect(s.busiestDayCount, 2);
  });

  test('byType + topType ranking', () {
    final s = QrAnalytics.compute([
      at(now, type: QrType.url),
      at(now, type: QrType.url),
      at(now, type: QrType.wifi),
    ], now: now);
    expect(s.byType[QrType.url], 2);
    expect(s.byType[QrType.wifi], 1);
    expect(s.topType, QrType.url);
  });

  test('threats counts risky links only', () {
    final s = QrAnalytics.compute([
      at(now, type: QrType.url, raw: 'https://farvixo.com'), // safe
      at(now, type: QrType.url, raw: 'http://192.168.0.1/login'), // danger
      at(now, type: QrType.url, raw: 'https://bit.ly/x'), // caution
      at(now, type: QrType.text, raw: 'hello'), // not a link
    ], now: now);
    expect(s.threats, 2);
  });
}
