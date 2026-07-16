import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tools_data.dart';
import '../models/tool_model.dart';
import 'app_providers.dart';

/// Recently used tools — most recent first, deduplicated, capped, persisted
/// (see docs/HOME_DASHBOARD_SYSTEM.md — Recently Used).
final recentToolsProvider =
    StateNotifierProvider<RecentToolsNotifier, List<String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RecentToolsNotifier(storage.recentToolIds, storage.setRecentToolIds);
});

class RecentToolsNotifier extends StateNotifier<List<String>> {
  RecentToolsNotifier(List<String> saved, this._persist) : super(saved);

  static const _maxItems = 10;

  final Future<void> Function(List<String>) _persist;

  void recordUse(String toolId) {
    final ids = [toolId, ...state.where((id) => id != toolId)];
    state = ids.take(_maxItems).toList();
    _persist(state);
  }

  void clear() {
    state = [];
    _persist(state);
  }
}

/// Favorite (pinned) tools — persisted, toggleable
/// (see docs/HOME_DASHBOARD_SYSTEM.md — Favorites).
final favoriteToolsProvider =
    StateNotifierProvider<FavoriteToolsNotifier, List<String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return FavoriteToolsNotifier(
      storage.favoriteToolIds, storage.setFavoriteToolIds);
});

class FavoriteToolsNotifier extends StateNotifier<List<String>> {
  FavoriteToolsNotifier(List<String> saved, this._persist) : super(saved);

  final Future<void> Function(List<String>) _persist;

  bool isFavorite(String toolId) => state.contains(toolId);

  void toggle(String toolId) {
    state = isFavorite(toolId)
        ? state.where((id) => id != toolId).toList()
        : [...state, toolId];
    _persist(state);
  }
}

/// Recommendation engine (local heuristic — doc: AI Recommendation Engine).
///
/// Recommends tools from the user's most-used categories that they haven't
/// opened recently; falls back to badged (popular/new/AI) tools.
final recommendedToolsProvider = Provider<List<Tool>>((ref) {
  final recents = ref.watch(recentToolsProvider);
  final favorites = ref.watch(favoriteToolsProvider);
  final known = {...recents, ...favorites};

  // No history yet → no personalized picks (Trending covers discovery).
  if (known.isEmpty) return const [];

  // Rank categories by how often they appear in recents + favorites.
  final categoryScore = <String, int>{};
  for (final id in known) {
    final tool = ToolsData.toolById(id);
    if (tool != null) {
      categoryScore[tool.categoryId] =
          (categoryScore[tool.categoryId] ?? 0) + 1;
    }
  }

  final picks = <Tool>[];
  if (categoryScore.isNotEmpty) {
    final ranked = categoryScore.keys.toList()
      ..sort((a, b) => categoryScore[b]!.compareTo(categoryScore[a]!));
    for (final categoryId in ranked) {
      picks.addAll(ToolsData.tools.where(
          (t) => t.categoryId == categoryId && !known.contains(t.id)));
      if (picks.length >= 6) break;
    }
  }

  // Fallback / top-up with badged tools.
  if (picks.length < 6) {
    picks.addAll(ToolsData.tools.where((t) =>
        t.badge != null && !known.contains(t.id) && !picks.contains(t)));
  }
  return picks.take(6).toList();
});

/// Trending tools (doc: Trending Tools — most popular, new releases, AI).
final trendingToolsProvider = Provider<List<Tool>>((ref) {
  return ToolsData.tools.where((t) => t.badge != null).take(8).toList();
});
