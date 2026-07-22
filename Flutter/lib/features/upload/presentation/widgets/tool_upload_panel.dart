import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_palette.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/design_tokens.dart';
import '../../domain/tool_upload_spec.dart';
import '../../domain/upload_item.dart';
import '../../domain/upload_source.dart';
import '../../providers/upload_providers.dart';
import '../../services/upload_picker_service.dart';
import '../upload_layout.dart';
import 'lightning_hero.dart';
import 'upload_drop_zone.dart';
import 'upload_queue_tile.dart';
import 'upload_source_sheet.dart';

/// Drop-in upload surface for a tool screen.
///
/// This is how the other 70 upload-consuming tools get Lightning Upload
/// without each one reimplementing a picker:
///
/// ```dart
/// ToolUploadPanel(
///   toolId: 'merge-pdf',
///   onFilesReady: (files) => controller.run(files),
/// )
/// ```
///
/// The panel looks up the tool's [ToolUploadSpec], so accepted extensions,
/// single-vs-batch and gallery preference all come from one registry rather
/// than being restated at every call site. If the tool id has no spec the
/// panel renders nothing — a tool that takes typed text never accidentally
/// grows a drop zone.
class ToolUploadPanel extends ConsumerStatefulWidget {
  const ToolUploadPanel({
    super.key,
    required this.toolId,
    this.onFilesReady,
    this.showQueue = true,
  });

  /// Catalog id, e.g. `merge-pdf`.
  final String toolId;

  /// Fires whenever the accepted set changes, so the tool can enable its CTA.
  final ValueChanged<List<UploadItem>>? onFilesReady;

  /// Show the per-file queue under the stage.
  final bool showQueue;

  @override
  ConsumerState<ToolUploadPanel> createState() => _ToolUploadPanelState();
}

class _ToolUploadPanelState extends ConsumerState<ToolUploadPanel> {
  static const _picker = UploadPickerService();
  bool _dropHover = false;

  ToolUploadSpec? get _spec => ToolUploadSpecs.of(widget.toolId);

  Future<void> _openSourceSheet() async {
    final spec = _spec;
    if (spec == null) return;
    final platform = ref.read(uploadPlatformProvider);
    final choice = await UploadSourceSheet.show(
      context,
      spec.sourcesFor(platform),
    );
    if (choice == null || !mounted) return;
    final items = await _picker.pick(choice, spec: spec);
    if (!mounted || items.isEmpty) return;
    _accept(items);
  }

  void _onDropped(List<({String name, int size, String? path})> payload) {
    final spec = _spec;
    final items = _picker.fromDrop(payload, spec: spec);
    if (items.isEmpty) {
      _reject();
      return;
    }
    _accept(items);
  }

  void _accept(List<UploadItem> items) {
    ref.read(uploadQueueProvider.notifier).enqueue(items);
    widget.onFilesReady?.call(items);
  }

  void _reject() {
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
    final spec = _spec;
    // Tools that take typed input get no upload surface at all.
    if (spec == null) return const SizedBox.shrink();

    final p = AppPalette.of(context);
    final metrics = UploadMetrics.of(context).embedded;
    final summary = ref.watch(uploadSummaryProvider);

    return UploadDropZone(
      onFiles: _onDropped,
      onHoverChanged: (v) => setState(() => _dropHover = v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: metrics.heroMaxHeight,
            child: LightningHero(
              status: summary.status,
              progress: summary.progress,
              isDropTarget: _dropHover,
              metrics: metrics,
              caption: _caption(spec, summary),
              onTap: _openSourceSheet,
            ),
          ),
          const SizedBox(height: Gap.item),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openSourceSheet,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(spec.multiFile ? 'Choose files' : 'Choose file'),
                ),
              ),
              if (summary.total > 0) ...[
                const SizedBox(width: Gap.button),
                OutlinedButton(
                  onPressed: ref.read(uploadQueueProvider.notifier).clearAll,
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
          if (widget.showQueue && summary.total > 0) ...[
            const SizedBox(height: Gap.item),
            for (final item in summary.items) ...[
              UploadQueueTile(item: item),
              const SizedBox(height: Gap.list),
            ],
          ],
          if (summary.isEmpty) ...[
            const SizedBox(height: Gap.inline),
            Text(
              spec.hint ?? 'Accepts ${spec.acceptLabel}',
              textAlign: TextAlign.center,
              style: AppTypography.caption(context, color: p.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  String? _caption(ToolUploadSpec spec, UploadSummary summary) {
    if (summary.isEmpty) {
      final canDrop = UploadPlatform.current.supportsDrop;
      if (spec.multiFile) {
        return canDrop ? 'Drop files, or tap' : 'Tap to choose files';
      }
      return canDrop ? 'Drop a file, or tap' : 'Tap to choose a file';
    }
    if (summary.status.isActive) {
      return '${summary.speedLabel} · ${summary.etaLabel} left';
    }
    return '${summary.total} file${summary.total == 1 ? '' : 's'} ready';
  }
}
