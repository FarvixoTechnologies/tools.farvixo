import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/qr_type.dart';
import '../models/scan_history_entry.dart';

/// History sort orders.
enum HistorySort { newest, oldest, type }

/// A filter over the scan history.
class HistoryQuery {
  const HistoryQuery({
    this.search = '',
    this.typeFilter,
    this.sort = HistorySort.newest,
    this.favoritesOnly = false,
    this.includeDeleted = false,
  });

  final String search;

  /// Restrict to one [QrType], or null for all.
  final QrType? typeFilter;

  final HistorySort sort;
  final bool favoritesOnly;

  /// When true, returns ONLY soft-deleted rows (the "Recently Deleted" view).
  final bool includeDeleted;

  HistoryQuery copyWith({
    String? search,
    QrType? typeFilter,
    bool clearTypeFilter = false,
    HistorySort? sort,
    bool? favoritesOnly,
    bool? includeDeleted,
  }) =>
      HistoryQuery(
        search: search ?? this.search,
        typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
        sort: sort ?? this.sort,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        includeDeleted: includeDeleted ?? this.includeDeleted,
      );
}

/// Repository over an (optionally encrypted) Hive box of [ScanHistoryEntry].
///
/// Pure data access + query logic — no Flutter/UI imports beyond Hive so it
/// stays unit-testable by injecting a plain (unencrypted) box. Production code
/// uses [open] which wires the encrypted box + secure-storage key.
class ScanHistoryRepository {
  ScanHistoryRepository(this._box);

  final Box<ScanHistoryEntry> _box;

  static const boxName = 'qr_scan_history';
  static const _keyName = 'qr_history_hive_key';
  static const _adapterTypeId = 42;

  /// Recently-deleted retention before automatic purge.
  static const trashTtl = Duration(days: 30);

  /// Reactive handle for the UI (drives ValueListenableBuilder).
  Listenable get listenable => _box.listenable();

  // ─────────────────────────────────────────────────────── production open

  /// Open the encrypted history box, creating (and securely storing) the AES
  /// key on first run. Registers the adapter and runs pending migrations.
  static Future<ScanHistoryRepository> open({
    FlutterSecureStorage? secureStorage,
  }) async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(_adapterTypeId)) {
      Hive.registerAdapter(ScanHistoryEntryAdapter());
    }
    final storage = secureStorage ?? const FlutterSecureStorage();
    final key = await _readOrCreateKey(storage);
    final box = await Hive.openBox<ScanHistoryEntry>(
      boxName,
      encryptionCipher: HiveAesCipher(key),
    );
    final repo = ScanHistoryRepository(box);
    await repo.runMaintenance();
    return repo;
  }

  static Future<List<int>> _readOrCreateKey(FlutterSecureStorage storage) async {
    final existing = await storage.read(key: _keyName);
    if (existing != null) {
      try {
        return _decodeKey(existing);
      } catch (_) {
        // Corrupt key material — regenerate rather than crash.
      }
    }
    final key = Hive.generateSecureKey();
    await storage.write(key: _keyName, value: key.join(','));
    return key;
  }

  static List<int> _decodeKey(String raw) =>
      raw.split(',').map(int.parse).toList(growable: false);

  // ─────────────────────────────────────────────────────────────── writes

  /// Insert a scan/generate record and return its id.
  Future<String> add(ScanHistoryEntry entry) async {
    await _box.put(entry.id, entry);
    return entry.id;
  }

  /// Convenience factory + insert from a decoded value.
  Future<ScanHistoryEntry> record({
    required String raw,
    required QrType type,
    required String title,
    String? subtitle,
    String source = 'camera',
  }) async {
    final entry = ScanHistoryEntry(
      id: newId(),
      raw: raw,
      typeIndex: type.index,
      title: title,
      subtitle: subtitle,
      source: source,
      createdAt: DateTime.now(),
    );
    await add(entry);
    return entry;
  }

  ScanHistoryEntry? byId(String id) => _box.get(id);

  Future<void> toggleFavorite(String id) async {
    final e = _box.get(id);
    if (e == null) return;
    await _box.put(id, e.copyWith(favorite: !e.favorite));
  }

  Future<void> togglePin(String id) async {
    final e = _box.get(id);
    if (e == null) return;
    await _box.put(id, e.copyWith(pinned: !e.pinned));
  }

  /// Soft-delete → moves to "Recently Deleted". [restore] undoes it.
  Future<void> softDelete(String id) async {
    final e = _box.get(id);
    if (e == null) return;
    await _box.put(id, e.copyWith(deletedAt: DateTime.now()));
  }

  Future<void> restore(String id) async {
    final e = _box.get(id);
    if (e == null) return;
    await _box.put(id, e.copyWith(clearDeletedAt: true));
  }

  /// Permanently remove a record.
  Future<void> deleteForever(String id) => _box.delete(id);

  // Bulk actions.
  Future<void> softDeleteMany(Iterable<String> ids) async {
    final now = DateTime.now();
    await _box.putAll({
      for (final id in ids)
        if (_box.get(id) case final e?) id: e.copyWith(deletedAt: now),
    });
  }

  Future<void> restoreMany(Iterable<String> ids) async {
    await _box.putAll({
      for (final id in ids)
        if (_box.get(id) case final e?) id: e.copyWith(clearDeletedAt: true),
    });
  }

  Future<void> favoriteMany(Iterable<String> ids, {required bool favorite}) async {
    await _box.putAll({
      for (final id in ids)
        if (_box.get(id) case final e?) id: e.copyWith(favorite: favorite),
    });
  }

  Future<void> deleteForeverMany(Iterable<String> ids) => _box.deleteAll(ids);

  /// Empty the "Recently Deleted" bin.
  Future<void> emptyTrash() async {
    final ids = _box.values.where((e) => e.isDeleted).map((e) => e.id).toList();
    await _box.deleteAll(ids);
  }

  /// Purge trashed rows older than [trashTtl]. Called on open.
  Future<int> runMaintenance() async {
    final cutoff = DateTime.now().subtract(trashTtl);
    final expired = _box.values
        .where((e) => e.deletedAt != null && e.deletedAt!.isBefore(cutoff))
        .map((e) => e.id)
        .toList();
    if (expired.isNotEmpty) await _box.deleteAll(expired);
    return expired.length;
  }

  /// Auto-delete ALL records (live or trashed) created before [age] ago — the
  /// privacy "auto-delete history" retention setting. Returns how many went.
  Future<int> purgeOlderThan(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    final old = _box.values
        .where((e) => e.createdAt.isBefore(cutoff))
        .map((e) => e.id)
        .toList();
    if (old.isNotEmpty) await _box.deleteAll(old);
    return old.length;
  }

  /// Wipe the entire history ("clear all data").
  Future<void> clearAll() => _box.clear();

  /// Merge imported entries into the store (keyed by id, so re-importing the
  /// same backup is idempotent). Returns how many were added or updated.
  Future<int> importEntries(Iterable<ScanHistoryEntry> entries) async {
    final map = {for (final e in entries) e.id: e};
    if (map.isEmpty) return 0;
    await _box.putAll(map);
    return map.length;
  }

  // ─────────────────────────────────────────────────────────────── reads

  /// All live (non-deleted) entries, unfiltered.
  int get count => _box.values.where((e) => !e.isDeleted).length;

  int get favoritesCount =>
      _box.values.where((e) => !e.isDeleted && e.favorite).length;

  int get trashCount => _box.values.where((e) => e.isDeleted).length;

  /// Per-type counts of live entries (feeds analytics + filter chips).
  Map<QrType, int> countsByType() {
    final out = <QrType, int>{};
    for (final e in _box.values) {
      if (e.isDeleted) continue;
      out[e.type] = (out[e.type] ?? 0) + 1;
    }
    return out;
  }

  /// Filtered + sorted view. Pinned live entries always float to the top
  /// (except in the trash view). Use [page]/[pageSize] for lazy loading.
  List<ScanHistoryEntry> query(
    HistoryQuery q, {
    int page = 0,
    int pageSize = 30,
  }) {
    final all = _filterSort(q);
    if (pageSize <= 0) return all;
    final start = page * pageSize;
    if (start >= all.length) return const [];
    return all.sublist(start, min(start + pageSize, all.length));
  }

  /// Total rows matching a query (for "showing X of Y" + hasMore).
  int matchCount(HistoryQuery q) => _filterSort(q).length;

  List<ScanHistoryEntry> _filterSort(HistoryQuery q) {
    final search = q.search.trim().toLowerCase();
    final list = _box.values.where((e) {
      if (q.includeDeleted != e.isDeleted) return false;
      if (q.favoritesOnly && !e.favorite) return false;
      if (q.typeFilter != null && e.type != q.typeFilter) return false;
      if (search.isNotEmpty) {
        final hay = '${e.title} ${e.subtitle ?? ''} ${e.raw}'.toLowerCase();
        if (!hay.contains(search)) return false;
      }
      return true;
    }).toList();

    int byRecency(ScanHistoryEntry a, ScanHistoryEntry b) =>
        b.createdAt.compareTo(a.createdAt);

    list.sort((a, b) {
      // Pinned first in live views.
      if (!q.includeDeleted && a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return switch (q.sort) {
        HistorySort.newest => byRecency(a, b),
        HistorySort.oldest => a.createdAt.compareTo(b.createdAt),
        HistorySort.type => a.type.index != b.type.index
            ? a.type.index.compareTo(b.type.index)
            : byRecency(a, b),
      };
    });
    return list;
  }

  /// A stable-ish unique id.
  static String newId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(0x3ffff).toRadixString(16);
    return '$ts-$rnd';
  }

  Future<void> close() => _box.close();
}
