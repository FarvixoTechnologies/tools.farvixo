import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/tool_repository.dart';
import '../data/tools_data.dart';
import '../models/favorite_tool.dart';
import '../models/tool_model.dart';
import '../theme/app_colors.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

/// Repository singleton — reuses the shared [farvixoApiClientProvider].
/// Kept alive for the whole session so its in-memory TTL cache survives
/// navigation between tabs.
final toolRepositoryProvider = Provider<ToolRepository>((ref) {
  return ToolRepository(ref.watch(farvixoApiClientProvider));
});

// =============================================================================
// Result providers (source of truth) — expose RepoResult so the UI can tell
// live/cache/local apart and show an "Offline mode" indicator. These are NOT
// autoDispose so the catalog stays warm across tab switches (no refetch storm).
// =============================================================================

/// Categories with source metadata. Invalidate to force a network refresh.
final categoriesResultProvider =
    FutureProvider<RepoResult<ToolCategory>>((ref) async {
  return ref.watch(toolRepositoryProvider).getCategories(refresh: true);
});

/// Full tool catalog with source metadata, fetched once per session (kept
/// alive). Category filtering is done client-side in [remoteToolsProvider] so
/// switching categories never triggers another network request.
final toolsResultProvider =
    FutureProvider<RepoResult<Tool>>((ref) async {
  return ref.watch(toolRepositoryProvider).getTools(refresh: true);
});

// =============================================================================
// Derived list providers — same shape the UI already consumes
// (AsyncValue<List<...>>), so no call sites change. Reading these does not
// trigger extra fetches; they project the result providers above.
// =============================================================================

/// Live tool categories (backend, cached, local fallback).
final remoteCategoriesProvider =
    Provider<AsyncValue<List<ToolCategory>>>((ref) {
  return ref.watch(categoriesResultProvider).whenData((r) => r.items);
});

/// Live tool catalog, optionally filtered by category slug (client-side over
/// the cached full catalog — no network on category switch).
final remoteToolsProvider =
    Provider.family<AsyncValue<List<Tool>>, String?>((ref, category) {
  return ref.watch(toolsResultProvider).whenData((r) {
    if (category == null || category.isEmpty) return r.items;
    return r.items.where((t) => t.categoryId == category).toList();
  });
});

/// True when the catalog is currently served from the bundled fallback because
/// the backend was unreachable — drives the "Offline mode" banner.
final offlineStatusProvider = Provider<bool>((ref) {
  final tools = ref.watch(toolsResultProvider).valueOrNull;
  final categories = ref.watch(categoriesResultProvider).valueOrNull;
  return tools?.source == RepoSource.local ||
      categories?.source == RepoSource.local;
});

/// Server-side tool search (empty query → empty list). autoDispose so each
/// query's result is released once no longer watched — this cancels stale
/// searches and prevents an unbounded per-query cache.
final remoteToolSearchProvider =
    FutureProvider.autoDispose.family<List<Tool>, String>((ref, query) async {
  final result = await ref.watch(toolRepositoryProvider).searchTools(query);
  return result.items;
});

/// A single tool by slug (backend, local fallback). Used by the detail screen.
/// autoDispose — a tool page's fetch is released when the page is popped.
final remoteToolProvider =
    FutureProvider.autoDispose.family<Tool?, String>((ref, slug) async {
  return ref.watch(toolRepositoryProvider).getTool(slug);
});

/// The signed-in user's favorites from the backend. Recomputes on auth change.
final remoteFavoritesProvider =
    FutureProvider<List<FavoriteTool>>((ref) async {
  // Rebuild when the user signs in/out.
  ref.watch(authProvider);
  return ref.watch(toolRepositoryProvider).getFavorites();
});

/// Safe category resolver: prefers live API categories, falls back to the
/// bundled catalog, then to a generic category so unknown backend slugs never
/// crash a [ToolCard]. Never throws.
final categoryResolverProvider =
    Provider<ToolCategory Function(String)>((ref) {
  final apiCats = ref.watch(remoteCategoriesProvider).valueOrNull;
  return (String categoryId) {
    if (apiCats != null) {
      for (final c in apiCats) {
        if (c.id == categoryId) return c;
      }
    }
    final local = ToolsData.categoryById(categoryId);
    if (local != null) return local;
    return ToolCategory(
      id: categoryId,
      name: categoryId.isEmpty ? 'Tools' : categoryId,
      icon: Icons.apps_rounded,
      color: AppColors.accentDev,
    );
  };
});

/// Central refresh helper — invalidates ONLY the catalog providers (never a
/// global reset). Category filtering is client-side, so one invalidation
/// refreshes every category view. Screens call this from pull-to-refresh / retry.
void refreshCatalog(WidgetRef ref) {
  ref.invalidate(categoriesResultProvider);
  ref.invalidate(toolsResultProvider);
}
