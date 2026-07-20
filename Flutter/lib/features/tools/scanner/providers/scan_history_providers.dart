import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scan_history_repository.dart';
import 'qr_settings_provider.dart';

/// Opens (once) the encrypted Hive-backed history repository. UI watches this
/// and shows a skeleton while it resolves, so app startup stays instant.
final scanHistoryRepositoryProvider =
    FutureProvider<ScanHistoryRepository>((ref) async {
  final repo = await ScanHistoryRepository.open();
  ref.onDispose(repo.close);
  // Enforce the privacy auto-delete retention window on open.
  final retention = ref.read(qrSettingsProvider).retentionDays;
  if (retention > 0) {
    await repo.purgeOlderThan(Duration(days: retention));
  }
  return repo;
});

/// Current filter/search/sort state for the history screen.
final historyQueryProvider =
    StateProvider.autoDispose<HistoryQuery>((ref) => const HistoryQuery());

/// Ids currently selected in multi-select (bulk actions) mode.
final historySelectionProvider =
    StateProvider.autoDispose<Set<String>>((ref) => <String>{});
