import '../models/qr_type.dart';
import '../models/scan_history_entry.dart';
import 'qr_parser.dart';
import 'qr_security.dart';

/// Locally-computed usage statistics for the scan history. Everything here is
/// derived on-device from Hive rows — no tracking, nothing leaves the phone.
class QrStats {
  const QrStats({
    required this.total,
    required this.today,
    required this.week,
    required this.month,
    required this.byType,
    required this.dailyCounts,
    required this.threats,
  });

  final int total;
  final int today;
  final int week;
  final int month;

  /// Live-entry counts per [QrType] (descending-friendly via [topTypes]).
  final Map<QrType, int> byType;

  /// Scan counts for the last 7 days; index 0 = six days ago … 6 = today.
  final List<int> dailyCounts;

  /// Number of scanned links flagged caution/danger by the offline heuristics.
  final int threats;

  bool get isEmpty => total == 0;

  int get busiestDayCount =>
      dailyCounts.isEmpty ? 0 : dailyCounts.reduce((a, b) => a > b ? a : b);

  /// Types sorted by frequency, most-used first.
  List<MapEntry<QrType, int>> get topTypes {
    final list = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /// Most-used type, or null when there's no history.
  QrType? get topType => topTypes.isEmpty ? null : topTypes.first.key;
}

/// Pure analytics computation over history entries.
class QrAnalytics {
  const QrAnalytics._();

  /// Compute stats from [entries] (deleted rows are ignored). [now] is
  /// injectable for deterministic tests.
  static QrStats compute(Iterable<ScanHistoryEntry> entries, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final startOfToday = DateTime(ref.year, ref.month, ref.day);
    final weekAgo = startOfToday.subtract(const Duration(days: 6));
    final monthAgo = startOfToday.subtract(const Duration(days: 29));

    var total = 0, today = 0, week = 0, month = 0, threats = 0;
    final byType = <QrType, int>{};
    final daily = List<int>.filled(7, 0);

    for (final e in entries) {
      if (e.isDeleted) continue;
      total++;
      byType[e.type] = (byType[e.type] ?? 0) + 1;

      final day = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      if (!day.isBefore(startOfToday)) today++;
      if (!day.isBefore(weekAgo)) week++;
      if (!day.isBefore(monthAgo)) month++;

      final bucket = 6 - startOfToday.difference(day).inDays;
      if (bucket >= 0 && bucket < 7) daily[bucket]++;

      if (e.type == QrType.url || e.type == QrType.appLink) {
        final verdict = QrSecurity.assess(QrParser.parse(e.raw));
        if (verdict.level != RiskLevel.safe) threats++;
      }
    }

    return QrStats(
      total: total,
      today: today,
      week: week,
      month: month,
      byType: byType,
      dailyCounts: daily,
      threats: threats,
    );
  }
}
