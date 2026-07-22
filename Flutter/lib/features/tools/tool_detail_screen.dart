import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/tools_data.dart';
import '../../providers/tool_repository_provider.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/tool_card.dart';
import '../upload/domain/upload_status.dart';
import '../upload/presentation/upload_layout.dart';
import '../upload/presentation/widgets/lightning_hero.dart';
import 'engine/tool_engine.dart';
import 'engine/tool_execution.dart';
import 'engine/tool_io_service.dart';
import 'engine/engines/scan_engines.dart' show describeQrPayload;
import 'scanner/models/qr_type.dart';
import 'scanner/providers/qr_settings_provider.dart';
import 'scanner/providers/scan_history_providers.dart';
import 'scanner/qr_generator_screen.dart';
import 'scanner/qr_live_scanner_screen.dart';
import 'scanner/scan_result_screen.dart';
import 'scanner/services/qr_parser.dart';
import 'scanner/services/qr_security.dart';
import 'converter/models/target_format.dart';
import 'converter/screens/pdf_converter_screen.dart';

/// Universal tool page — premium galaxy backdrop, glowing tool header, glass
/// workspace (pick → process → share) and related tools. Processing runs on
/// device through a [ToolEngine]; unsupported tools show an honest notice.
class ToolDetailScreen extends ConsumerStatefulWidget {
  const ToolDetailScreen({super.key, required this.toolId});

  final String toolId;

  @override
  ConsumerState<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends ConsumerState<ToolDetailScreen> {
  final List<ToolFile> _files = [];
  final TextEditingController _textController = TextEditingController();
  String? _choiceValue;

  static bool _isPdfConverterTool(String id) => switch (id) {
        'pdf-converter' ||
        'pdf-to-word' ||
        'word-to-pdf' ||
        'pdf-to-excel' ||
        'excel-to-pdf' ||
        'pdf-to-image' =>
          true,
        _ => false,
      };

  static TargetFormat? _converterLock(String id) => switch (id) {
        'pdf-to-word' => TargetFormat.docx,
        'word-to-pdf' => TargetFormat.pdf,
        'pdf-to-excel' => TargetFormat.xlsx,
        'excel-to-pdf' => TargetFormat.pdf,
        'pdf-to-image' => TargetFormat.png,
        _ => null,
      };

  static String _converterTitle(String id) => switch (id) {
        'pdf-to-word' => 'PDF to Word',
        'word-to-pdf' => 'Word to PDF',
        'pdf-to-excel' => 'PDF to Excel',
        'excel-to-pdf' => 'Excel to PDF',
        'pdf-to-image' => 'PDF to Image',
        _ => 'PDF Converter',
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AnalyticsService.instance.toolOpen(widget.toolId));
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  ToolEngine? get _engine =>
      ref.read(toolEngineRegistryProvider).forSlug(widget.toolId);

  /// Line under the stage before anything is picked: what to tap, and what
  /// the tool accepts.
  String _pickHint(ToolSpec spec) {
    final verb = spec.multiFile ? 'Tap to select files' : 'Tap to select a file';
    final formats = spec.allowedExtensions;
    if (formats == null || formats.isEmpty) {
      return '$verb · processed on your device';
    }
    return '$verb\n${formats.map((e) => e.toUpperCase()).join(' · ')} · on-device';
  }

  Future<void> _pick() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      final files = await ref.read(toolIoServiceProvider).pickFiles(engine.spec);
      if (files.isNotEmpty && mounted) {
        setState(() => _files
          ..clear()
          ..addAll(files));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open file: $e')));
      }
    }
  }

  void _run() {
    final choice = _engine?.spec.choice;
    final options = <String, Object?>{};
    if (choice != null) {
      options[choice.optionKey] = _choiceValue ?? choice.defaultValue;
    }
    unawaited(
      ref.read(toolExecutionProvider(widget.toolId).notifier).run(
            ToolInput(
              files: _files,
              text: _textController.text,
              options: options,
            ),
          ),
    );
  }

  void _cancel() =>
      ref.read(toolExecutionProvider(widget.toolId).notifier).cancel();

  /// Live camera scan (QR Scanner tool only) — pushes the viewfinder and
  /// publishes the decoded value through the standard result card.
  Future<void> _liveScan() async {
    final value = await Navigator.of(context).push<String>(
      AppPageRoute(builder: (_) => const QrLiveScannerScreen()),
    );
    if (value == null || !mounted) return;
    ref.read(toolExecutionProvider(widget.toolId).notifier).complete(
          ToolResult.text(value, summary: describeQrPayload(value)),
        );
    final settings = ref.read(qrSettingsProvider);
    // Private mode → scan without saving to history.
    if (!settings.privateMode) unawaited(_recordScan(value, 'camera'));

    // Auto-open safe links, when enabled, instead of the result screen.
    if (settings.autoOpenLinks) {
      final parsed = QrParser.parse(value);
      final verdict = QrSecurity.assess(parsed);
      final uri = parsed.actionUri;
      if (verdict.level == RiskLevel.safe &&
          (parsed.type == QrType.url || parsed.type == QrType.appLink) &&
          uri != null) {
        final launched = await launchUrl(Uri.parse(uri),
                mode: LaunchMode.externalApplication)
            .catchError((_) => false);
        if (launched) return;
      }
    }

    // Rich, typed result with security assessment + smart actions.
    if (!mounted) return;
    await Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => ScanResultScreen(raw: value, source: 'camera'),
      ),
    );
  }

  /// Save a decoded value to the secure history store, tolerating any failure.
  Future<void> _recordScan(String value, String source) async {
    try {
      final repo = await ref.read(scanHistoryRepositoryProvider.future);
      final parsed = QrParser.parse(value);
      await repo.record(
        raw: value,
        type: parsed.type,
        title: parsed.title,
        subtitle: parsed.subtitle,
        source: source,
      );
    } catch (_) {
      // History is a convenience layer — a storage hiccup must not break scanning.
    }
  }

  void _reset() {
    ref.read(toolExecutionProvider(widget.toolId).notifier).reset();
    _textController.clear();
    setState(() => _files.clear());
  }

  Future<void> _share(ToolResult result) async {
    try {
      await ref.read(toolIoServiceProvider).shareResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPdfConverterTool(widget.toolId)) {
      return PdfConverterScreen(
        lockedTarget: _converterLock(widget.toolId),
        title: _converterTitle(widget.toolId),
      );
    }

    if (widget.toolId == 'qr-generator') {
      return const QrGeneratorScreen();
    }

    final p = AppPalette.of(context);
    // Fire analytics when a run finishes (replaces the old simulated toolFinish).
    ref.listen(toolExecutionProvider(widget.toolId), (prev, next) {
      if (next is ToolSuccess) {
        unawaited(
            AnalyticsService.instance.toolFinish(widget.toolId, success: true));
      } else if (next is ToolFailed) {
        unawaited(AnalyticsService.instance
            .toolFinish(widget.toolId, success: false));
      }
    });
    final toolAsync = ref.watch(remoteToolProvider(widget.toolId));
    final tool = toolAsync.valueOrNull;

    if (tool == null && toolAsync.isLoading) {
      return Scaffold(
        body: PremiumBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: PremiumHeader(
                    title: 'Loading…',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/tools'),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: p.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (tool == null) {
      return Scaffold(
        body: PremiumBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: PremiumHeader(
                    title: 'Not found',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/tools'),
                  ),
                ),
                Expanded(
                  child: PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Tool not found',
                    message: 'This tool is no longer available.',
                    actionLabel: 'Retry',
                    onAction: () =>
                        ref.invalidate(remoteToolProvider(widget.toolId)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final category = ref.watch(categoryResolverProvider)(tool.categoryId);
    final relatedSource =
        ref.watch(remoteToolsProvider(tool.categoryId)).valueOrNull ??
            ToolsData.byCategory(tool.categoryId);
    final related = relatedSource
        .where((t) => t.id != tool.id)
        .take(4)
        .toList();

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: tool.name,
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/tools'),
                    actions: [
                      CircleGlassButton(
                        icon: Icons.search_rounded,
                        onTap: () => context.push('/search'),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------- tool identity card ----------
                      FadeSlideIn(
                        index: 1,
                        child: GlassCard(
                          glowColor: category.color,
                          child: Row(
                            children: [
                              GlowIcon(
                                icon: tool.icon,
                                color: category.color,
                                size: 58,
                                iconSize: 30,
                                radius: 16,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(tool.name,
                                        style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold)),
                                    const SizedBox(height: 3),
                                    Text(tool.description,
                                        style: AppTypography.bodySmall(context, color: p.textSecondary).copyWith(height: 1.35)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // ---------- workspace ----------
                      FadeSlideIn(
                          index: 2, child: _buildWorkspace(category.color, p)),
                      const SizedBox(height: 26),
                      // ---------- how it works ----------
                      FadeSlideIn(
                        index: 3,
                        child: const PremiumSectionHead(title: 'How it works'),
                      ),
                      FadeSlideIn(
                          index: 3, child: _HowItWorksRow(accent: p.accent)),
                      const SizedBox(height: 8),
                      // ---------- related ----------
                      if (related.isNotEmpty) ...[
                        FadeSlideIn(
                          index: 4,
                          child: const PremiumSectionHead(
                              title: 'Related tools'),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: related.length,
                          itemBuilder: (context, i) => FadeSlideIn(
                            index: 4 + i,
                            child: ToolCard(tool: related[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspace(Color accent, AppPalette p) {
    final engine = _engine;
    if (engine == null) return _comingSoonCard(p);

    final exec = ref.watch(toolExecutionProvider(widget.toolId));
    return switch (exec) {
      ToolRunning(:final fraction, :final stage) =>
        _processingCard(accent, p, fraction, stage),
      ToolSuccess(:final result) => _resultCard(p, result),
      ToolFailed(:final message) => _errorCard(accent, p, message),
      _ => _inputCard(engine.spec, accent, p),
    };
  }

  // ---------- idle: pick file(s) / enter text, then run ----------
  Widget _inputCard(ToolSpec spec, Color accent, AppPalette p) {
    final hasFiles = _files.isNotEmpty;
    final needsText = spec.needsText;
    final textOk = !needsText || _textController.text.trim().isNotEmpty;
    final fileOk = !spec.needsFile || hasFiles;
    final canRun = fileOk && textOk;

    final isQrScanner = widget.toolId == 'qr-scanner';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isQrScanner) ...[
          PressableScale(
            onTap: _liveScan,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: Radii.brTile,
                boxShadow: Elevations.accentGlow(accent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded,
                      color: AppColors.onAccent, size: 22),
                  const SizedBox(width: Space.s10),
                  Text(
                    'Scan Live with Camera',
                    style: AppTypography.titleSmall(
                      context,
                      color: AppColors.onAccent,
                      weight: FontWeights.extrabold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Divider(color: p.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'or scan from a photo',
                  style: AppTypography.labelSmall(context, color: p.textMuted),
                ),
              ),
              Expanded(child: Divider(color: p.border)),
            ],
          ),
          const SizedBox(height: 14),
        ],
        // Lightning stage, shared by every engine-backed tool. The screen owns
        // picking (via ToolIoService) — the stage is the surface and the
        // status readout, so on-device tools never touch the upload queue.
        if (spec.needsFile)
          SizedBox(
            height: UploadMetrics.of(context).embedded.heroMaxHeight,
            child: LightningHero(
              status: hasFiles ? UploadStatus.completed : UploadStatus.idle,
              metrics: UploadMetrics.of(context).embedded,
              onTap: _pick,
              caption: hasFiles
                  ? (_files.length == 1
                      ? _files.first.name
                      : '${_files.length} files selected')
                  : _pickHint(spec),
            ),
          ),
        if (needsText) ...[
          if (spec.needsFile) const SizedBox(height: 12),
          TextField(
            controller: _textController,
            obscureText: spec.textHint.toLowerCase().contains('password'),
            maxLines: spec.textHint.toLowerCase().contains('password') ? 1 : 3,
            minLines: 1,
            onChanged: (_) => setState(() {}),
            style: AppTypography.bodyLarge(context, color: p.textPrimary),
            decoration: InputDecoration(
              hintText: spec.textHint,
              hintStyle: AppTypography.bodyLarge(context, color: p.textMuted),
              filled: true,
              fillColor: p.surface2,
              border: OutlineInputBorder(
                borderRadius: Radii.brTile,
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: Radii.brTile,
                borderSide: BorderSide(color: p.border),
              ),
            ),
          ),
        ],
        if (spec.choice != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _choiceValue ?? spec.choice!.defaultValue,
            isExpanded: true,
            dropdownColor: p.surface,
            style: AppTypography.titleSmall(context, color: p.textPrimary),
            decoration: InputDecoration(
              labelText: spec.choice!.label,
              labelStyle: AppTypography.bodyMedium(context, color: p.textMuted),
              filled: true,
              fillColor: p.surface2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: Radii.brTile,
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: Radii.brTile,
                borderSide: BorderSide(color: p.border),
              ),
            ),
            items: [
              for (final o in spec.choice!.options)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => setState(() => _choiceValue = v),
          ),
        ],
        if (spec.takesNoInput) ...[
          Text(
            'Tap below to generate a new value.',
            style: AppTypography.bodySmall(context, color: p.textMuted),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: '${spec.actionLabel} Now',
          onPressed: canRun ? _run : null,
        ),
      ],
    );
  }

  // ---------- running: progress + stage + cancel ----------
  Widget _processingCard(
      Color accent, AppPalette p, double? fraction, String? stage) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      glowColor: accent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (fraction == null)
            CircularProgressIndicator(color: accent)
          else
            ClipRRect(
              borderRadius: Radii.brPill,
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: p.surface2,
                color: accent,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            stage ?? 'Processing…',
            style:
                AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.bold),
          ),
          if (fraction != null) ...[
            const SizedBox(height: 4),
            Text('${(fraction * 100).round()}%',
                style: AppTypography.labelMedium(context, color: p.textMuted)),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _cancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ---------- success: result + share + process another ----------
  Widget _resultCard(AppPalette p, ToolResult result) {
    final isImage =
        result.kind == ToolResultKind.file && (result.mime?.startsWith('image/') ?? false);
    final copyable =
        result.kind == ToolResultKind.text ? result.text : result.copyText;
    final canRegenerate = _engine?.spec.canRegenerate ?? false;

    Widget resultZone;
    if (result.kind == ToolResultKind.text && result.text != null) {
      resultZone = Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 280),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: Radii.brPanel,
          color: p.surface2,
          border: Border.all(color: p.border),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            result.text!,
            style: AppTypography.bodyMedium(context, color: p.textPrimary).copyWith(height: 1.45),
          ),
        ),
      );
    } else if (isImage && result.bytes != null) {
      resultZone = ClipRRect(
        borderRadius: Radii.brPanel,
        child: Image.memory(
          result.bytes!,
          height: 240,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else {
      resultZone = Container(
        height: 184,
        decoration: BoxDecoration(
          borderRadius: Radii.brPanel,
          color: AppColors.success.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
                color: AppColors.success.withValues(alpha: .2), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 50, color: AppColors.success),
            const SizedBox(height: 12),
            Text('Done! Your result is ready.',
                style: AppTypography.titleMedium(context, color: p.textPrimary, weight: FontWeights.extrabold)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        resultZone,
        if (result.summary != null) ...[
          const SizedBox(height: 8),
          Text(result.summary!,
              textAlign: TextAlign.center,
              style: AppTypography.labelMedium(context, color: p.textMuted)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (copyable != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(copyable),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(
                      result.kind == ToolResultKind.text ? 'Copy' : 'Copy text'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: PrimaryButton(
                label: 'Share / Save',
                icon: Icons.ios_share_rounded,
                onPressed: () => _share(result),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: canRegenerate ? _run : _reset,
          child: Text(canRegenerate ? 'Regenerate' : 'Process Another'),
        ),
      ],
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Motion.snackbar,
        ),
      );
    }
  }

  // ---------- failure: message + retry ----------
  Widget _errorCard(Color accent, AppPalette p, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: Radii.brPanel,
            color: AppColors.error.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 44, color: AppColors.error),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge(context,
                      color: p.textPrimary, weight: FontWeights.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Try Again',
          icon: Icons.refresh_rounded,
          onPressed: _files.isNotEmpty || _textController.text.isNotEmpty
              ? _run
              : _reset,
        ),
      ],
    );
  }

  // ---------- unsupported tool: honest notice (no fake processing) ----------
  Widget _comingSoonCard(AppPalette p) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.hourglass_top_rounded, size: 44, color: p.accent),
          const SizedBox(height: 12),
          Text('Coming soon on mobile',
              style: AppTypography.titleMedium(context, color: p.textPrimary, weight: FontWeights.extrabold)),
          const SizedBox(height: 4),
          Text(
            'This tool isn\'t available on-device yet. You can use it now at tools.farvixo.com.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(context, color: p.textMuted).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const steps = [
      (Icons.upload_file_rounded, 'Upload', 'Select your file'),
      (Icons.bolt_rounded, 'Process', 'We do the work'),
      (Icons.download_rounded, 'Download', 'Get your result'),
    ];
    return Row(
      children: [
        for (final (icon, title, subtitle) in steps)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  GlowIcon(icon: icon, color: accent, size: 46, iconSize: 22),
                  const SizedBox(height: 8),
                  Text(title,
                      style: AppTypography.bodyMedium(context, color: p.textPrimary, weight: FontWeights.bold)),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall(context, color: p.textMuted)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
