import 'dart:convert';

import '../models/qr_type.dart';
import '../models/scan_history_entry.dart';

/// Serialization for history export (CSV / JSON backup) and import (JSON).
/// Pure — no I/O or Flutter imports — so it's fully unit-testable. The UI layer
/// handles file writing / sharing / picking.
class QrExport {
  const QrExport._();

  static const csvHeader =
      'id,type,title,subtitle,raw,source,created_at,favorite,pinned';

  /// Render entries as CSV (RFC-4180 style quoting). Deleted rows are skipped.
  static String toCsv(Iterable<ScanHistoryEntry> entries) {
    final buf = StringBuffer(csvHeader)..write('\n');
    for (final e in entries) {
      if (e.isDeleted) continue;
      buf.writeln([
        e.id,
        e.type.name,
        e.title,
        e.subtitle ?? '',
        e.raw,
        e.source,
        e.createdAt.toIso8601String(),
        e.favorite,
        e.pinned,
      ].map(_csvCell).join(','));
    }
    return buf.toString();
  }

  /// Full-fidelity JSON backup (includes flags + timestamps for round-trip).
  static String toJson(Iterable<ScanHistoryEntry> entries) {
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': [
        for (final e in entries)
          {
            'id': e.id,
            'raw': e.raw,
            'typeIndex': e.typeIndex,
            'title': e.title,
            'subtitle': e.subtitle,
            'source': e.source,
            'createdAtMs': e.createdAt.millisecondsSinceEpoch,
            'favorite': e.favorite,
            'pinned': e.pinned,
            'deletedAtMs': e.deletedAt?.millisecondsSinceEpoch,
          },
      ],
    });
  }

  /// Parse a JSON backup back into entries. Tolerant: malformed rows are
  /// skipped, and a non-conforming document yields an empty list rather than
  /// throwing.
  static List<ScanHistoryEntry> fromJson(String json) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map || decoded['entries'] is! List) return const [];
    final out = <ScanHistoryEntry>[];
    for (final raw in decoded['entries'] as List) {
      if (raw is! Map) continue;
      try {
        final createdMs = (raw['createdAtMs'] as num?)?.toInt() ?? 0;
        final deletedMs = (raw['deletedAtMs'] as num?)?.toInt();
        final id = raw['id'] as String?;
        final value = raw['raw'] as String?;
        if (id == null || value == null) continue;
        out.add(ScanHistoryEntry(
          id: id,
          raw: value,
          typeIndex: (raw['typeIndex'] as num?)?.toInt() ?? QrType.text.index,
          title: raw['title'] as String? ?? value,
          subtitle: raw['subtitle'] as String?,
          source: raw['source'] as String? ?? 'import',
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
          favorite: raw['favorite'] as bool? ?? false,
          pinned: raw['pinned'] as bool? ?? false,
          deletedAt: deletedMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(deletedMs),
        ));
      } catch (_) {
        // Skip a bad row; keep importing the rest.
      }
    }
    return out;
  }

  static String _csvCell(Object? value) {
    final s = '$value';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
