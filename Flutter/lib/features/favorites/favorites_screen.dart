import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/tools_data.dart';
import '../../models/tool_model.dart';
import '../../providers/tool_activity_provider.dart';
import '../../providers/tool_repository_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/retry_view.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/tool_card.dart';

/// Favorites tab — premium galaxy backdrop, glass header, staggered grid of
/// pinned tools, animated empty state. Backed by the Favorites API
/// ([remoteFavoritesProvider]) with a local/offline fallback.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static int _columnsFor(double width) {
    if (width >= 1000) return 6;
    if (width >= 600) return 4;
    return 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live catalog (falls back to the bundled catalog when offline) used to
    // resolve favorite slugs into full [Tool] cards.
    final catalog = ref.watch(remoteToolsProvider(null)).valueOrNull ??
        ToolsData.tools;
    Tool? resolve(String slug) {
      for (final t in catalog) {
        if (t.remoteSlug == slug || t.id == slug) return t;
      }
      return ToolsData.toolById(slug);
    }

    // Prefer backend favorites; fall back to locally-pinned favorites so the
    // screen still works signed-out / offline.
    final favoritesAsync = ref.watch(remoteFavoritesProvider);
    final remoteFavorites = favoritesAsync.valueOrNull;
    final localFavorites = ref.watch(favoriteToolsProvider);
    final slugs = (remoteFavorites != null && remoteFavorites.isNotEmpty)
        ? remoteFavorites.map((f) => f.toolSlug).toList()
        : localFavorites;

    final tools = [
      for (final slug in slugs)
        if (resolve(slug) != null) resolve(slug)!,
    ];
    final columns = _columnsFor(MediaQuery.sizeOf(context).width);
    final offline = ref.watch(offlineStatusProvider);

    Future<void> onRefresh() async {
      ref.invalidate(remoteFavoritesProvider);
      refreshCatalog(ref);
    }

    // Loading only when we have nothing to show yet.
    final loading = favoritesAsync.isLoading && tools.isEmpty;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.md, 12, Insets.md, Insets.xs),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: 'Favorites',
                    subtitle: '${tools.length} pinned tool'
                        '${tools.length == 1 ? '' : 's'}',
                    emoji: '💜',
                  ),
                ),
              ),
              if (offline) OfflineBanner(onRetry: onRefresh),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: loading
                      ? SectionSkeleton(
                          itemCount: columns * 2,
                          crossAxisCount: columns,
                        )
                      : tools.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              children: [
                                SizedBox(
                                  height: MediaQuery.sizeOf(context).height * 0.6,
                                  child: PremiumEmptyState(
                                    icon: Icons.favorite_rounded,
                                    emoji: '💜',
                                    title: 'No favorites yet',
                                    message:
                                        'Pin your most-used tools and they will appear here.',
                                    actionLabel: 'Explore Tools',
                                    onAction: () => context.go('/tools'),
                                  ),
                                ),
                              ],
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  Insets.md, 12, Insets.md, 120),
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.35,
                              ),
                              itemCount: tools.length,
                              itemBuilder: (context, i) => FadeSlideIn(
                                index: i.clamp(0, 12),
                                child: ToolCard(tool: tools[i]),
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
