import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tools_data.dart';
import '../models/tool_model.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

/// Recently used tools — local cache + optional Supabase `user_tool_stats` / RPC.
final recentToolsProvider =
    StateNotifierProvider<RecentToolsNotifier, List<String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RecentToolsNotifier(
    storage.recentToolIds,
    storage.setRecentToolIds,
    () => ref.read(authProvider),
  );
});

class RecentToolsNotifier extends StateNotifier<List<String>> {
  RecentToolsNotifier(super.saved, this._persist, this._user);

  static const _maxItems = 10;

  final Future<void> Function(List<String>) _persist;
  final AppUser? Function() _user;

  bool get _canSync {
    final u = _user();
    return SupabaseService.client != null && u != null && !u.isGuest;
  }

  void recordUse(String toolId) {
    final ids = [toolId, ...state.where((id) => id != toolId)];
    state = ids.take(_maxItems).toList();
    _persist(state);
    if (_canSync) {
      // ignore: discarded_futures
      _recordRemote(toolId);
    }
  }

  Future<void> _recordRemote(String toolId) async {
    try {
      await SupabaseService.client!
          .rpc('record_tool_use', params: {'p_tool_id': toolId});
    } catch (e) {
      debugPrint('RecentTools.recordRemote failed: $e');
    }
  }

  Future<void> hydrateFromRemote() async {
    if (!_canSync) return;
    try {
      final rows = await SupabaseService.client!
          .from('user_tool_stats')
          .select('tool_id')
          .eq('user_id', _user()!.id)
          .order('last_used_at', ascending: false)
          .limit(_maxItems);
      final remote = (rows as List)
          .map((r) => (r as Map)['tool_id'] as String?)
          .whereType<String>()
          .toList();
      if (remote.isEmpty) return;
      // Prefer remote order when signed in (source of truth), keep unknown local.
      final merged = [
        ...remote,
        ...state.where((id) => !remote.contains(id)),
      ].take(_maxItems).toList();
      state = merged;
      await _persist(state);
    } catch (e) {
      debugPrint('RecentTools.hydrateFromRemote failed: $e');
    }
  }

  void clear() {
    state = [];
    _persist(state);
  }
}

/// Favorite tools — local + Supabase `user_favorites`.
final favoriteToolsProvider =
    StateNotifierProvider<FavoriteToolsNotifier, List<String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return FavoriteToolsNotifier(
    storage.favoriteToolIds,
    storage.setFavoriteToolIds,
    () => ref.read(authProvider),
  );
});

class FavoriteToolsNotifier extends StateNotifier<List<String>> {
  FavoriteToolsNotifier(super.saved, this._persist, this._user);

  final Future<void> Function(List<String>) _persist;
  final AppUser? Function() _user;

  bool get _canSync {
    final u = _user();
    return SupabaseService.client != null && u != null && !u.isGuest;
  }

  bool isFavorite(String toolId) => state.contains(toolId);

  void toggle(String toolId) {
    final adding = !isFavorite(toolId);
    state = adding
        ? [...state, toolId]
        : state.where((id) => id != toolId).toList();
    _persist(state);
    if (_canSync) {
      // ignore: discarded_futures
      _syncRemote(toolId, adding: adding);
    }
  }

  Future<void> _syncRemote(String toolId, {required bool adding}) async {
    final uid = _user()!.id;
    final client = SupabaseService.client!;
    try {
      if (adding) {
        await client.from('user_favorites').upsert({
          'user_id': uid,
          'tool_id': toolId,
        });
      } else {
        await client
            .from('user_favorites')
            .delete()
            .eq('user_id', uid)
            .eq('tool_id', toolId);
      }
    } catch (e) {
      debugPrint('FavoriteTools.syncRemote failed: $e');
    }
  }

  Future<void> hydrateFromRemote() async {
    if (!_canSync) return;
    final uid = _user()!.id;
    final client = SupabaseService.client!;
    try {
      final rows = await client
          .from('user_favorites')
          .select('tool_id')
          .eq('user_id', uid);
      final remote = (rows as List)
          .map((r) => (r as Map)['tool_id'] as String?)
          .whereType<String>()
          .toSet();
      final local = state.toSet();
      final merged = {...local, ...remote}.toList();
      state = merged;
      await _persist(state);

      // Push local-only favorites once so both devices converge.
      final onlyLocal = local.difference(remote);
      for (final id in onlyLocal) {
        try {
          await client.from('user_favorites').upsert({
            'user_id': uid,
            'tool_id': id,
          });
        } catch (e) {
          debugPrint('FavoriteTools.pushLocal failed ($id): $e');
        }
      }
    } catch (e) {
      debugPrint('FavoriteTools.hydrateFromRemote failed: $e');
    }
  }
}

final recommendedToolsProvider = Provider<List<Tool>>((ref) {
  final recents = ref.watch(recentToolsProvider);
  final favorites = ref.watch(favoriteToolsProvider);
  final known = {...recents, ...favorites};

  if (known.isEmpty) return const [];

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

  if (picks.length < 6) {
    picks.addAll(ToolsData.tools.where((t) =>
        t.badge != null && !known.contains(t.id) && !picks.contains(t)));
  }
  return picks.take(6).toList();
});

final trendingToolsProvider = Provider<List<Tool>>((ref) {
  return ToolsData.tools.where((t) => t.badge != null).take(8).toList();
});
