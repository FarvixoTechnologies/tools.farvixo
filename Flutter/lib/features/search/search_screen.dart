import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/tool_repository_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/retry_view.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/tool_card.dart';

/// Search — premium galaxy backdrop, glass search field, animated empty /
/// no-result states and a staggered results grid. Results come from the
/// backend search endpoint (debounced), with an offline catalog fallback
/// handled inside the repository.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  /// Committed (debounced) query that actually drives the search provider.
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    // Rebuild immediately so the clear button reflects the field, but defer the
    // actual (backend) search until typing settles.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = query.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ---------- glass search bar ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: FadeSlideIn(
                  child: Row(
                    children: [
                      CircleGlassButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/home'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: p.surface.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: p.accent.withValues(alpha: .5)),
                            boxShadow: [
                              BoxShadow(
                                  color: p.accent.withValues(alpha: .12),
                                  blurRadius: 16),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  size: 20, color: p.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focus,
                                  onChanged: _onChanged,
                                  style: TextStyle(color: p.textPrimary),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    hintText: 'Search any tool...',
                                    hintStyle: TextStyle(color: p.textMuted),
                                    border: InputBorder.none,
                                    filled: false,
                                  ),
                                ),
                              ),
                              if (hasQuery)
                                PressableScale(
                                  onTap: () {
                                    _controller.clear();
                                    _debounce?.cancel();
                                    setState(() => _query = '');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(Insets.xs),
                                    decoration: BoxDecoration(
                                      color: p.surface2,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.close_rounded,
                                        size: 16, color: p.textMuted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ---------- body ----------
              Expanded(child: _buildBody(hasQuery)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool hasQuery) {
    if (!hasQuery || _query.isEmpty) {
      return const PremiumEmptyState(
        icon: Icons.search_rounded,
        title: 'Search across all tools',
        message:
            'Find any of Farvixo\'s 120+ tools by name, category or what it does.',
      );
    }

    final resultsAsync = ref.watch(remoteToolSearchProvider(_query));
    return resultsAsync.when(
      loading: () => const SectionSkeleton(itemCount: 6),
      error: (_, _) => ErrorRetryView(
        title: 'Search unavailable',
        message: 'Please check your connection and try again.',
        onRetry: () => ref.invalidate(remoteToolSearchProvider(_query)),
      ),
      data: (results) {
        if (results.isEmpty) {
          return PremiumEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No tools found',
            message: 'Nothing matched "$_query". '
                'Try a different keyword.',
          );
        }
        final p = AppPalette.of(context);
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(remoteToolSearchProvider(_query)),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
                    child: Row(
                      children: [
                        Text(
                          '${results.length} '
                          'result${results.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        Gaps.w8,
                        Expanded(
                          child: Text(
                            'for "$_query"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: p.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.md, 0, Insets.md, 120),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => FadeSlideIn(
                        index: i.clamp(0, 12),
                        child: ToolCard(tool: results[i])),
                    childCount: results.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
