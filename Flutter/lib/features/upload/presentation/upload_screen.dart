import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/category_colors.dart';
import '../../../theme/design_tokens.dart';
import '../domain/tool_upload_spec.dart';
import '../domain/upload_item.dart';
import '../domain/upload_source.dart';
import '../domain/upload_status.dart';
import '../providers/upload_providers.dart';
import '../services/upload_picker_service.dart';
import 'upload_layout.dart';
import 'widgets/lightning_hero.dart';
import 'widgets/upload_drop_zone.dart';
import 'widgets/upload_queue_tile.dart';
import 'widgets/upload_source_sheet.dart';

/// Lightning Upload — the universal upload workspace.
///
/// One widget tree, seven size classes. Every dimension comes from
/// [UploadMetrics], so per-device sizing is a table you can read rather than
/// magic numbers scattered through build methods.
///
/// Pass a [spec] to scope the surface to one tool: the picker then filters to
/// that tool's accepted extensions and offers only sensible sources.
class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key, this.spec, this.title});

  /// When set, the workspace only accepts what this tool can process.
  final ToolUploadSpec? spec;

  /// Overrides the app-bar title (e.g. the tool's name).
  final String? title;

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  static const _picker = UploadPickerService();
  bool _dropHover = false;

  ToolUploadSpec? get _spec => widget.spec;

  Future<void> _openSourceSheet() async {
    final platform = ref.read(uploadPlatformProvider);
    final spec = _spec;
    final List<UploadSource> sources = spec != null
        ? spec.sourcesFor(platform)
        : ref.read(uploadSourcesProvider);
    final choice = await UploadSourceSheet.show(context, sources);
    if (choice == null || !mounted) return;
    await _pickFrom(choice);
  }

  Future<void> _pickFrom(UploadSource source) async {
    final items = await _picker.pick(source, spec: _spec);
    if (!mounted || items.isEmpty) return;
    ref.read(uploadQueueProvider.notifier).enqueue(items);
  }

  void _onDropped(List<({String name, int size, String? path})> payload) {
    final items = _picker.fromDrop(payload, spec: _spec);
    if (items.isEmpty) {
      _rejectDrop();
      return;
    }
    ref.read(uploadQueueProvider.notifier).enqueue(items);
  }

  void _rejectDrop() {
    final accept = _spec?.acceptLabel;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accept == null
              ? 'Those files could not be added.'
              : 'This tool only accepts $accept.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Motion.snackbar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final m = UploadMetrics.of(context);
    final summary = ref.watch(uploadSummaryProvider);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: Row(
          children: [
            const LightningMark(size: 26),
            const SizedBox(width: Gap.icon),
            Expanded(
              child: Text(
                widget.title ?? 'Lightning Upload',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleLarge(
                  context,
                  color: p.textPrimary,
                  weight: FontWeights.extrabold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (summary.completed > 0)
            IconButton(
              tooltip: 'Clear completed',
              onPressed: ref.read(uploadQueueProvider.notifier).clearCompleted,
              icon: const Icon(Icons.cleaning_services_rounded),
            ),
        ],
      ),
      floatingActionButton: m.showExtendedFab
          ? FloatingActionButton.extended(
              onPressed: _openSourceSheet,
              backgroundColor: CategoryColors.upload.accentOf(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(_spec?.multiFile ?? false ? 'Add files' : 'Add file'),
            )
          : null,
      body: UploadDropZone(
        onFiles: _onDropped,
        onHoverChanged: (v) => setState(() => _dropHover = v),
        child: SafeArea(
          child: switch (m.sizeClass.panes) {
            1 => _onePane(m, summary),
            2 => _twoPane(m, summary),
            _ => _threePane(m, summary),
          },
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Pane layouts
  // -------------------------------------------------------------------

  Widget _onePane(UploadMetrics m, UploadSummary summary) {
    return Column(
      children: [
        Expanded(flex: m.heroFlex, child: _hero(m, summary)),
        Expanded(
          flex: m.queueFlex,
          child: summary.isEmpty ? _emptyHint() : _queueList(summary),
        ),
      ],
    );
  }

  Widget _twoPane(UploadMetrics m, UploadSummary summary) {
    return Row(
      children: [
        Expanded(flex: m.heroFlex, child: _hero(m, summary)),
        Expanded(flex: m.queueFlex, child: _sidePanel(m, summary)),
      ],
    );
  }

  Widget _threePane(UploadMetrics m, UploadSummary summary) {
    return Row(
      children: [
        if (m.showSourceRail) _sourceRail(m),
        Expanded(child: _hero(m, summary)),
        SizedBox(width: m.queuePanelWidth, child: _sidePanel(m, summary)),
      ],
    );
  }

  Widget _sidePanel(UploadMetrics m, UploadSummary summary) {
    final p = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: p.border)),
      ),
      child: Column(
        children: [
          if (m.showStatsStrip) _stats(summary),
          Expanded(
            child: summary.isEmpty ? _emptyHint() : _queueList(summary),
          ),
          _queueActions(summary),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Pieces
  // -------------------------------------------------------------------

  Widget _hero(UploadMetrics m, UploadSummary summary) {
    return Padding(
      padding: EdgeInsets.all(
        m.sizeClass.isHandset ? Gap.item : Gap.screen,
      ),
      child: LightningHero(
        status: summary.status,
        progress: summary.progress,
        isDropTarget: _dropHover,
        caption: _caption(summary),
        metrics: m,
        onTap: _openSourceSheet,
      ),
    );
  }

  String? _caption(UploadSummary summary) {
    if (summary.isEmpty) {
      final accept = _spec?.acceptLabel;
      final base = UploadPlatform.current.supportsDrop
          ? 'Drop files here, or tap to browse'
          : 'Tap to choose files';
      return accept == null ? base : '$base · $accept';
    }
    final status = summary.status;
    if (status == UploadStatus.completed) {
      return '${summary.completed} of ${summary.total} uploaded';
    }
    if (status == UploadStatus.failed) {
      return '${summary.failed} failed · retry from the queue';
    }
    if (status == UploadStatus.offlineQueued) {
      return '${summary.total} waiting for a connection';
    }
    if (status.isActive) {
      return '${summary.transferredLabel} · ${summary.speedLabel} · '
          '${summary.etaLabel} left';
    }
    return summary.focus?.name;
  }

  Widget _stats(UploadSummary summary) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.screen,
            Gap.screen,
            Gap.screen,
            Gap.item,
          ),
          child: Row(
            children: [
              Expanded(child: _Stat(label: 'Queued', value: '${summary.total}')),
              Expanded(child: _Stat(label: 'Done', value: '${summary.completed}')),
              Expanded(child: _Stat(label: 'Failed', value: '${summary.failed}')),
              Expanded(child: _Stat(label: 'Speed', value: summary.speedLabel)),
            ],
          ),
        ),
        Divider(height: 1, color: p.border),
      ],
    );
  }

  Widget _queueList(UploadSummary summary) {
    return ListView.separated(
      padding: const EdgeInsets.all(Gap.screen),
      itemCount: summary.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.list),
      itemBuilder: (context, i) => UploadQueueTile(item: summary.items[i]),
    );
  }

  Widget _queueActions(UploadSummary summary) {
    if (summary.isEmpty) return const SizedBox.shrink();
    final queue = ref.read(uploadQueueProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(Gap.screen),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: queue.pauseAll,
              icon: const Icon(Icons.pause_rounded, size: 18),
              label: const Text('Pause all'),
            ),
          ),
          const SizedBox(width: Gap.button),
          Expanded(
            child: FilledButton.icon(
              onPressed: summary.failed > 0 ? queue.retryAll : queue.resumeAll,
              icon: Icon(
                summary.failed > 0
                    ? Icons.refresh_rounded
                    : Icons.play_arrow_rounded,
                size: 18,
              ),
              label: Text(summary.failed > 0 ? 'Retry failed' : 'Resume all'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceRail(UploadMetrics m) {
    final p = AppPalette.of(context);
    final platform = ref.watch(uploadPlatformProvider);
    final spec = _spec;
    final List<UploadSource> sources = spec != null
        ? spec.sourcesFor(platform)
        : ref.watch(uploadSourcesProvider);

    return Container(
      width: m.railWidth,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(Gap.item),
        children: [
          for (final group in SourceGroup.values)
            if (sources.any((s) => s.group == group)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.inline,
                  Gap.item,
                  Gap.inline,
                  Gap.inline,
                ),
                child: Text(
                  group.label.toUpperCase(),
                  style: AppTypography.overline(context, color: p.textMuted),
                ),
              ),
              for (final source in sources.where((s) => s.group == group))
                _RailTile(source: source, onTap: () => _pickFrom(source)),
            ],
        ],
      ),
    );
  }

  Widget _emptyHint() {
    final p = AppPalette.of(context);
    final platform = UploadPlatform.current;
    final spec = _spec;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nothing queued yet',
              style: AppTypography.titleMedium(
                context,
                color: p.textPrimary,
                weight: FontWeights.bold,
              ),
            ),
            const SizedBox(height: Gap.inline),
            Text(
              spec?.hint ??
                  (platform.supportsDrop
                      ? 'Drag files anywhere on this window, or use the button.'
                      : 'Pick files from your device to get started.'),
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(context, color: p.textMuted),
            ),
            if (spec != null) ...[
              const SizedBox(height: Gap.inline),
              Text(
                'Accepts ${spec.acceptLabel}',
                style: AppTypography.caption(context, color: p.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric(
            context,
            color: p.textPrimary,
            weight: FontWeights.extrabold,
          ),
        ),
        const SizedBox(height: Space.s2),
        Text(
          label.toUpperCase(),
          style: AppTypography.overline(context, color: p.textMuted),
        ),
      ],
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({required this.source, required this.onTap});

  final UploadSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final identity = source.group.identity;
    final blocked = UploadPickerService.unavailableReason(source);
    final enabled = blocked == null;

    return Tooltip(
      message: blocked ?? source.detail,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: Radii.brTile,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.inline,
              vertical: Space.s10,
            ),
            child: Row(
              children: [
                Icon(
                  source.icon,
                  size: 18,
                  color: enabled ? identity.accentOf(context) : p.textMuted,
                ),
                const SizedBox(width: Gap.icon),
                Expanded(
                  child: Text(
                    source.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium(
                      context,
                      color: p.textPrimary,
                      weight: FontWeights.semibold,
                    ),
                  ),
                ),
                if (!enabled)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: p.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
