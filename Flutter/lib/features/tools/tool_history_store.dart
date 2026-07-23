/// Per-tool result history — a lightweight record of the last few successful
/// runs, so every one of the 143 tools gains a "Recent" list with no per-tool
/// code. Mirrors [ToolDraftStore]: local SharedPreferences, JSON-encoded,
/// capped so it never grows without bound.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ToolHistoryEntry {
  const ToolHistoryEntry({
    required this.summary,
    required this.timestamp,
    this.fileName,
  });

  /// Short human line, e.g. "2.3 MB → 1.1 MB (52% smaller)".
  final String summary;

  /// Output file name when the result was a file (null for text results).
  final String? fileName;

  final DateTime timestamp;

  Map<String, Object?> toJson() => {
        's': summary,
        'f': fileName,
        't': timestamp.millisecondsSinceEpoch,
      };

  static ToolHistoryEntry fromJson(Map<String, Object?> j) => ToolHistoryEntry(
        summary: (j['s'] as String?) ?? '',
        fileName: j['f'] as String?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (j['t'] as num?)?.toInt() ?? 0),
      );

  /// "just now", "5m ago", "2h ago", "3d ago".
  String ago([DateTime? now]) {
    final d = (now ?? DateTime.now()).difference(timestamp);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class ToolHistoryStore {
  ToolHistoryStore._();
  static final instance = ToolHistoryStore._();

  /// Keep the most recent [maxEntries] runs per tool.
  static const maxEntries = 8;

  static String _key(String toolId) => 'tool_history_$toolId';

  Future<List<ToolHistoryEntry>> load(String toolId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(toolId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ToolHistoryEntry.fromJson)
          .toList();
      return list;
    } catch (_) {
      // Corrupt entry must never break the tool — treat as empty.
      return const [];
    }
  }

  /// Prepends [entry], de-dupes trivially identical consecutive summaries,
  /// and trims to [maxEntries].
  Future<void> add(String toolId, ToolHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load(toolId);
    if (current.isNotEmpty && current.first.summary == entry.summary) {
      return; // ignore an exact repeat of the last run
    }
    final next = [entry, ...current].take(maxEntries).toList();
    await prefs.setString(
      _key(toolId),
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear(String toolId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(toolId));
  }
}
