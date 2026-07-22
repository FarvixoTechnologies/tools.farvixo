import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tools_data.dart';
import '../models/tool_model.dart';
import '../services/storage_service.dart';
import '../utils/tool_search.dart';
import 'app_providers.dart';
import 'tool_repository_provider.dart';

/// Persisted recent search queries (newest first).
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RecentSearchesNotifier(storage.recentSearches, storage);
});

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier(super.state, this._storage);

  final StorageService _storage;

  Future<void> add(String query) async {
    await _storage.addRecentSearch(query);
    state = List<String>.from(_storage.recentSearches);
  }

  Future<void> clear() async {
    await _storage.clearRecentSearches();
    state = const [];
  }

  Future<void> remove(String query) async {
    final next = [
      for (final q in state)
        if (q.toLowerCase() != query.toLowerCase()) q,
    ];
    await _storage.setRecentSearches(next);
    state = next;
  }
}

/// Parameters for live advanced search.
class LiveSearchQuery {
  const LiveSearchQuery({
    required this.text,
    this.categoryId,
    this.filter = ToolSearchFilter.all,
  });

  final String text;
  final String? categoryId;
  final ToolSearchFilter filter;

  @override
  bool operator ==(Object other) =>
      other is LiveSearchQuery &&
      other.text == text &&
      other.categoryId == categoryId &&
      other.filter == filter;

  @override
  int get hashCode => Object.hash(text, categoryId, filter);
}

/// Instant ranked results from the warm catalog (no network wait).
final liveToolSearchProvider =
    Provider.autoDispose.family<List<Tool>, LiveSearchQuery>((ref, query) {
  final catalog = ref.watch(toolsResultProvider).valueOrNull?.items ??
      ToolsData.tools;
  return ToolSearch.searchTools(
    catalog,
    query.text,
    categoryId: query.categoryId,
    filter: query.filter,
  );
});

/// Optional network enrichment — merges remote hits after local ranking.
final enrichedToolSearchProvider = FutureProvider.autoDispose
    .family<List<Tool>, LiveSearchQuery>((ref, query) async {
  final local = ref.watch(liveToolSearchProvider(query));
  final q = query.text.trim();
  if (q.isEmpty) return local;

  try {
    final remote =
        await ref.watch(toolRepositoryProvider).searchTools(q);
    var merged = ToolSearch.merge(local, remote.items);
    // Re-apply category / filter on remote-only appends.
    if (query.categoryId != null && query.categoryId!.isNotEmpty) {
      merged = merged
          .where((t) => t.categoryId == query.categoryId)
          .toList();
    }
    if (query.filter != ToolSearchFilter.all) {
      merged = ToolSearch.searchTools(
        merged,
        q,
        categoryId: query.categoryId,
        filter: query.filter,
      );
    }
    return merged;
  } catch (_) {
    return local;
  }
});
