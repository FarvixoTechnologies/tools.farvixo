import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/tools_data.dart';
import '../../models/tool_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tool_activity_provider.dart';
import '../../providers/tool_repository_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/farvixo_logo.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/retry_view.dart';
import '../../widgets/tool_card.dart';

/// Resolve a tool id/slug against the live catalog, falling back to the bundled
/// catalog so recents keep resolving offline.
Tool? _resolveTool(List<Tool> catalog, String id) {
  for (final t in catalog) {
    if (t.id == id || t.remoteSlug == id) return t;
  }
  return ToolsData.toolById(id);
}

enum _SortMode { popular, newest, trending, recentlyUsed, aToZ }

enum _FilterMode { all, free, premium, ai, favorites }

/// Tools Page — FARVIXO TOOLS_PAGE.md 2026 Enterprise Edition.
/// Hierarchy: App bar → Title/Filters → Stats → Category chips →
/// Popular grid → Premium banner. Bottom nav lives in [MainShell].
class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  String? _selectedCategoryId;
  _SortMode _sort = _SortMode.popular;
  _FilterMode _filter = _FilterMode.all;
  bool _showAllCategories = false;

  static const _primaryChipIds = ['pdf', 'image', 'video', 'audio', 'ai'];

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  void didUpdateWidget(covariant ToolsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategoryId != oldWidget.initialCategoryId) {
      _selectedCategoryId = widget.initialCategoryId;
    }
  }

  /// Applies filter + sort to an already category-scoped list (the category
  /// filter itself is done via the backend query — [remoteToolsProvider]).
  List<Tool> _visibleTools(List<Tool> scoped) {
    var list = List<Tool>.from(scoped);

    final favorites = ref.read(favoriteToolsProvider);
    final recents = ref.read(recentToolsProvider);

    switch (_filter) {
      case _FilterMode.all:
        break;
      case _FilterMode.free:
        list = list.where((t) => t.badge != ToolBadge.ai).toList();
      case _FilterMode.premium:
      case _FilterMode.ai:
        list = list.where((t) => t.badge == ToolBadge.ai).toList();
      case _FilterMode.favorites:
        list = list.where((t) => favorites.contains(t.id)).toList();
    }

    switch (_sort) {
      case _SortMode.popular:
        list.sort((a, b) {
          final ap = a.badge == ToolBadge.popular ? 0 : 1;
          final bp = b.badge == ToolBadge.popular ? 0 : 1;
          if (ap != bp) return ap.compareTo(bp);
          return a.name.compareTo(b.name);
        });
      case _SortMode.newest:
        list.sort((a, b) {
          final an = a.badge == ToolBadge.isNew ? 0 : 1;
          final bn = b.badge == ToolBadge.isNew ? 0 : 1;
          if (an != bn) return an.compareTo(bn);
          return a.name.compareTo(b.name);
        });
      case _SortMode.trending:
        list.sort((a, b) {
          final at = a.badge != null ? 0 : 1;
          final bt = b.badge != null ? 0 : 1;
          if (at != bt) return at.compareTo(bt);
          return a.name.compareTo(b.name);
        });
      case _SortMode.recentlyUsed:
        list.sort((a, b) {
          final ai = recents.indexOf(a.id);
          final bi = recents.indexOf(b.id);
          final ar = ai < 0 ? 999 : ai;
          final br = bi < 0 ? 999 : bi;
          if (ar != br) return ar.compareTo(br);
          return a.name.compareTo(b.name);
        });
      case _SortMode.aToZ:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  Future<void> _openFilters() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var sort = _sort;
        var filter = _filter;
        final p = AppPalette.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.of(ctx).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: Radii.brSheet,
                border: Border.all(color: p.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: Radii.brPill,
                      ),
                    ),
                  ),
                  Text(
                    'Sort & Filter',
                    style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sort by',
                    style: AppTypography.bodyMedium(context, color: p.textSecondary, weight: FontWeights.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in _SortMode.values)
                        _SheetChip(
                          label: switch (e) {
                            _SortMode.popular => 'Popular',
                            _SortMode.newest => 'Newest',
                            _SortMode.trending => 'Trending',
                            _SortMode.recentlyUsed => 'Recently Used',
                            _SortMode.aToZ => 'A–Z',
                          },
                          selected: sort == e,
                          onTap: () => setSheet(() => sort = e),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Filter',
                    style: AppTypography.bodyMedium(context, color: p.textSecondary, weight: FontWeights.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in _FilterMode.values)
                        _SheetChip(
                          label: switch (e) {
                            _FilterMode.all => 'All',
                            _FilterMode.free => 'Free',
                            _FilterMode.premium => 'Premium',
                            _FilterMode.ai => 'AI',
                            _FilterMode.favorites => 'Favorites',
                          },
                          selected: filter == e,
                          onTap: () => setSheet(() => filter = e),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _sort = sort;
                          _filter = filter;
                        });
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                          borderRadius: Radii.brButton,
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: AppTypography.labelLarge(context, weight: FontWeights.extrabold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Full catalog (for stats) + category-scoped catalog (backend category
    // query) — both fall back to the bundled catalog when offline.
    final allTools =
        ref.watch(remoteToolsProvider(null)).valueOrNull ?? ToolsData.tools;
    final scopedTools =
        ref.watch(remoteToolsProvider(_selectedCategoryId)).valueOrNull ??
            (_selectedCategoryId == null
                ? ToolsData.tools
                : ToolsData.byCategory(_selectedCategoryId!));
    final categories =
        ref.watch(remoteCategoriesProvider).valueOrNull ?? ToolsData.categories;
    final offline = ref.watch(offlineStatusProvider);

    final tools = _visibleTools(scopedTools);
    final total = allTools.length;
    final popularCount =
        allTools.where((t) => t.badge == ToolBadge.popular).length;
    final aiCount = allTools.where((t) => t.badge == ToolBadge.ai).length;
    final freeCount = total - aiCount;
    final user = ref.watch(authProvider);
    final recents = ref.watch(recentToolsProvider);
    final recommended = ref.watch(recommendedToolsProvider);
    final nameSeed = (user?.fullName ?? user?.email ?? 'F').trim();
    final userInitial = nameSeed.isEmpty
        ? 'F'
        : nameSeed.characters.first.toUpperCase();

    final chipCategories = _showAllCategories
        ? categories
        : categories
            .where((c) => _primaryChipIds.contains(c.id))
            .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async => refreshCatalog(ref),
            child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  child: _ToolsAppBar(
                    userInitial: userInitial,
                    onSearch: () => context.push('/search'),
                    onNotifications: () => context.push('/notifications'),
                    onProfile: () => context.go('/profile'),
                    onMenu: () => Scaffold.maybeOf(context)?.openDrawer(),
                  ),
                ),
              ),
              if (offline)
                SliverToBoxAdapter(
                  child: OfflineBanner(
                    onRetry: () => refreshCatalog(ref),
                  ),
                ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: AppTypography.headlineLarge(context, color: p.textPrimary, weight: FontWeights.black).copyWith(height: 1.1),
                                  children: [
                                    const TextSpan(text: 'All '),
                                    TextSpan(
                                      text: 'Tools',
                                      style: AppTypography.bodyMedium(context, color: p.accent),
                                    ),
                                    const TextSpan(text: ' ✨'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$total powerful tools to boost your productivity',
                                style: AppTypography.bodyMedium(context, color: p.textSecondary).copyWith(height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FiltersButton(onTap: _openFilters),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _StatsRow(
                      total: total,
                      popular: popularCount,
                      free: freeCount,
                      premium: aiCount,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _CategoryChip(
                            label: 'All',
                            icon: Icons.apps_rounded,
                            color: p.accent,
                            selected: _selectedCategoryId == null,
                            onTap: () =>
                                setState(() => _selectedCategoryId = null),
                          ),
                          const SizedBox(width: 8),
                          for (final cat in chipCategories) ...[
                            _CategoryChip(
                              label: cat.name.replaceAll(' Tools', ''),
                              icon: cat.icon,
                              color: cat.color,
                              selected: _selectedCategoryId == cat.id,
                              onTap: () => setState(
                                () => _selectedCategoryId = cat.id,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (!_showAllCategories &&
                              categories.length > _primaryChipIds.length)
                            _CategoryChip(
                              label: 'More',
                              icon: Icons.expand_more_rounded,
                              color: p.textSecondary,
                              selected: false,
                              onTap: () =>
                                  setState(() => _showAllCategories = true),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (recents.isNotEmpty &&
                  _selectedCategoryId == null &&
                  _filter == _FilterMode.all)
                ..._section(
                  index: 4,
                  title: 'Recently Used',
                  tools: recents
                      .map((id) => _resolveTool(allTools, id))
                      .whereType<Tool>()
                      .take(6)
                      .toList(),
                ),
              if (recommended.isNotEmpty &&
                  _selectedCategoryId == null &&
                  _filter == _FilterMode.all)
                ..._section(
                  index: 5,
                  title: 'Recommended',
                  tools: recommended.take(6).toList(),
                ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 6,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          _selectedCategoryId == null
                              ? 'Popular Tools'
                              : ref
                                  .watch(categoryResolverProvider)(
                                      _selectedCategoryId!)
                                  .name,
                          style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                        ),
                        const Spacer(),
                        Text(
                          '${tools.length}',
                          style: AppTypography.bodyMedium(context, color: p.textMuted, weight: FontWeights.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (tools.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: p.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tools found',
                          style: AppTypography.titleMedium(context, color: p.textPrimary, weight: FontWeights.extrabold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try another category or clear filters.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium(context, color: p.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => setState(() {
                            _selectedCategoryId = null;
                            _filter = _FilterMode.all;
                            _sort = _SortMode.popular;
                          }),
                          child: Text('Reset filters'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.crossAxisExtent;
                      final columns = w >= 900
                          ? 5
                          : w >= 700
                              ? 4
                              : 3;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: columns >= 4 ? 0.92 : 0.78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => FadeSlideIn(
                            index: i.clamp(0, 12),
                            child: ToolCard(tool: tools[i]),
                          ),
                          childCount: tools.length,
                        ),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 8,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _PremiumUpgradeBanner(
                      onUpgrade: () => context.go('/profile'),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _section({
    required int index,
    required String title,
    required List<Tool> tools,
  }) {
    if (tools.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: FadeSlideIn(
          index: index,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text(
              title,
              style: AppTypography.titleLarge(context, color: AppPalette.of(context).textPrimary, weight: FontWeights.extrabold),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tools.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => SizedBox(
              width: 132,
              child: ToolCard(tool: tools[i]),
            ),
          ),
        ),
      ),
    ];
  }
}

class _ToolsAppBar extends StatelessWidget {
  const _ToolsAppBar({
    required this.userInitial,
    required this.onSearch,
    required this.onNotifications,
    required this.onProfile,
    required this.onMenu,
  });

  final String userInitial;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              onPressed: onMenu,
              icon: Icon(Icons.menu_rounded, color: p.textPrimary),
              tooltip: 'Menu',
            ),
            const FarvixoLogo(size: 32, glow: true),
            const SizedBox(width: 8),
            Text(
              'Farvixo',
              style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: Radii.brPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 12, color: AppColors.lightTextPrimary),
                  SizedBox(width: 3),
                  Text(
                    'Premium',
                    style: AppTypography.caption(context, color: AppColors.lightTextPrimary, weight: FontWeights.extrabold),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _IconBtn(icon: Icons.search_rounded, onTap: onSearch),
            const SizedBox(width: 4),
            Stack(
              clipBehavior: Clip.none,
              children: [
                _IconBtn(icon: Icons.notifications_none_rounded, onTap: onNotifications),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 14,
                    height: 14,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '3',
                      style: AppTypography.badge(context, color: AppColors.onAccent, weight: FontWeights.extrabold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onProfile,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: p.accent.withValues(alpha: 0.25),
                child: Text(
                  userInitial,
                  style: AppTypography.labelMedium(context, color: p.accent, weight: FontWeights.extrabold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.65),
          shape: BoxShape.circle,
          border: Border.all(color: p.border),
        ),
        child: Icon(icon, size: 20, color: p.textPrimary),
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.75),
          borderRadius: Radii.brButton,
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 16, color: p.textPrimary),
            const SizedBox(width: 6),
            Text(
              'Filters',
              style: AppTypography.bodySmall(context, color: p.textPrimary, weight: FontWeights.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.popular,
    required this.free,
    required this.premium,
  });

  final int total;
  final int popular;
  final int free;
  final int premium;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _StatCard(
            value: '$total',
            label: 'Total Tools',
            icon: Icons.grid_view_rounded,
            gradient: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _StatCard(
            value: '$popular',
            label: 'Popular',
            icon: Icons.local_fire_department_rounded,
            accent: AppColors.error,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _StatCard(
            value: '$free',
            label: 'Free',
            icon: Icons.check_circle_rounded,
            accent: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _StatCard(
            value: '$premium',
            label: 'Premium',
            icon: Icons.star_rounded,
            accent: AppColors.goldPremium,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.accent,
    this.gradient = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? accent;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: gradient ? AppColors.brandGradient : null,
        color: gradient ? null : p.surface.withValues(alpha: 0.8),
        borderRadius: Radii.brCard,
        border: gradient ? null : Border.all(color: p.border),
        boxShadow: gradient
            ? [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: gradient
                ? AppColors.onAccent.withValues(alpha: 0.9)
                : (accent ?? p.accent),
          ),
          const Spacer(),
          Text(
            value,
            // The featured (gradient) stat card gets a larger numeral.
            style: (gradient
                    ? AppTypography.headlineSmall(context)
                    : AppTypography.titleMedium(context))
                .copyWith(
              fontWeight: FontWeights.black,
              height: 1,
              color: gradient ? AppColors.onAccent : p.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(context, color: gradient
                  ? AppColors.onAccent.withValues(alpha: 0.85)
                  : p.textMuted, weight: FontWeights.semibold),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.brandGradient : null,
            color: selected ? null : p.surface.withValues(alpha: 0.7),
            borderRadius: Radii.brPill,
            border: Border.all(
              color: selected ? Colors.transparent : p.border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? AppColors.onAccent : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.bodySmall(context, color: selected ? AppColors.onAccent : p.textSecondary, weight: FontWeights.bold),
              ),
            ],
          ),
        ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: p.accent.withValues(alpha: 0.25),
      labelStyle: AppTypography.bodySmall(context, color: selected ? p.accent : p.textSecondary, weight: FontWeights.bold),
      side: BorderSide(color: selected ? p.accent : p.border),
      backgroundColor: p.surface2,
      shape: const RoundedRectangleBorder(borderRadius: Radii.brPill),
    );
  }
}

class _PremiumUpgradeBanner extends StatelessWidget {
  const _PremiumUpgradeBanner({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.violet900, AppColors.violet800, AppColors.brandPrimary],
        ),
        borderRadius: Radii.brPanel,
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.goldPremium.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldPremium.withValues(alpha: 0.5)),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.goldPremium,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Farvixo Premium',
                  style: AppTypography.titleSmall(context, color: AppColors.onAccent, weight: FontWeights.extrabold),
                ),
                SizedBox(height: 2),
                Text(
                  'Unlock all tools & remove limits',
                  style: AppTypography.labelSmall(context, color: AppColors.violet200),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PressableScale(
            onTap: onUpgrade,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandPrimaryHover, AppColors.indigo],
                ),
                borderRadius: Radii.brPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Upgrade Now',
                    style: AppTypography.labelMedium(context, color: AppColors.onAccent, weight: FontWeights.extrabold),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.onAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
