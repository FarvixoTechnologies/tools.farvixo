import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/auth_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium_kit.dart';
import '../../../widgets/skeletons.dart';
import 'data/scan_history_repository.dart';
import 'models/qr_type.dart';
import 'models/scan_history_entry.dart';
import 'providers/qr_settings_provider.dart';
import 'providers/scan_history_providers.dart';
import 'qr_analytics_screen.dart';
import 'scan_result_screen.dart';

/// Which slice of history is shown.
enum HistoryMode { history, favorites, trash }

/// Production Scan-History screen: encrypted Hive store, fast search, filters,
/// sorting, date-grouped lazy list, swipe-to-delete + undo, multi-select bulk
/// actions, favorites and a recently-deleted bin. Reuses the Farvixo premium
/// kit + design tokens — no new architecture.
///
/// When the privacy "Lock history" setting is on, the contents are gated behind
/// a device-auth prompt.
class ScanHistoryScreen extends ConsumerStatefulWidget {
  const ScanHistoryScreen({super.key, this.initialMode = HistoryMode.history});

  final HistoryMode initialMode;

  @override
  ConsumerState<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends ConsumerState<ScanHistoryScreen> {
  bool _unlocked = false;
  bool _authInFlight = false;

  @override
  void initState() {
    super.initState();
    // Defer to first frame so we can read providers safely.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeUnlock());
  }

  Future<void> _maybeUnlock() async {
    final locked = ref.read(qrSettingsProvider).biometricLock;
    if (!locked) {
      setState(() => _unlocked = true);
      return;
    }
    if (_authInFlight) return;
    setState(() => _authInFlight = true);
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate(reason: 'Unlock your scan history');
    if (!mounted) return;
    setState(() {
      _unlocked = ok;
      _authInFlight = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(scanHistoryRepositoryProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          child: !_unlocked
              ? _LockedView(
                  busy: _authInFlight,
                  onUnlock: _maybeUnlock,
                  onBack: () => Navigator.of(context).maybePop(),
                )
              : repoAsync.when(
                  loading: () => const _HistorySkeleton(),
                  error: (e, _) => _HistoryError(
                    onRetry: () =>
                        ref.invalidate(scanHistoryRepositoryProvider),
                  ),
                  data: (repo) =>
                      _HistoryBody(repo: repo, initialMode: widget.initialMode),
                ),
        ),
      ),
    );
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView({
    required this.busy,
    required this.onUnlock,
    required this.onBack,
  });
  final bool busy;
  final VoidCallback onUnlock;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, 0),
          child: PremiumHeader(title: 'Scan History', onBack: onBack),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlowIcon(
                    icon: Icons.lock_rounded, color: p.accent, size: 72, iconSize: 34),
                const SizedBox(height: Insets.lg),
                Text('History locked',
                    style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold)),
                const SizedBox(height: Insets.sm),
                Text('Authenticate to view your saved scans.',
                    style: AppTypography.bodyLarge(context, color: p.textSecondary)),
                const SizedBox(height: Insets.lg),
                FilledButton.icon(
                  onPressed: busy ? null : onUnlock,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.fingerprint_rounded),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────── body

class _HistoryBody extends ConsumerStatefulWidget {
  const _HistoryBody({required this.repo, required this.initialMode});
  final ScanHistoryRepository repo;
  final HistoryMode initialMode;

  @override
  ConsumerState<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends ConsumerState<_HistoryBody> {
  static const _pageSize = 30;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;
  late HistoryMode _mode = widget.initialMode;
  int _limit = _pageSize;

  ScanHistoryRepository get _repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 400) {
      final total = _repo.matchCount(_queryFor(ref.read(historyQueryProvider)));
      if (_limit < total) setState(() => _limit += _pageSize);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(Motion.searchDebounce, () {
      ref.read(historyQueryProvider.notifier).update((q) => q.copyWith(search: v));
      setState(() => _limit = _pageSize);
    });
  }

  HistoryQuery _queryFor(HistoryQuery base) => base.copyWith(
        favoritesOnly: _mode == HistoryMode.favorites,
        includeDeleted: _mode == HistoryMode.trash,
      );

  void _switchMode(HistoryMode m) {
    HapticFeedback.selectionClick();
    ref.read(historySelectionProvider.notifier).state = {};
    setState(() {
      _mode = m;
      _limit = _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(historyQueryProvider);
    final selection = ref.watch(historySelectionProvider);
    final selecting = selection.isNotEmpty;

    return AnimatedBuilder(
      animation: _repo.listenable,
      builder: (context, _) {
        final effective = _queryFor(query);
        final total = _repo.matchCount(effective);
        final rows = _repo.query(effective, pageSize: _limit > 0 ? _limit : total);
        final hasMore = rows.length < total;
        final grouped = _groupByDate(rows, effective.sort);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.md, Insets.sm, Insets.md, 0),
              child: selecting
                  ? _SelectionBar(
                      count: selection.length,
                      mode: _mode,
                      onClose: () =>
                          ref.read(historySelectionProvider.notifier).state = {},
                      onFavorite: () => _bulkFavorite(selection),
                      onDelete: () => _bulkDelete(selection),
                      onRestore: () => _bulkRestore(selection),
                    )
                  : PremiumHeader(
                      title: switch (_mode) {
                        HistoryMode.history => 'Scan History',
                        HistoryMode.favorites => 'Favorites',
                        HistoryMode.trash => 'Recently Deleted',
                      },
                      subtitle: '$total item${total == 1 ? '' : 's'}',
                      onBack: () => Navigator.of(context).maybePop(),
                      actions: [
                        IconButton(
                          tooltip: 'Analytics',
                          icon: Icon(Icons.insights_rounded,
                              color: AppPalette.of(context).textPrimary),
                          onPressed: () => Navigator.of(context).push(
                            AppPageRoute(
                                builder: (_) => const QrAnalyticsScreen()),
                          ),
                        ),
                        if (_mode != HistoryMode.trash)
                          _SortButton(
                            sort: query.sort,
                            onSelected: (s) {
                              ref
                                  .read(historyQueryProvider.notifier)
                                  .update((q) => q.copyWith(sort: s));
                              setState(() => _limit = _pageSize);
                            },
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: Insets.sm),
            _ModeTabs(
              mode: _mode,
              historyCount: _repo.count,
              favoritesCount: _repo.favoritesCount,
              trashCount: _repo.trashCount,
              onChanged: _switchMode,
            ),
            const SizedBox(height: Insets.sm),
            if (_mode != HistoryMode.trash) ...[
              _SearchBar(controller: _searchCtrl, onChanged: _onSearch),
              _TypeFilterChips(
                counts: _repo.countsByType(),
                selected: query.typeFilter,
                onSelected: (t) {
                  ref.read(historyQueryProvider.notifier).update(
                        (q) => t == null
                            ? q.copyWith(clearTypeFilter: true)
                            : q.copyWith(typeFilter: t),
                      );
                  setState(() => _limit = _pageSize);
                },
              ),
            ],
            Expanded(
              child: rows.isEmpty
                  ? _EmptyState(mode: _mode, searching: query.search.isNotEmpty)
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _repo.runMaintenance();
                        setState(() => _limit = _pageSize);
                      },
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                            Insets.md, Insets.sm, Insets.md, Insets.xxl),
                        itemCount: grouped.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= grouped.length) {
                            return const Padding(
                              padding: EdgeInsets.all(Insets.md),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final node = grouped[i];
                          if (node is _GroupHeader) {
                            return _SectionLabel(label: node.label);
                          }
                          final entry = (node as _GroupItem).entry;
                          return _HistoryRow(
                            key: ValueKey(entry.id),
                            entry: entry,
                            mode: _mode,
                            selected: selection.contains(entry.id),
                            selecting: selecting,
                            onTap: () => _onRowTap(entry, selecting),
                            onLongPress: () => _toggleSelect(entry.id),
                            onFavorite: () => _repo.toggleFavorite(entry.id),
                            onPin: () => _repo.togglePin(entry.id),
                            onDelete: () => _deleteWithUndo(entry),
                            onRestore: () => _repo.restore(entry.id),
                            onDeleteForever: () =>
                                _repo.deleteForever(entry.id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────── row interaction

  void _onRowTap(ScanHistoryEntry entry, bool selecting) {
    if (selecting) {
      _toggleSelect(entry.id);
      return;
    }
    if (_mode == HistoryMode.trash) return;
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => ScanResultScreen(raw: entry.raw, source: entry.source),
      ),
    );
  }

  void _toggleSelect(String id) {
    HapticFeedback.selectionClick();
    final set = {...ref.read(historySelectionProvider)};
    set.contains(id) ? set.remove(id) : set.add(id);
    ref.read(historySelectionProvider.notifier).state = set;
  }

  Future<void> _deleteWithUndo(ScanHistoryEntry entry) async {
    await _repo.softDelete(entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Moved to Recently Deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _repo.restore(entry.id),
          ),
        ),
      );
  }

  Future<void> _bulkDelete(Set<String> ids) async {
    if (_mode == HistoryMode.trash) {
      await _repo.deleteForeverMany(ids);
    } else {
      await _repo.softDeleteMany(ids);
    }
    ref.read(historySelectionProvider.notifier).state = {};
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${ids.length} item${ids.length == 1 ? '' : 's'} '
            '${_mode == HistoryMode.trash ? 'deleted' : 'moved to trash'}'),
      ),
    );
  }

  Future<void> _bulkRestore(Set<String> ids) async {
    await _repo.restoreMany(ids);
    ref.read(historySelectionProvider.notifier).state = {};
  }

  Future<void> _bulkFavorite(Set<String> ids) async {
    await _repo.favoriteMany(ids, favorite: true);
    ref.read(historySelectionProvider.notifier).state = {};
  }
}

// ───────────────────────────────────────────────────────── date grouping

sealed class _GroupNode {}

class _GroupHeader extends _GroupNode {
  _GroupHeader(this.label);
  final String label;
}

class _GroupItem extends _GroupNode {
  _GroupItem(this.entry);
  final ScanHistoryEntry entry;
}

List<_GroupNode> _groupByDate(List<ScanHistoryEntry> rows, HistorySort sort) {
  // Only group chronologically when sorting by time.
  if (sort == HistorySort.type) {
    return [for (final e in rows) _GroupItem(e)];
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(const Duration(days: 7));

  String bucket(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (!day.isBefore(today)) return 'Today';
    if (!day.isBefore(yesterday)) return 'Yesterday';
    if (!day.isBefore(weekStart)) return 'This Week';
    return 'Older';
  }

  final out = <_GroupNode>[];
  String? current;
  for (final e in rows) {
    final b = bucket(e.createdAt);
    if (b != current) {
      current = b;
      out.add(_GroupHeader(b));
    }
    out.add(_GroupItem(e));
  }
  return out;
}

// ─────────────────────────────────────────────────────────────── row card

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.entry,
    required this.mode,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onFavorite,
    required this.onPin,
    required this.onDelete,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final ScanHistoryEntry entry;
  final HistoryMode mode;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavorite;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final accent = entry.type.accentOf(context);

    final card = Semantics(
      button: true,
      selected: selected,
      label: '${entry.type.label}: ${entry.title}',
      child: PressableScale(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: Insets.sm),
          padding: const EdgeInsets.all(Insets.sm + 2),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.16)
                : p.surface.withValues(alpha: p.isDark ? 0.6 : 0.9),
            borderRadius: Radii.brPanel,
            border: Border.all(
              color: selected ? accent : p.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? accent : p.textMuted,
                    size: 22,
                  ),
                ),
              GlowIcon(icon: entry.type.icon, color: accent, glow: false),
              const SizedBox(width: Insets.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (entry.pinned) ...[
                          Icon(Icons.push_pin_rounded,
                              size: 12, color: accent),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall(context, color: p.textPrimary, weight: FontWeights.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.type.label} • ${_ago(entry.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall(context, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              if (!selecting) _rowTrailing(context, p, accent),
            ],
          ),
        ),
      ),
    );

    if (selecting) return card;

    // Swipe: live rows → soft delete; trash rows → restore / delete-forever.
    return Dismissible(
      key: ValueKey('dismiss-${entry.id}'),
      direction: mode == HistoryMode.trash
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      background: _swipeBg(p, left: true),
      secondaryBackground: _swipeBg(p, left: false),
      confirmDismiss: (dir) async {
        if (mode == HistoryMode.trash) {
          if (dir == DismissDirection.startToEnd) {
            onRestore();
          } else {
            onDeleteForever();
          }
          return true;
        }
        onDelete();
        return true;
      },
      child: card,
    );
  }

  Widget _rowTrailing(BuildContext context, AppPalette p, Color accent) {
    if (mode == HistoryMode.trash) {
      return Tooltip(
        message: 'Restore',
        child: IconButton(
          icon: Icon(Icons.restore_rounded, color: p.textSecondary),
          onPressed: onRestore,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: entry.favorite ? 'Unstar' : 'Star',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              entry.favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: entry.favorite ? AppColors.goldPremium : p.textMuted,
              size: 22,
            ),
            onPressed: onFavorite,
          ),
        ),
        _RowMenu(entry: entry, onPin: onPin, onDelete: onDelete),
      ],
    );
  }

  Widget _swipeBg(AppPalette p, {required bool left}) {
    final restore = mode == HistoryMode.trash && left;
    final color = restore ? AppColors.success : AppColors.error;
    final icon = restore ? Icons.restore_rounded : Icons.delete_rounded;
    return Container(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      margin: const EdgeInsets.only(bottom: Insets.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: Radii.brPanel,
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.entry, required this.onPin, required this.onDelete});
  final ScanHistoryEntry entry;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(Icons.more_vert_rounded, color: p.textMuted, size: 20),
      color: p.surface,
      onSelected: (v) {
        switch (v) {
          case 'pin':
            onPin();
          case 'copy':
            Clipboard.setData(ClipboardData(text: entry.raw));
          case 'share':
            Share.share(entry.raw);
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pin',
          child: Text(entry.pinned ? 'Unpin' : 'Pin to top'),
        ),
        const PopupMenuItem(value: 'copy', child: Text('Copy')),
        const PopupMenuItem(value: 'share', child: Text('Share')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────── mode tabs

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({
    required this.mode,
    required this.historyCount,
    required this.favoritesCount,
    required this.trashCount,
    required this.onChanged,
  });
  final HistoryMode mode;
  final int historyCount;
  final int favoritesCount;
  final int trashCount;
  final ValueChanged<HistoryMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
      child: Row(
        children: [
          _tab(context, HistoryMode.history, 'History', historyCount),
          const SizedBox(width: Insets.sm),
          _tab(context, HistoryMode.favorites, 'Favorites', favoritesCount),
          const SizedBox(width: Insets.sm),
          _tab(context, HistoryMode.trash, 'Trash', trashCount),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, HistoryMode m, String label, int count) {
    final p = AppPalette.of(context);
    final active = m == mode;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: '$label, $count items',
        child: PressableScale(
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.standard,
            padding: const EdgeInsets.symmetric(vertical: Insets.sm + 2),
            decoration: BoxDecoration(
              gradient: active ? AppColors.brandGradient : null,
              color: active ? null : p.surface.withValues(alpha: 0.5),
              borderRadius: Radii.brPill,
              border: Border.all(color: active ? Colors.transparent : p.border),
            ),
            child: Text(
              count > 0 ? '$label ($count)' : label,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(context, color: active ? AppColors.onAccent : p.textSecondary, weight: FontWeights.bold),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── search bar

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.titleSmall(context, color: p.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search history…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: p.surface.withValues(alpha: 0.6),
          border: OutlineInputBorder(
            borderRadius: Radii.brPill,
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: Radii.brPill,
            borderSide: BorderSide(color: p.border),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────── type filter chips

class _TypeFilterChips extends StatelessWidget {
  const _TypeFilterChips({
    required this.counts,
    required this.selected,
    required this.onSelected,
  });
  final Map<QrType, int> counts;
  final QrType? selected;
  final ValueChanged<QrType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final types = counts.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (types.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        children: [
          _chip(context, label: 'All', active: selected == null,
              onTap: () => onSelected(null)),
          for (final t in types) ...[
            const SizedBox(width: Insets.sm),
            _chip(context,
                label: t.label,
                icon: t.icon,
                accent: t.accentOf(context),
                active: selected == t,
                onTap: () => onSelected(t)),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
    Color? accent,
  }) {
    final p = AppPalette.of(context);
    final c = accent ?? p.accent;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.2) : p.surface.withValues(alpha: 0.5),
          borderRadius: Radii.brPill,
          border: Border.all(color: active ? c : p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: active ? c : p.textMuted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppTypography.labelMedium(context, color: active ? c : p.textSecondary, weight: FontWeights.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────── selection bar

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.mode,
    required this.onClose,
    required this.onFavorite,
    required this.onDelete,
    required this.onRestore,
  });
  final int count;
  final HistoryMode mode;
  final VoidCallback onClose;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: 'Cancel selection',
          icon: Icon(Icons.close_rounded, color: p.textPrimary),
          onPressed: onClose,
        ),
        Text(
          '$count selected',
          style: AppTypography.titleMedium(context, color: p.textPrimary, weight: FontWeights.extrabold),
        ),
        const Spacer(),
        if (mode == HistoryMode.trash)
          IconButton(
            tooltip: 'Restore',
            icon: const Icon(Icons.restore_rounded, color: AppColors.success),
            onPressed: onRestore,
          )
        else
          IconButton(
            tooltip: 'Add to favorites',
            icon: const Icon(Icons.star_rounded, color: AppColors.goldPremium),
            onPressed: onFavorite,
          ),
        IconButton(
          tooltip: mode == HistoryMode.trash ? 'Delete forever' : 'Delete',
          icon: const Icon(Icons.delete_rounded, color: AppColors.error),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onSelected});
  final HistorySort sort;
  final ValueChanged<HistorySort> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopupMenuButton<HistorySort>(
      tooltip: 'Sort',
      icon: Icon(Icons.sort_rounded, color: p.textPrimary),
      color: p.surface,
      initialValue: sort,
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: HistorySort.newest, child: Text('Newest first')),
        PopupMenuItem(value: HistorySort.oldest, child: Text('Oldest first')),
        PopupMenuItem(value: HistorySort.type, child: Text('By type')),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Insets.sm, 4, Insets.sm),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall(context, color: p.textMuted, weight: FontWeights.extrabold).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

// ─────────────────────────────────────────────────── empty / skeleton / error

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.mode, required this.searching});
  final HistoryMode mode;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = searching
        ? (Icons.search_off_rounded, 'No matches', 'Try a different search term.')
        : switch (mode) {
            HistoryMode.history => (
                Icons.history_rounded,
                'No scans yet',
                'Codes you scan will appear here, stored securely on your device.',
              ),
            HistoryMode.favorites => (
                Icons.star_border_rounded,
                'No favorites',
                'Star a scan to keep it handy here.',
              ),
            HistoryMode.trash => (
                Icons.delete_outline_rounded,
                'Trash is empty',
                'Deleted scans wait here for 30 days before being removed.',
              ),
          };
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: PremiumEmptyState(icon: icon, title: title, message: message),
        ),
      ],
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSkeletonCard(height: 40),
          const SizedBox(height: Insets.md),
          const AppSkeletonCard(height: 44, radius: Radii.pill),
          const SizedBox(height: Insets.md),
          for (var i = 0; i < 6; i++) ...[
            const AppSkeletonCard(height: 66),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Could not open history',
      message: 'The secure history store failed to load.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

// ─────────────────────────────────────────────────────────────── helpers

String _ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${d.day}/${d.month}/${d.year}';
}
