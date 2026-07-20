import 'dart:io';

import 'package:farvixo_all/features/tools/scanner/data/scan_history_repository.dart';
import 'package:farvixo_all/features/tools/scanner/models/qr_type.dart';
import 'package:farvixo_all/features/tools/scanner/models/scan_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box<ScanHistoryEntry> box;
  late ScanHistoryRepository repo;
  var seq = 0;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('qr_hist_test');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(42)) {
      Hive.registerAdapter(ScanHistoryEntryAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  setUp(() async {
    box = await Hive.openBox<ScanHistoryEntry>('box_${seq++}');
    repo = ScanHistoryRepository(box);
  });

  tearDown(() async => box.close());

  ScanHistoryEntry make({
    required String id,
    required QrType type,
    String title = 't',
    DateTime? at,
    bool favorite = false,
    bool pinned = false,
    DateTime? deletedAt,
    String raw = 'raw',
  }) =>
      ScanHistoryEntry(
        id: id,
        raw: raw,
        typeIndex: type.index,
        title: title,
        source: 'camera',
        createdAt: at ?? DateTime.now(),
        favorite: favorite,
        pinned: pinned,
        deletedAt: deletedAt,
      );

  group('CRUD + record', () {
    test('record + count', () async {
      await repo.record(raw: 'https://a.com', type: QrType.url, title: 'a.com');
      await repo.record(raw: 'hello', type: QrType.text, title: 'hello');
      expect(repo.count, 2);
      expect(box.length, 2);
    });

    test('byId returns the stored entry', () async {
      final e = await repo.record(raw: 'x', type: QrType.text, title: 'x');
      expect(repo.byId(e.id)!.raw, 'x');
    });
  });

  group('query: filter/sort/pagination', () {
    setUp(() async {
      final base = DateTime(2026, 1, 10, 12);
      await repo.add(make(id: '1', type: QrType.url, title: 'apple',
          at: base));
      await repo.add(make(id: '2', type: QrType.wifi, title: 'banana',
          at: base.add(const Duration(hours: 1))));
      await repo.add(make(id: '3', type: QrType.url, title: 'cherry',
          at: base.add(const Duration(hours: 2)), favorite: true));
    });

    test('newest first by default', () {
      final r = repo.query(const HistoryQuery());
      expect(r.map((e) => e.id), ['3', '2', '1']);
    });

    test('oldest sort', () {
      final r = repo.query(const HistoryQuery(sort: HistorySort.oldest));
      expect(r.map((e) => e.id), ['1', '2', '3']);
    });

    test('type filter', () {
      final r = repo.query(const HistoryQuery(typeFilter: QrType.url));
      expect(r.map((e) => e.id).toSet(), {'1', '3'});
    });

    test('search matches title/raw', () {
      final r = repo.query(const HistoryQuery(search: 'ban'));
      expect(r.single.id, '2');
    });

    test('favorites only', () {
      final r = repo.query(const HistoryQuery(favoritesOnly: true));
      expect(r.single.id, '3');
    });

    test('pagination', () {
      final p0 = repo.query(const HistoryQuery(), page: 0, pageSize: 2);
      final p1 = repo.query(const HistoryQuery(), page: 1, pageSize: 2);
      expect(p0.length, 2);
      expect(p1.length, 1);
      expect(repo.matchCount(const HistoryQuery()), 3);
    });

    test('pinned floats to top regardless of recency', () async {
      await repo.togglePin('1'); // oldest, now pinned
      final r = repo.query(const HistoryQuery());
      expect(r.first.id, '1');
    });
  });

  group('favorites + pins', () {
    test('toggleFavorite flips and counts', () async {
      final e = await repo.record(raw: 'x', type: QrType.text, title: 'x');
      await repo.toggleFavorite(e.id);
      expect(repo.byId(e.id)!.favorite, isTrue);
      expect(repo.favoritesCount, 1);
      await repo.toggleFavorite(e.id);
      expect(repo.byId(e.id)!.favorite, isFalse);
    });
  });

  group('soft delete / restore / trash', () {
    test('softDelete hides from live, shows in trash', () async {
      final e = await repo.record(raw: 'x', type: QrType.text, title: 'x');
      await repo.softDelete(e.id);
      expect(repo.count, 0);
      expect(repo.trashCount, 1);
      expect(repo.query(const HistoryQuery(includeDeleted: true)).length, 1);
    });

    test('restore brings it back', () async {
      final e = await repo.record(raw: 'x', type: QrType.text, title: 'x');
      await repo.softDelete(e.id);
      await repo.restore(e.id);
      expect(repo.count, 1);
      expect(repo.trashCount, 0);
    });

    test('runMaintenance purges only expired trash', () async {
      await repo.add(make(
        id: 'old',
        type: QrType.text,
        deletedAt: DateTime.now().subtract(const Duration(days: 40)),
      ));
      await repo.add(make(
        id: 'recent',
        type: QrType.text,
        deletedAt: DateTime.now().subtract(const Duration(days: 2)),
      ));
      final purged = await repo.runMaintenance();
      expect(purged, 1);
      expect(repo.byId('old'), isNull);
      expect(repo.byId('recent'), isNotNull);
    });
  });

  group('bulk actions', () {
    test('softDeleteMany + restoreMany + favoriteMany', () async {
      for (final id in ['a', 'b', 'c']) {
        await repo.add(make(id: id, type: QrType.text));
      }
      await repo.softDeleteMany(['a', 'b']);
      expect(repo.count, 1);
      await repo.restoreMany(['a']);
      expect(repo.count, 2);
      await repo.favoriteMany(['a', 'c'], favorite: true);
      expect(repo.favoritesCount, 2);
    });

    test('emptyTrash removes all deleted', () async {
      await repo.add(make(id: 'a', type: QrType.text,
          deletedAt: DateTime.now()));
      await repo.add(make(id: 'b', type: QrType.text));
      await repo.emptyTrash();
      expect(repo.trashCount, 0);
      expect(repo.count, 1);
    });
  });

  group('retention + clear (privacy)', () {
    test('purgeOlderThan removes live + trashed rows past the window', () async {
      await repo.add(make(id: 'old-live', type: QrType.text,
          at: DateTime.now().subtract(const Duration(days: 40))));
      await repo.add(make(id: 'old-trash', type: QrType.text,
          at: DateTime.now().subtract(const Duration(days: 40)),
          deletedAt: DateTime.now()));
      await repo.add(make(id: 'fresh', type: QrType.text));
      final purged = await repo.purgeOlderThan(const Duration(days: 30));
      expect(purged, 2);
      expect(repo.byId('fresh'), isNotNull);
    });

    test('clearAll wipes everything', () async {
      for (final id in ['a', 'b', 'c']) {
        await repo.add(make(id: id, type: QrType.text));
      }
      await repo.clearAll();
      expect(repo.count, 0);
      expect(box.isEmpty, isTrue);
    });
  });

  test('countsByType ignores deleted', () async {
    await repo.add(make(id: '1', type: QrType.url));
    await repo.add(make(id: '2', type: QrType.url));
    await repo.add(make(id: '3', type: QrType.wifi,
        deletedAt: DateTime.now()));
    final counts = repo.countsByType();
    expect(counts[QrType.url], 2);
    expect(counts[QrType.wifi], isNull);
  });
}
