import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../../../providers/tool_activity_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/premium/app_haptics.dart';
import '../../../widgets/premium_kit.dart';
import '../../../widgets/primary_button.dart';
import '../converter/services/pdf_rasterizer.dart';
import '../engine/engines/pdf_engines.dart';
import '../engine/tool_engine.dart';
import '../engine/tool_io_service.dart';
import '../tool_history_store.dart';

/// Dedicated premium **Merge PDF** workspace — the reference implementation for
/// the PDF tool family.
///
/// Features: multi-file queue, drag-to-reorder, first-page thumbnails + page
/// counts (PDFium via pdfrx), undo/redo, live totals, on-device merge with
/// progress + cancel, result card with save/share, per-tool history and a
/// favorite toggle. All processing is local (syncfusion `MergePdfEngine`); the
/// UI depends only on the engine contract, so a remote engine could replace it
/// without touching this screen.
class MergePdfScreen extends ConsumerStatefulWidget {
  const MergePdfScreen({super.key});

  static const toolId = 'merge-pdf';

  @override
  ConsumerState<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends ConsumerState<MergePdfScreen> {
  final _engine = MergePdfEngine();
  final _io = ToolIoService();

  final List<_MergeItem> _items = [];
  final List<List<_MergeItem>> _undo = [];
  final List<List<_MergeItem>> _redo = [];

  List<ToolHistoryEntry> _history = const [];
  int _seq = 0;

  /// Base name (no extension) for the merged output. User-editable.
  String _outputName = 'farvixo-merged';

  bool _running = false;
  bool _canceled = false;
  double? _progress;
  String? _stage;

  ToolResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await ToolHistoryStore.instance.load(MergePdfScreen.toolId);
    if (mounted) setState(() => _history = h);
  }

  // ── mutation helpers (undo/redo aware) ────────────────────────────────────

  void _snapshot() {
    _undo.add(List.of(_items));
    if (_undo.length > 30) _undo.removeAt(0);
    _redo.clear();
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    AppHaptics.tick();
    _redo.add(List.of(_items));
    setState(() {
      _items
        ..clear()
        ..addAll(_undo.removeLast());
    });
  }

  void _redoLast() {
    if (_redo.isEmpty) return;
    AppHaptics.tick();
    _undo.add(List.of(_items));
    setState(() {
      _items
        ..clear()
        ..addAll(_redo.removeLast());
    });
  }

  // ── picking + thumbnails ──────────────────────────────────────────────────

  Future<void> _pick() async {
    final picked = await _io.pickFiles(_engine.spec);
    if (picked.isEmpty) return;
    AppHaptics.tap();
    _snapshot();
    final added = <_MergeItem>[];
    for (final f in picked) {
      final item = _MergeItem(id: 'm${_seq++}', file: f);
      added.add(item);
    }
    setState(() {
      _items.addAll(added);
      _result = null;
      _error = null;
    });
    for (final item in added) {
      _startThumb(item);
    }
  }

  /// Render the first page + read the page count in the background, then patch
  /// the row in place. Failures degrade gracefully to an icon placeholder.
  void _startThumb(_MergeItem item) async {
    try {
      await PdfRasterizer.ensureInitialized();
      final doc = await PdfDocument.openData(item.file.bytes);
      try {
        final count = doc.pages.length;
        Uint8List? thumb;
        if (count > 0) {
          final page = doc.pages[0];
          const targetW = 150.0;
          final scale = targetW / page.width;
          final w = (page.width * scale).round().clamp(48, 400);
          final h = (page.height * scale).round().clamp(48, 560);
          final rendered =
              await page.render(fullWidth: w.toDouble(), fullHeight: h.toDouble());
          if (rendered != null) {
            try {
              final image = img.Image.fromBytes(
                width: rendered.width,
                height: rendered.height,
                bytes: rendered.pixels.buffer,
                order: img.ChannelOrder.bgra,
              );
              thumb = Uint8List.fromList(img.encodePng(image));
            } finally {
              rendered.dispose();
            }
          }
        }
        if (!mounted) return;
        setState(() {
          item
            ..pageCount = count
            ..thumb = thumb
            ..thumbLoading = false;
        });
      } finally {
        await doc.dispose();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => item.thumbLoading = false);
    }
  }

  void _remove(_MergeItem item) {
    AppHaptics.tap();
    _snapshot();
    setState(() {
      _items.remove(item);
      _result = null;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    _snapshot();
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final it = _items.removeAt(oldIndex);
      _items.insert(newIndex, it);
      _result = null;
    });
    AppHaptics.drop();
  }

  void _moveToTop(_MergeItem item) {
    final i = _items.indexOf(item);
    if (i <= 0) return;
    AppHaptics.tap();
    _snapshot();
    setState(() {
      _items.removeAt(i);
      _items.insert(0, item);
      _result = null;
    });
  }

  void _moveToBottom(_MergeItem item) {
    final i = _items.indexOf(item);
    if (i < 0 || i == _items.length - 1) return;
    AppHaptics.tap();
    _snapshot();
    setState(() {
      _items.removeAt(i);
      _items.add(item);
      _result = null;
    });
  }

  void _reverseOrder() {
    if (_items.length < 2) return;
    AppHaptics.tap();
    _snapshot();
    setState(() {
      final reversed = _items.reversed.toList();
      _items
        ..clear()
        ..addAll(reversed);
      _result = null;
    });
  }

  void _sortByName() {
    if (_items.length < 2) return;
    AppHaptics.tap();
    _snapshot();
    setState(() {
      _items.sort((a, b) =>
          a.file.name.toLowerCase().compareTo(b.file.name.toLowerCase()));
      _result = null;
    });
  }

  void _sortBySize() {
    if (_items.length < 2) return;
    AppHaptics.tap();
    _snapshot();
    setState(() {
      _items.sort((a, b) => a.file.sizeBytes.compareTo(b.file.sizeBytes));
      _result = null;
    });
  }

  /// Names appearing more than once — surfaced as a subtle badge so users catch
  /// accidental double-adds before merging.
  Set<String> get _duplicateNames {
    final seen = <String, int>{};
    for (final it in _items) {
      final key = it.file.name.toLowerCase();
      seen[key] = (seen[key] ?? 0) + 1;
    }
    return seen.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toSet();
  }

  void _clearAll() {
    if (_items.isEmpty) return;
    AppHaptics.tap();
    _snapshot();
    setState(() {
      _items.clear();
      _result = null;
      _error = null;
    });
  }

  // ── merge ─────────────────────────────────────────────────────────────────

  Future<void> _merge() async {
    if (_items.length < 2) return;
    setState(() {
      _running = true;
      _canceled = false;
      _progress = 0;
      _stage = 'Preparing';
      _error = null;
      _result = null;
    });
    try {
      final input = ToolInput(
        files: _items.map((e) => e.file).toList(),
        options: {
          'pageRanges': _items.map((e) => e.pageRange).toList(),
        },
      );
      final raw = await _engine.run(
        input,
        onProgress: (fraction, stage) {
          if (!mounted) return;
          setState(() {
            _progress = fraction;
            _stage = stage;
          });
        },
        isCanceled: () => _canceled,
      );
      if (!mounted) return;
      // Re-wrap with the user's chosen output name (engine hardcodes a default).
      final name = _sanitizedOutputName();
      final result = ToolResult.file(
        raw.bytes ?? Uint8List(0),
        fileName: '$name.pdf',
        mime: raw.mime ?? 'application/pdf',
        summary: raw.summary,
      );
      setState(() => _result = result);
      AppHaptics.success();
      await ToolHistoryStore.instance.add(
        MergePdfScreen.toolId,
        ToolHistoryEntry(
          summary: result.summary ?? 'Merged ${_items.length} PDFs',
          fileName: result.fileName,
          // (fileName already carries the custom output name)
          timestamp: DateTime.now(),
        ),
      );
      await _loadHistory();
    } on ToolCanceled {
      if (mounted) setState(() => _error = 'Merge canceled.');
    } on ToolFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _progress = null;
          _stage = null;
        });
      }
    }
  }

  Future<void> _share() async {
    final r = _result;
    if (r == null) return;
    await _io.shareResult(r);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final favs = ref.watch(favoriteToolsProvider);
    final isFav = favs.contains(MergePdfScreen.toolId);
    final totalPages =
        _items.fold<int>(0, (sum, it) => sum + _selectedPages(it));
    final totalBytes =
        _items.fold<int>(0, (sum, it) => sum + it.file.sizeBytes);

    return Scaffold(
      backgroundColor: p.bg,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: PremiumHeader(
                  title: 'Merge PDF',
                  subtitle: 'Combine files into one — reorder, then merge',
                  emoji: '📄',
                  onBack: () => context.pop(),
                  actions: [
                    CircleGlassButton(
                      icon: isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      onTap: () {
                        AppHaptics.tap();
                        ref
                            .read(favoriteToolsProvider.notifier)
                            .toggle(MergePdfScreen.toolId);
                      },
                    ),
                    const SizedBox(width: 8),
                    CircleGlassButton(
                      icon: Icons.more_horiz_rounded,
                      onTap: _openMoreSheet,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _items.isEmpty
                    ? _emptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                        children: [
                          _summaryBar(p, totalPages, totalBytes),
                          const SizedBox(height: 10),
                          _outputNameBar(p),
                          if (_duplicateNames.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _duplicateWarning(p),
                          ],
                          const SizedBox(height: 12),
                          _reorderList(p),
                          const SizedBox(height: 8),
                          _addMoreButton(p),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            _errorCard(p, _error!),
                          ],
                          if (_result != null) ...[
                            const SizedBox(height: 16),
                            _resultCard(p),
                          ],
                          if (_history.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _historySection(p),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _items.length >= 2 ? _mergeBar(p) : null,
    );
  }

  /// Secondary actions live here, not in the header (mobile-first: keep the top
  /// bar to Back · Title · Favorite · More).
  Future<void> _openMoreSheet() async {
    AppHaptics.tap();
    final p = AppPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTile(ctx, Icons.undo_rounded, 'Undo',
                enabled: _undo.isNotEmpty, onTap: _undoLast),
            _sheetTile(ctx, Icons.redo_rounded, 'Redo',
                enabled: _redo.isNotEmpty, onTap: _redoLast),
            Divider(color: AppPalette.of(ctx).border, height: 1),
            _sheetTile(ctx, Icons.swap_vert_rounded, 'Reverse order',
                enabled: _items.length >= 2, onTap: _reverseOrder),
            _sheetTile(ctx, Icons.sort_by_alpha_rounded, 'Sort by name (A–Z)',
                enabled: _items.length >= 2, onTap: _sortByName),
            _sheetTile(ctx, Icons.data_usage_rounded, 'Sort by size (small → large)',
                enabled: _items.length >= 2, onTap: _sortBySize),
            Divider(color: AppPalette.of(ctx).border, height: 1),
            _sheetTile(ctx, Icons.drive_file_rename_outline_rounded,
                'Rename output',
                enabled: true, onTap: _editOutputName),
            _sheetTile(ctx, Icons.clear_all_rounded, 'Clear all files',
                enabled: _items.isNotEmpty, onTap: _clearAll),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(
    BuildContext ctx,
    IconData icon,
    String label, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final p = AppPalette.of(ctx);
    final color = enabled ? p.textPrimary : p.textMuted;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: AppTypography.bodyMedium(ctx, color: color)),
      enabled: enabled,
      onTap: enabled
          ? () {
              Navigator.of(ctx).pop();
              onTap();
            }
          : null,
    );
  }

  Widget _emptyState() {
    return PremiumEmptyState(
      icon: Icons.picture_as_pdf_rounded,
      emoji: '📄',
      title: 'Add PDFs to merge',
      message:
          'Pick two or more PDF files. Reorder them any way you like, then merge into a single document — all on your device.',
      actionLabel: 'Choose PDF files',
      onAction: _pick,
    );
  }

  Widget _summaryBar(AppPalette p, int totalPages, int totalBytes) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GlowIcon(
            icon: Icons.layers_rounded,
            color: p.accent,
            size: 42,
            iconSize: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_items.length} file${_items.length == 1 ? '' : 's'} queued',
                  style: AppTypography.titleSmall(context,
                      weight: FontWeights.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${totalPages > 0 ? '$totalPages pages · ' : ''}${_formatBytes(totalBytes)}',
                  style:
                      AppTypography.bodySmall(context, color: p.textSecondary),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _clearAll,
            icon: Icon(Icons.clear_all_rounded,
                size: 18, color: p.textSecondary),
            label: Text('Clear',
                style: AppTypography.labelMedium(context,
                    color: p.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _outputNameBar(AppPalette p) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: InkWell(
        onTap: _editOutputName,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(Icons.description_rounded, size: 20, color: p.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Output file',
                      style: AppTypography.caption(context,
                          color: p.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    '${_sanitizedOutputName()}.pdf',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(context,
                        weight: FontWeights.semibold),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, size: 18, color: p.accent),
          ],
        ),
      ),
    );
  }

  Widget _duplicateWarning(AppPalette p) {
    final n = _duplicateNames.length;
    return GlassCard(
      glowColor: AppColors.warning,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$n file name${n == 1 ? '' : 's'} appear more than once — check for accidental duplicates before merging.',
              style: AppTypography.caption(context, color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reorderList(AppPalette p) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _items.length,
      onReorder: _reorder,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        child: child,
      ),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _fileRow(p, item, index, key: ValueKey(item.id));
      },
    );
  }

  Widget _fileRow(AppPalette p, _MergeItem item, int index, {required Key key}) {
    final isDuplicate = _duplicateNames.contains(item.file.name.toLowerCase());
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: () => _openRowMenu(item, index),
        child: GlassCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
            _positionBadge(p, index),
            const SizedBox(width: 8),
            _thumb(p, item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium(context,
                              weight: FontWeights.semibold),
                        ),
                      ),
                      if (isDuplicate) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded,
                            size: 13, color: AppColors.warning),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _rowSubtitle(item),
                    style: AppTypography.caption(context,
                        color: p.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  _pageRangeChip(p, item),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 20, color: p.textMuted),
              onPressed: () => _remove(item),
              tooltip: 'Remove',
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_indicator_rounded,
                    color: p.textMuted, size: 22),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _positionBadge(AppPalette p, int index) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '${index + 1}',
        style: AppTypography.caption(context, color: p.accent)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Number of pages this item contributes to the merge given its range.
  int _selectedPages(_MergeItem item) {
    final count = item.pageCount ?? 0;
    if (count == 0) return 0;
    return MergePdfEngine.parsePageRange(item.pageRange, count).length;
  }

  Widget _pageRangeChip(AppPalette p, _MergeItem item) {
    final hasRange = item.pageRange != null && item.pageRange!.trim().isNotEmpty;
    final label = hasRange
        ? 'Pages ${item.pageRange}'
        : 'All pages';
    final color = hasRange ? p.accent : p.textSecondary;
    return InkWell(
      onTap: () => _editPageRange(item),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: hasRange ? p.accent.withValues(alpha: .12) : p.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: hasRange ? p.accent.withValues(alpha: .4) : p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_none_rounded, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.caption(context, color: color)
                    .copyWith(fontWeight: FontWeight.w600)),
            if (hasRange) ...[
              const SizedBox(width: 4),
              Text('· ${_selectedPages(item)}',
                  style: AppTypography.caption(context, color: color)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editPageRange(_MergeItem item) async {
    AppHaptics.tap();
    final p = AppPalette.of(context);
    final total = item.pageCount ?? 0;
    final controller = TextEditingController(text: item.pageRange ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Select pages',
            style: AppTypography.titleSmall(ctx, weight: FontWeights.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              total > 0
                  ? 'This PDF has $total pages. Enter pages to include, e.g. 1-3,5,8. Leave blank for all.'
                  : 'Enter pages to include, e.g. 1-3,5,8. Leave blank for all.',
              style: AppTypography.bodySmall(ctx, color: p.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
              decoration: InputDecoration(
                hintText: total > 0 ? '1-$total' : '1-3,5',
                filled: true,
                fillColor: p.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('__clear__'),
            child: Text('All pages',
                style: AppTypography.labelLarge(ctx, color: p.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('Apply',
                style: AppTypography.labelLarge(ctx, color: p.accent)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() {
      item.pageRange =
          (value == '__clear__' || value.trim().isEmpty) ? null : value.trim();
      _result = null;
    });
  }

  Future<void> _openRowMenu(_MergeItem item, int index) async {
    AppHaptics.tap();
    final p = AppPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(item.file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium(ctx, color: p.textSecondary)),
              ),
            ),
            _sheetTile(ctx, Icons.vertical_align_top_rounded, 'Move to top',
                enabled: index > 0, onTap: () => _moveToTop(item)),
            _sheetTile(ctx, Icons.vertical_align_bottom_rounded, 'Move to bottom',
                enabled: index < _items.length - 1,
                onTap: () => _moveToBottom(item)),
            _sheetTile(ctx, Icons.delete_outline_rounded, 'Remove from queue',
                enabled: true, onTap: () => _remove(item)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _thumb(AppPalette p, _MergeItem item) {
    final child = Container(
      width: 46,
      height: 60,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: item.thumb != null
          ? Image.memory(item.thumb!, fit: BoxFit.cover)
          : Center(
              child: item.thumbLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: p.accent),
                    )
                  : Icon(Icons.picture_as_pdf_rounded,
                      color: p.textMuted, size: 22),
            ),
    );
    if (item.thumb == null) return child;
    return GestureDetector(
      onTap: () => _openPreview(item),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          child,
          Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(Icons.zoom_in_rounded,
                  size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPreview(_MergeItem item) async {
    if (item.thumb == null) return;
    AppHaptics.tap();
    final p = AppPalette.of(context);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.memory(item.thumb!, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.file.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall(ctx, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'First page preview · pinch to zoom',
              style: AppTypography.caption(ctx, color: p.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _rowSubtitle(_MergeItem item) {
    final size = _formatBytes(item.file.sizeBytes);
    if (item.thumbLoading) return 'Reading… · $size';
    if (item.pageCount != null) {
      return '${item.pageCount} page${item.pageCount == 1 ? '' : 's'} · $size';
    }
    return size;
  }

  Widget _addMoreButton(AppPalette p) {
    return OutlinedButton.icon(
      onPressed: _running ? null : _pick,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text('Add more PDFs'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: p.border),
        foregroundColor: p.textPrimary,
      ),
    );
  }

  Widget _mergeBar(AppPalette p) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .92),
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: _running
          ? _progressRow(p)
          : PrimaryButton(
              label: _mergeButtonLabel(),
              icon: Icons.merge_type_rounded,
              onPressed: _merge,
            ),
    );
  }

  String _mergeButtonLabel() {
    final pages =
        _items.fold<int>(0, (sum, it) => sum + _selectedPages(it));
    if (pages > 0) {
      return 'Merge ${_items.length} PDFs · $pages pages';
    }
    return 'Merge ${_items.length} PDFs';
  }

  Widget _progressRow(AppPalette p) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_stage ?? 'Merging…',
                  style: AppTypography.labelMedium(context)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: p.surface2,
                  color: p.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () => setState(() => _canceled = true),
          child: Text('Cancel',
              style: AppTypography.labelLarge(context, color: AppColors.error)),
        ),
      ],
    );
  }

  Widget _resultCard(AppPalette p) {
    final r = _result!;
    return GlassCard(
      glowColor: AppColors.success,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlowIcon(
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Merged PDF ready',
                        style: AppTypography.titleSmall(context,
                            weight: FontWeights.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${r.fileName ?? 'farvixo-merged.pdf'} · ${_formatBytes(r.bytes?.length ?? 0)}',
                      style: AppTypography.bodySmall(context,
                          color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Save / Share',
                  icon: Icons.ios_share_rounded,
                  onPressed: _share,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorCard(AppPalette p, String message) {
    return GlassCard(
      glowColor: AppColors.error,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppTypography.bodySmall(context, color: p.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _historySection(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent merges',
                style:
                    AppTypography.titleSmall(context, weight: FontWeights.bold)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                await ToolHistoryStore.instance.clear(MergePdfScreen.toolId);
                await _loadHistory();
              },
              child: Text('Clear',
                  style: AppTypography.labelMedium(context,
                      color: p.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._history.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: p.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(e.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(context)),
                  ),
                  const SizedBox(width: 8),
                  Text(e.ago(),
                      style: AppTypography.caption(context,
                          color: p.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _sanitizedOutputName() {
    final cleaned = _outputName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'farvixo-merged' : cleaned;
  }

  Future<void> _editOutputName() async {
    AppHaptics.tap();
    final controller = TextEditingController(text: _outputName);
    final p = AppPalette.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Output file name',
            style: AppTypography.titleSmall(ctx, weight: FontWeights.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
          decoration: InputDecoration(
            hintText: 'farvixo-merged',
            suffixText: '.pdf',
            filled: true,
            fillColor: p.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: p.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: p.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: AppTypography.labelLarge(ctx, color: p.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('Save',
                style: AppTypography.labelLarge(ctx, color: p.accent)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() => _outputName = value.trim().isEmpty ? 'farvixo-merged' : value.trim());
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / kb).toStringAsFixed(0)} KB';
  }
}

/// One row in the merge queue.
class _MergeItem {
  _MergeItem({required this.id, required this.file});

  final String id;
  final ToolFile file;
  int? pageCount;
  Uint8List? thumb;
  bool thumbLoading = true;

  /// Optional 1-based page-range spec ("1-3,5"); null = all pages.
  String? pageRange;
}
