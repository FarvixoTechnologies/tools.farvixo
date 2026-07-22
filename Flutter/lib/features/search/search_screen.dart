import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/tools_data.dart';
import '../../models/tool_model.dart';
import '../../providers/search_provider.dart';
import '../../providers/tool_repository_provider.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/category_colors.dart';
import '../../theme/design_tokens.dart';
import '../../utils/tool_search.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/tool_card.dart';

/// Advanced live tool search — ranked results, filters, recent + trending.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  Timer? _analyticsDebounce;

  String _query = '';
  String? _categoryId;
  ToolSearchFilter _filter = ToolSearchFilter.all;
  bool _listView = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
      _query = initial;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_query.isEmpty) _focus.requestFocus();
      ref.read(toolsResultProvider);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _analyticsDebounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(Motion.searchDebounce, () {
      if (!mounted) return;
      final next = raw.trim();
      setState(() => _query = next);
      if (next.length >= 2) {
        _analyticsDebounce?.cancel();
        _analyticsDebounce = Timer(Motion.analyticsDebounce, () {
          unawaited(AnalyticsService.instance.search(next));
        });
      }
    });
  }

  void _commitQuery(String value, {bool saveRecent = true}) {
    final q = value.trim();
    _controller.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    _debounce?.cancel();
    setState(() => _query = q);
    if (saveRecent && q.isNotEmpty) {
      unawaited(ref.read(recentSearchesProvider.notifier).add(q));
      unawaited(AnalyticsService.instance.search(q));
    }
    HapticFeedback.selectionClick();
  }

  LiveSearchQuery get _liveQuery => LiveSearchQuery(
        text: _query,
        categoryId: _categoryId,
        filter: _filter,
      );

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(remoteCategoriesProvider).valueOrNull ?? ToolsData.categories;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              _SearchHeader(
                controller: _controller,
                focusNode: _focus,
                hasQuery: _controller.text.trim().isNotEmpty,
                listView: _listView,
                onChanged: _onChanged,
                onSubmitted: (v) => _commitQuery(v),
                onClear: () {
                  _controller.clear();
                  _debounce?.cancel();
                  setState(() => _query = '');
                  _focus.requestFocus();
                },
                onToggleView: () => setState(() => _listView = !_listView),
              ),
              _FilterBar(
                filter: _filter,
                onFilter: (f) => setState(() => _filter = f),
                categoryId: _categoryId,
                categories: categories,
                onCategory: (id) => setState(() => _categoryId = id),
              ),
              Expanded(
                child: _query.isEmpty
                    ? _IdleBody(
                        recent: ref.watch(recentSearchesProvider),
                        onChip: (q) => _commitQuery(q),
                        onClearRecent: () => unawaited(
                          ref.read(recentSearchesProvider.notifier).clear(),
                        ),
                        onRemoveRecent: (q) => unawaited(
                          ref.read(recentSearchesProvider.notifier).remove(q),
                        ),
                      )
                    : _ResultsBody(
                        query: _liveQuery,
                        listView: _listView,
                        rawQuery: _query,
                        onRetryClearFilters: () => setState(() {
                          _categoryId = null;
                          _filter = ToolSearchFilter.all;
                        }),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.hasQuery,
    required this.listView,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onToggleView,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasQuery;
  final bool listView;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          CircleGlassButton(
            icon: Icons.arrow_back_rounded,
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: Space.s16),
              decoration: BoxDecoration(
                color: (p.isDark ? AppColors.inputDark : p.surface)
                    .withValues(alpha: 0.92),
                borderRadius: Radii.brPanel,
                border: Border.all(color: p.accent.withValues(alpha: 0.45)),
                boxShadow: Elevations.accentGlow(p.accent),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 22, color: p.accent),
                  const SizedBox(width: Space.s10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: AppTypography.titleMedium(
                        context,
                        color: p.textPrimary,
                        weight: FontWeights.semibold,
                      ),
                      cursorColor: p.accent,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        hintText: 'Search any tool… PDF, AI, compress…',
                        hintStyle: AppTypography.titleMedium(
                          context,
                          color: p.textMuted,
                          weight: FontWeights.medium,
                        ),
                        border: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  if (hasQuery)
                    PressableScale(
                      onTap: onClear,
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
          const SizedBox(width: 4),
          IconButton(
            tooltip: listView ? 'Grid view' : 'List view',
            onPressed: onToggleView,
            icon: Icon(
              listView ? Icons.grid_view_rounded : Icons.view_list_rounded,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filters ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.onFilter,
    required this.categoryId,
    required this.categories,
    required this.onCategory,
  });

  final ToolSearchFilter filter;
  final ValueChanged<ToolSearchFilter> onFilter;
  final String? categoryId;
  final List<ToolCategory> categories;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.s16),
            children: [
              _Chip(
                label: 'All',
                selected: filter == ToolSearchFilter.all && categoryId == null,
                onTap: () {
                  onFilter(ToolSearchFilter.all);
                  onCategory(null);
                },
              ),
              _Chip(
                label: 'AI',
                selected: filter == ToolSearchFilter.ai,
                accent: CategoryColors.ai.accentOf(context),
                onTap: () => onFilter(
                  filter == ToolSearchFilter.ai
                      ? ToolSearchFilter.all
                      : ToolSearchFilter.ai,
                ),
              ),
              _Chip(
                label: 'Popular',
                selected: filter == ToolSearchFilter.popular,
                accent: CategoryColors.premium.accentOf(context),
                onTap: () => onFilter(
                  filter == ToolSearchFilter.popular
                      ? ToolSearchFilter.all
                      : ToolSearchFilter.popular,
                ),
              ),
              _Chip(
                label: 'New',
                selected: filter == ToolSearchFilter.newTools,
                // Status colour, matching the NEW badge on ToolCard.
                accent: AppColors.success,
                onTap: () => onFilter(
                  filter == ToolSearchFilter.newTools
                      ? ToolSearchFilter.all
                      : ToolSearchFilter.newTools,
                ),
              ),
              ...categories.map(
                (c) => _Chip(
                  label: c.shortName ?? c.name.replaceAll(' Tools', ''),
                  selected: categoryId == c.id,
                  accent: c.identity.accentOf(context),
                  onTap: () => onCategory(categoryId == c.id ? null : c.id),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.s20,
            Space.s4,
            Space.s20,
            Space.s0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Live ranked search · name, keywords & category',
              style: AppTypography.labelSmall(
                context,
                color: p.textMuted,
                weight: FontWeights.regular,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = accent ?? p.accent;
    return Padding(
      padding: const EdgeInsets.only(right: Gap.list),
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.curveOf(context, Motion.standard),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s16,
            vertical: Space.s8,
          ),
          decoration: BoxDecoration(
            borderRadius: Radii.brChip,
            gradient: selected
                ? LinearGradient(
                    colors: [
                      color,
                      Color.lerp(color, AppColors.brandMagenta, 0.45)!,
                    ],
                  )
                : null,
            color:
                selected ? null : (p.isDark ? AppColors.inputDark : p.surface2),
            border: Border.all(
              color: selected ? Colors.transparent : p.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.bodySmall(
              context,
              color: selected ? AppColors.onAccent : p.textSecondary,
              weight: FontWeights.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Idle (recent + trending) ───────────────────────────────────────────────

class _IdleBody extends StatelessWidget {
  const _IdleBody({
    required this.recent,
    required this.onChip,
    required this.onClearRecent,
    required this.onRemoveRecent,
  });

  final List<String> recent;
  final ValueChanged<String> onChip;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onRemoveRecent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final chipFill = p.isDark ? AppColors.inputDark : p.surface2;
    final chipLabel = AppTypography.bodyMedium(
      context,
      color: p.textPrimary,
      weight: FontWeights.semibold,
    );
    final sectionTitle = AppTypography.titleSmall(
      context,
      color: p.textPrimary,
      weight: FontWeights.extrabold,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.s20,
        Space.s16,
        Space.s20,
        Space.s40,
      ),
      physics: const BouncingScrollPhysics(),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Text('Recent', style: sectionTitle),
              const Spacer(),
              TextButton(
                onPressed: onClearRecent,
                child: Text(
                  'Clear',
                  style: AppTypography.bodyMedium(context, color: p.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.list),
          Wrap(
            spacing: Gap.list,
            runSpacing: Gap.list,
            children: [
              for (final q in recent.take(8))
                InputChip(
                  label: Text(q),
                  onPressed: () => onChip(q),
                  onDeleted: () => onRemoveRecent(q),
                  deleteIconColor: p.textMuted,
                  backgroundColor: chipFill,
                  side: BorderSide(color: p.border),
                  labelStyle: chipLabel,
                ),
            ],
          ),
          const SizedBox(height: Gap.dialog),
        ],
        Text('Trending', style: sectionTitle),
        const SizedBox(height: Space.s10),
        Wrap(
          spacing: Gap.list,
          runSpacing: Gap.list,
          children: [
            for (final q in ToolSearch.trendingQueries)
              ActionChip(
                avatar: Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: CategoryColors.audio.accentOf(context),
                ),
                label: Text(q),
                onPressed: () => onChip(q),
                backgroundColor: chipFill,
                side: BorderSide(color: p.border),
                labelStyle: chipLabel,
              ),
          ],
        ),
        const SizedBox(height: Space.s28),
        const PremiumEmptyState(
          icon: Icons.auto_awesome_rounded,
          title: 'Search across all tools',
          message:
              'Type to search live — ranked by name, keywords, category & typos.',
        ),
      ],
    );
  }
}

// ─── Results ────────────────────────────────────────────────────────────────

class _ResultsBody extends ConsumerWidget {
  const _ResultsBody({
    required this.query,
    required this.listView,
    required this.rawQuery,
    required this.onRetryClearFilters,
  });

  final LiveSearchQuery query;
  final bool listView;
  final String rawQuery;
  final VoidCallback onRetryClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final instant = ref.watch(liveToolSearchProvider(query));
    final enriched = ref.watch(enrichedToolSearchProvider(query));
    final results = enriched.maybeWhen(
      data: (remote) => remote.isNotEmpty ? remote : instant,
      orElse: () => instant,
    );

    if (results.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No tools found',
        message: 'Nothing matched "$rawQuery". Try another keyword '
            'or clear filters.',
        actionLabel: 'Clear filters',
        onAction: onRetryClearFilters,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        refreshCatalog(ref);
        ref.invalidate(enrichedToolSearchProvider(query));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s20,
                Space.s10,
                Space.s20,
                Space.s8,
              ),
              child: Row(
                children: [
                  Text(
                    '${results.length} result${results.length == 1 ? '' : 's'}',
                    style: AppTypography.numeric(
                      context,
                      color: p.textPrimary,
                      weight: FontWeights.extrabold,
                    ),
                  ),
                  const SizedBox(width: Gap.inline),
                  Expanded(
                    child: Text(
                      'for "$rawQuery"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall(
                        context,
                        color: p.textMuted,
                      ),
                    ),
                  ),
                  if (enriched.isLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (listView)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final tool = results[i];
                  return FadeSlideIn(
                    index: i.clamp(0, 12),
                    child: _SearchListTile(tool: tool, query: rawQuery),
                  );
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => FadeSlideIn(
                    index: i.clamp(0, 12),
                    child: ToolCard(tool: results[i]),
                  ),
                  childCount: results.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchListTile extends ConsumerWidget {
  const _SearchListTile({required this.tool, required this.query});

  final Tool tool;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    // Identity comes from the tool's own category, so a result row reads the
    // same colour as its card in the tools grid.
    final id = tool.identity;
    final accent = id.accentOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          unawaited(
            ref.read(recentSearchesProvider.notifier).add(query),
          );
          context.push('/tool/${tool.id}');
        },
        borderRadius: Radii.brCard,
        child: Ink(
          padding: const EdgeInsets.all(Space.s16),
          decoration: BoxDecoration(
            color: (p.isDark ? AppColors.zincSurface : p.surface)
                .withValues(alpha: p.isDark ? 0.9 : 0.95),
            borderRadius: Radii.brCard,
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: id.surfaceGradient(context),
                  borderRadius: Radii.brButton,
                  border: Border.all(color: id.border(context)),
                ),
                child: Icon(tool.icon, color: accent, size: 22),
              ),
              const SizedBox(width: Gap.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall(
                        context,
                        color: p.textPrimary,
                        weight: FontWeights.extrabold,
                      ),
                    ),
                    const SizedBox(height: Space.s2),
                    Text(
                      tool.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium(
                        context,
                        color: p.textSecondary,
                        weight: FontWeights.regular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.inline),
              Icon(Icons.chevron_right_rounded, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
