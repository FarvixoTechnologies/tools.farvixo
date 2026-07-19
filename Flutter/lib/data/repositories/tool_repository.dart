import 'package:flutter/material.dart';

import '../../models/favorite_tool.dart';
import '../../models/tool_model.dart';
import '../../services/farvixo_api_client.dart';
import '../tools_data.dart';

/// Outcome of a repository read that always resolves to usable data.
///
/// [source] tells the UI whether the data came from the live backend, an
/// in-memory cache, or the bundled local catalog fallback. [error] is set when
/// the network call failed even though [items] still holds a usable fallback.
class RepoResult<T> {
  const RepoResult({
    required this.items,
    required this.source,
    this.error,
  });

  final List<T> items;
  final RepoSource source;
  final String? error;

  bool get isFromNetwork => source == RepoSource.network;
}

enum RepoSource { network, cache, local }

/// Single source of truth for tool catalog + favorites data.
///
/// Reuses [FarvixoApiClient] for networking and the bundled [ToolsData] as an
/// offline/error fallback. Categories, tools and search hit the public
/// `/api/v1/tools*` endpoints; favorites require a signed-in session.
class ToolRepository {
  ToolRepository(this._api);

  final FarvixoApiClient _api;

  static const Duration _ttl = Duration(minutes: 10);

  // ---- in-memory cache ----
  List<ToolCategory>? _categoriesCache;
  DateTime? _categoriesAt;

  List<Tool>? _toolsCache;
  DateTime? _toolsAt;

  bool _fresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < _ttl;

  /// Resolve an icon for an API tool from the bundled catalog (falls back to a
  /// category icon, then a generic icon) so cards always render something sane.
  IconData _iconFor(String slug, String categoryId) {
    final local = ToolsData.toolById(slug);
    if (local != null) return local.icon;
    final category = ToolsData.categoryById(categoryId);
    return category?.icon ?? Icons.build_rounded;
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  Future<RepoResult<ToolCategory>> getCategories({bool refresh = false}) async {
    if (!refresh && _fresh(_categoriesAt) && _categoriesCache != null) {
      return RepoResult(items: _categoriesCache!, source: RepoSource.cache);
    }

    final res = await _api.getPublic('/v1/tools/categories');
    if (res.ok && res.data != null) {
      final raw = res.data!['categories'];
      if (raw is List) {
        final parsed = raw
            .whereType<Map>()
            .map((m) => ToolCategory.fromApi(Map<String, dynamic>.from(m)))
            .where((c) => c.id.isNotEmpty)
            .toList();
        if (parsed.isNotEmpty) {
          _categoriesCache = parsed;
          _categoriesAt = DateTime.now();
          return RepoResult(items: parsed, source: RepoSource.network);
        }
      }
    }

    // Fallback: last good cache, else bundled catalog.
    if (_categoriesCache != null) {
      return RepoResult(
        items: _categoriesCache!,
        source: RepoSource.cache,
        error: res.message,
      );
    }
    return RepoResult(
      items: ToolsData.categories,
      source: RepoSource.local,
      error: res.message,
    );
  }

  // ---------------------------------------------------------------------------
  // Tools
  // ---------------------------------------------------------------------------

  Future<RepoResult<Tool>> getTools({
    String? category,
    bool refresh = false,
  }) async {
    // Serve the full list from cache and filter locally when possible.
    if (!refresh && _fresh(_toolsAt) && _toolsCache != null) {
      return RepoResult(
        items: _filterByCategory(_toolsCache!, category),
        source: RepoSource.cache,
      );
    }

    final res = await _api.getPublic('/v1/tools');
    if (res.ok && res.data != null) {
      final parsed = _parseTools(res.data!['tools']);
      if (parsed.isNotEmpty) {
        _toolsCache = parsed;
        _toolsAt = DateTime.now();
        return RepoResult(
          items: _filterByCategory(parsed, category),
          source: RepoSource.network,
        );
      }
    }

    if (_toolsCache != null) {
      return RepoResult(
        items: _filterByCategory(_toolsCache!, category),
        source: RepoSource.cache,
        error: res.message,
      );
    }
    final local = category == null || category.isEmpty
        ? ToolsData.tools
        : ToolsData.byCategory(category);
    return RepoResult(
      items: local,
      source: RepoSource.local,
      error: res.message,
    );
  }

  /// Server-side search with a local fallback.
  Future<RepoResult<Tool>> searchTools(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const RepoResult(items: [], source: RepoSource.local);

    final res = await _api.getPublic('/v1/tools/search', query: {'q': q});
    if (res.ok && res.data != null) {
      final parsed = _parseTools(res.data!['tools']);
      return RepoResult(items: parsed, source: RepoSource.network);
    }
    return RepoResult(
      items: ToolsData.search(q),
      source: RepoSource.local,
      error: res.message,
    );
  }

  /// Fetch a single tool by slug (falls back to the bundled catalog).
  Future<Tool?> getTool(String slug) async {
    final res = await _api.getPublic('/v1/tools/$slug');
    if (res.ok && res.data != null) {
      final raw = res.data!['tool'];
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final categoryId = (map['category'] ?? '').toString();
        return Tool.fromApi(
          map,
          fallbackIcon: _iconFor(slug, categoryId),
        );
      }
    }
    return ToolsData.toolById(slug);
  }

  List<Tool> _parseTools(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) {
          final map = Map<String, dynamic>.from(m);
          final slug = (map['slug'] ?? map['id'] ?? '').toString();
          final categoryId = (map['category'] ?? '').toString();
          return Tool.fromApi(map, fallbackIcon: _iconFor(slug, categoryId));
        })
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  List<Tool> _filterByCategory(List<Tool> tools, String? category) {
    if (category == null || category.isEmpty) return tools;
    return tools.where((t) => t.categoryId == category).toList();
  }

  // ---------------------------------------------------------------------------
  // Favorites API (session required)
  // ---------------------------------------------------------------------------

  /// List the signed-in user's favorites. Returns an empty list when the user
  /// is not signed in or the backend favorites table is not yet provisioned.
  Future<List<FavoriteTool>> getFavorites() async {
    if (!_api.hasSession) return const [];
    final res = await _api.get('/v1/tools/favorite');
    if (!res.ok || res.data == null) return const [];
    if (res.data!['ready'] == false) return const [];
    final raw = res.data!['favorites'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => FavoriteTool.fromApi(Map<String, dynamic>.from(m)))
        .where((f) => f.toolSlug.isNotEmpty)
        .toList();
  }

  /// Add or remove a favorite. Returns true when the backend accepted the call.
  Future<bool> setFavorite(String toolSlug, {required bool favorite}) async {
    if (!_api.hasSession) return false;
    final res = await _api.post(
      '/v1/tools/favorite',
      data: {'toolSlug': toolSlug, 'favorite': favorite},
    );
    if (!res.ok) {
      debugPrint('ToolRepository.setFavorite failed: ${res.message}');
    }
    return res.ok;
  }
}
