import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_palette.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/category_colors.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../widgets/premium/premium.dart';
import '../../../../widgets/premium_kit.dart';
import '../../../upload/presentation/widgets/lightning_picker.dart';
import '../../engine/tool_engine.dart';
import '../../engine/tool_io_service.dart';
import '../engines/pdf_converter_engine.dart';
import '../models/conversion_result.dart';
import '../models/target_format.dart';
import '../providers/pdf_converter_provider.dart';
import '../services/converter_lifecycle_gate.dart';
import '../services/pdf_analyzer.dart';
import '../widgets/analysis_review.dart';
import '../widgets/compare_diff.dart';
import '../widgets/conversion_result_card.dart';
import '../widgets/converter_drop_zone.dart';
import '../widgets/converter_steps.dart';
import '../widgets/format_grid.dart';

/// Unified multi-step PDF Converter — Upload → Analyze → Convert → Download.
class PdfConverterScreen extends ConsumerStatefulWidget {
  const PdfConverterScreen({
    super.key,
    this.lockedTarget,
    this.title = 'PDF Converter',
  });

  final TargetFormat? lockedTarget;
  final String title;

  @override
  ConsumerState<PdfConverterScreen> createState() => _PdfConverterScreenState();
}

class _PdfConverterScreenState extends ConsumerState<PdfConverterScreen> {
  static const _analyzer = PdfAnalyzer();
  bool _compareMode = false;
  final _confetti = ConfettiController();

  /// This tool's unique visual signature within the PDF color family.
  ToolIdentity get _identity =>
      ToolIdentity.of('pdf-converter', categoryId: 'pdf');

  @override
  void initState() {
    super.initState();
    ConverterLifecycleGate.instance.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.lockedTarget != null) {
        ref
            .read(pdfConverterProvider.notifier)
            .setLockedTarget(widget.lockedTarget);
      }
    });
  }

  @override
  void dispose() {
    ConverterLifecycleGate.instance.detach();
    super.dispose();
  }

  Future<void> _pickCamera() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await ref.read(pdfConverterProvider.notifier).stageFile(
          name: x.name.isEmpty ? 'camera.jpg' : x.name,
          bytes: bytes,
        );
  }

  Future<void> _pasteText() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste text → PDF'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Paste or type text…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    await ref.read(pdfConverterProvider.notifier).stageFile(
          name: 'pasted.txt',
          bytes: Uint8List.fromList(utf8.encode(text)),
        );
  }

  Future<void> _importUrl() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com/file.pdf',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(pdfConverterProvider.notifier).importFromUrl(controller.text);
  }

  Future<void> _openSettings() async {
    final ctrl = ref.read(pdfConverterProvider.notifier);
    final state = ref.read(pdfConverterProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        var offline = state.offlineOnly;
        var settings = state.settings;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final p = AppPalette.of(ctx);
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Converter settings',
                      style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Offline-only mode'),
                    subtitle: const Text('Disable URL import'),
                    value: offline,
                    onChanged: (v) {
                      setModal(() => offline = v);
                      ctrl.setOfflineOnly(v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ZIP multi-page images'),
                    value: settings.zipMultiPageImages,
                    onChanged: (v) {
                      final next = settings.copyWith(zipMultiPageImages: v);
                      setModal(() => settings = next);
                      ctrl.updateSettings(next);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Clear conversion history'),
                    onTap: () async {
                      await ctrl.clearHistory();
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack('History cleared');
                    },
                  ),
                  Text(
                    state.isPro
                        ? 'Pro · unlimited conversions'
                        : 'Free · ${state.dailyConversions}/${PdfConverterState.freeDailyLimit} today',
                    style: AppTypography.labelMedium(context, color: p.textMuted),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export(ConversionResult result, {required bool share}) async {
    final io = ref.read(toolIoServiceProvider);
    final toolResult = ToolResult.file(
      result.bytes,
      fileName: result.fileName,
      mime: result.mime,
    );
    if (share) {
      await io.shareResult(toolResult);
    } else {
      final file = await io.saveResult(toolResult);
      if (!mounted) return;
      _snack('Saved to ${file.path}');
      await io.shareResult(toolResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final state = ref.watch(pdfConverterProvider);
    final ctrl = ref.read(pdfConverterProvider.notifier);

    // Physical + visual feedback on the two moments that matter most:
    // success (confetti in this tool's colors) and failure (error buzz).
    ref.listen(pdfConverterProvider, (prev, next) {
      if (next.view == ConverterView.results &&
          prev?.view != ConverterView.results &&
          next.result != null) {
        _confetti.fire();
        AppHaptics.success();
      }
      if (next.error != null && next.error != prev?.error) {
        AppHaptics.error();
      }
    });
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final isTablet = width >= 600 && width < 900;
    final horizontalPad = isWide ? 32.0 : (isTablet ? 24.0 : 20.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: ConfettiBurst(
          controller: _confetti,
          colors: _identity.confettiColors(context),
          child: SafeArea(
          child: Semantics(
            container: true,
            label: '${widget.title} tool',
            child: Column(
              children: [
                PremiumHeader(
                  title: widget.title,
                  subtitle: isWide
                      ? 'On-device · private · drag & drop supported'
                      : 'On-device · private by default',
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: [
                    CircleGlassButton(
                      icon: Icons.tune_rounded,
                      onTap: _openSettings,
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPad, 4, horizontalPad, 12),
                  child: ConverterSteps(view: state.view),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 1100 : double.infinity,
                      ),
                      child: isWide &&
                              state.view == ConverterView.convert &&
                              state.structure != null &&
                              state.lockedTarget == null &&
                              state.inputKind != ConverterInputKind.toPdf
                          ? _wideConvertLayout(state, ctrl, p, horizontalPad)
                          : ListView(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPad,
                                0,
                                horizontalPad,
                                28,
                              ),
                              children: [
                                if (state.error != null) ...[
                                  _errorBanner(state.error!, p),
                                  const SizedBox(height: 12),
                                ],
                                ..._body(state, ctrl, p),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String message, AppPalette p) {
    return Semantics(
      liveRegion: true,
      label: 'Error: $message',
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: AppTypography.bodyLarge(context, color: p.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideConvertLayout(
    PdfConverterState state,
    PdfConverterController ctrl,
    AppPalette p,
    double pad,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.thumbnail != null)
            SizedBox(
              width: 220,
              child: Semantics(
                label: 'Document preview thumbnail',
                image: true,
                child: ClipRRect(
                  borderRadius: Radii.brPanel,
                  child: Image.memory(state.thumbnail!, fit: BoxFit.contain),
                ),
              ),
            ),
          if (state.thumbnail != null) const SizedBox(width: 20),
          Expanded(
            child: ListView(
              children: [
                if (state.error != null) ...[
                  _errorBanner(state.error!, p),
                  const SizedBox(height: 12),
                ],
                ..._convertView(state, ctrl, p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(
    PdfConverterState state,
    PdfConverterController ctrl,
    AppPalette p,
  ) {
    final converting = state.progress != null &&
        state.view == ConverterView.convert &&
        state.result == null &&
        state.error == null;

    if (converting) {
      return [
        ConvertProgressCard(
          fraction: state.progress,
          stage: state.stage,
          onCancel: ctrl.cancel,
          accentColor: _identity.accent(context),
        ),
      ];
    }

    switch (state.view) {
      case ConverterView.upload:
        return [_upload(state, ctrl, p)];
      case ConverterView.analysis:
        return [
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircularProgressIndicator(color: p.accent),
                const SizedBox(height: 16),
                Text(
                  'Detecting headings, tables, images…',
                  style: AppTypography.bodyLarge(context, color: p.textSecondary),
                ),
              ],
            ),
          ),
        ];
      case ConverterView.review:
        if (state.structure == null) return [const Text('No analysis')];
        return [
          if (state.fileName != null) _fileBar(state, ctrl, p),
          const SizedBox(height: 12),
          AnalysisReview(
            structure: state.structure!,
            thumbnail:
                state.thumbnail != null ? MemoryImage(state.thumbnail!) : null,
            onContinue: ctrl.goToConvert,
            onUseRecommendation: () {
              ctrl.selectTarget(state.structure!.recommendation.format);
              ctrl.goToConvert();
            },
            onOpenOcr: () => context.push('/tool/pdf-ocr'),
          ),
        ];
      case ConverterView.convert:
        return _convertView(state, ctrl, p);
      case ConverterView.compare:
        if (state.compareResults.isEmpty) {
          return [
            ConvertProgressCard(
              fraction: state.progress,
              stage: state.stage,
              onCancel: ctrl.cancel,
              accentColor: _identity.accent(context),
            ),
          ];
        }
        return [
          CompareResultsPanel(
            results: state.compareResults,
            onShare: (r) => unawaited(_export(r, share: true)),
            onDiff: ctrl.showDiff,
            onBack: ctrl.changeFormat,
          ),
        ];
      case ConverterView.diff:
        final r = state.result ??
            (state.compareResults.isNotEmpty
                ? state.compareResults.first
                : null);
        if (r == null) return [const Text('No result')];
        return [
          DiffViewPanel(
            originalThumb: state.thumbnail,
            result: r,
            onBack: () => ctrl.changeFormat(),
          ),
        ];
      case ConverterView.results:
        if (state.result == null) return [const Text('No result')];
        final r = state.result!;
        return [
          ConversionResultCard(
            result: r,
            onDownload: () => unawaited(_export(r, share: false)),
            onShare: () => unawaited(_export(r, share: true)),
            onAnother: ctrl.convertAnother,
            onChangeFormat: ctrl.changeFormat,
          ),
          Semantics(
            liveRegion: true,
            label: 'Conversion complete. ${r.fileName}',
            child: const SizedBox.shrink(),
          ),
          if (state.thumbnail != null || r.previewBytes != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: ctrl.showDiff,
              icon: const Icon(Icons.compare_rounded),
              label: const Text('View Diff'),
            ),
          ],
        ];
    }
  }

  Widget _upload(
    PdfConverterState state,
    PdfConverterController ctrl,
    AppPalette p,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Lightning stage in picker mode: same key art as Lightning Upload,
        // but purely local — it hands back bytes and never touches the queue
        // or a transport, so the "files stay on your device" promise holds.
        LightningPicker(
          accept: ConverterFormats.accepted.toList(),
          pickedName: state.fileName,
          busy: state.progress != null,
          hint: 'PDF · Word · Excel · Images · Text',
          onPicked: (file) =>
              ctrl.stageFile(name: file.name, bytes: file.bytes),
        ),
        const SizedBox(height: Gap.item),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickCamera,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pasteText,
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('Paste'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.offlineOnly ? null : _importUrl,
                icon: const Icon(Icons.link_rounded),
                label: const Text('URL'),
              ),
            ),
          ],
        ),
        if (state.history.isNotEmpty) ...[
          const PremiumSectionHead(title: 'Recent conversions'),
          for (final (i, h) in state.history.take(5).indexed)
            FadeSlideIn(
              index: i + 1,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(h.target.icon, color: h.target.accentOf(context)),
                title: Text(
                  h.sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${h.target.label} · ${h.confidence}% · ${_ago(h.timestamp)}',
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(
          'Files stay on your device. URL import uses a direct download (no Farvixo proxy).',
          style: AppTypography.labelMedium(context, color: p.textMuted),
        ),
      ],
    );
  }

  List<Widget> _convertView(
    PdfConverterState state,
    PdfConverterController ctrl,
    AppPalette p,
  ) {
    final toPdf = state.inputKind == ConverterInputKind.toPdf ||
        state.lockedTarget == TargetFormat.pdf;
    return [
      if (state.fileName != null) _fileBar(state, ctrl, p),
      const SizedBox(height: 12),
      if (toPdf)
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Convert ${state.fileName} → PDF',
            style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.bold),
          ),
        )
      else ...[
        Row(
          children: [
            Expanded(
              child: Text(
                _compareMode ? 'Compare formats (2–3)' : 'Output format',
                style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
              ),
            ),
            if (state.lockedTarget == null)
              TextButton(
                onPressed: () => setState(() => _compareMode = !_compareMode),
                child: Text(_compareMode ? 'Single' : 'Compare'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        FormatGrid(
          formats: pdfOutputFormats,
          selected: state.target,
          locked: state.lockedTarget,
          isPro: state.isPro,
          compareMode: _compareMode,
          compareSelected: state.compareFormats,
          onSelect: ctrl.selectTarget,
          onToggleCompare: ctrl.toggleCompareFormat,
        ),
        if (!_compareMode &&
            state.target != null &&
            state.structure != null) ...[
          const SizedBox(height: 12),
          ConfidenceBanner(
            overall: _analyzer
                .confidenceFor(state.structure!, state.target!)
                .overall,
            breakdown:
                _analyzer.confidenceFor(state.structure!, state.target!),
          ),
        ],
        if (!_compareMode &&
            (state.target?.isImage == true ||
                state.target == TargetFormat.pptx)) ...[
          const SizedBox(height: 14),
          _imageSettings(state, ctrl, p),
        ],
      ],
      const SizedBox(height: 18),
      SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: () {
            AppHaptics.tap();
            if (_compareMode) {
              unawaited(ctrl.runCompare());
            } else if (state.target != null) {
              unawaited(ctrl.convert());
            }
          },
          child: Text(
            toPdf
                ? 'Convert to PDF'
                : _compareMode
                    ? 'Compare ${state.compareFormats.length} formats'
                    : 'Convert to ${state.target?.label ?? '…'}',
          ),
        ),
      ),
    ];
  }

  Widget _imageSettings(
    PdfConverterState state,
    PdfConverterController ctrl,
    AppPalette p,
  ) {
    final s = state.settings;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Image quality',
            style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.bold),
          ),
          Slider(
            value: s.imageQuality,
            min: 0.5,
            max: 1.0,
            divisions: 10,
            label: s.imageQuality.toStringAsFixed(2),
            onChanged: (v) => ctrl.updateSettings(s.copyWith(imageQuality: v)),
          ),
          Text(
            'Resolution',
            style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final r in const [1.5, 2.0, 3.0])
                ChoiceChip(
                  label: Text('${r}x'),
                  selected: s.resolution == r,
                  onSelected: (_) =>
                      ctrl.updateSettings(s.copyWith(resolution: r)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fileBar(
    PdfConverterState state,
    PdfConverterController ctrl,
    AppPalette p,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            state.inputKind == ConverterInputKind.pdf
                ? Icons.picture_as_pdf_rounded
                : Icons.insert_drive_file_rounded,
            color: CategoryColors.pdf.accentOf(context),
          ),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Text(
              state.fileName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.bold),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: ctrl.clearFile,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
