import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/tools_data.dart';
import '../../providers/tool_activity_provider.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/tool_card.dart';

/// Favorites tab — premium galaxy backdrop, glass header, staggered grid of
/// pinned tools, animated empty state.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static int _columnsFor(double width) {
    if (width >= 1000) return 6;
    if (width >= 600) return 4;
    return 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteToolsProvider);
    final tools = [
      for (final id in favorites)
        if (ToolsData.toolById(id) != null) ToolsData.toolById(id)!,
    ];
    final columns = _columnsFor(MediaQuery.sizeOf(context).width);

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: 'Favorites',
                    subtitle: '${tools.length} pinned tool'
                        '${tools.length == 1 ? '' : 's'}',
                    emoji: '💜',
                  ),
                ),
              ),
              Expanded(
                child: tools.isEmpty
                    ? PremiumEmptyState(
                        icon: Icons.favorite_rounded,
                        emoji: '💜',
                        title: 'No favorites yet',
                        message:
                            'Pin your most-used tools and they will appear here.',
                        actionLabel: 'Explore Tools',
                        onAction: () => context.go('/tools'),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.35,
                        ),
                        itemCount: tools.length,
                        itemBuilder: (context, i) => FadeSlideIn(
                          index: i,
                          child: ToolCard(tool: tools[i]),
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
