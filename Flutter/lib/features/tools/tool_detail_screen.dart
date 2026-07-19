import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/tools_data.dart';
import '../../providers/tool_repository_provider.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/tool_card.dart';
import 'engine/tool_engine.dart';
import 'engine/tool_execution.dart';
import 'engine/tool_io_service.dart';

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
                                        style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            color: p.textPrimary)),
                                    const SizedBox(height: 3),
                                    Text(tool.description,
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.35,
                                            color: p.textSecondary)),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spec.needsFile)
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _pick,
            child: Container(
              height: 184,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: hasFiles ? AppColors.success : accent,
                  width: 1.5,
                ),
                color: (hasFiles ? AppColors.success : accent)
                    .withValues(alpha: .06),
                boxShadow: [
                  BoxShadow(
                      color: (hasFiles ? AppColors.success : accent)
                          .withValues(alpha: .18),
                      blurRadius: 24),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasFiles
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_rounded,
                    size: 50,
                    color: hasFiles ? AppColors.success : accent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasFiles
                        ? (_files.length == 1
                            ? _files.first.name
                            : '${_files.length} files selected')
                        : (spec.multiFile
                            ? 'Tap to select files'
                            : 'Tap to select a file'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: p.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spec.allowedExtensions == null
                        ? 'Processed privately on your device'
                        : '${spec.allowedExtensions!.map((e) => e.toUpperCase()).join(', ')} • on-device',
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                ],
              ),
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
            style: TextStyle(color: p.textPrimary),
            decoration: InputDecoration(
              hintText: spec.textHint,
              hintStyle: TextStyle(color: p.textMuted),
              filled: true,
              fillColor: p.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
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
            style: TextStyle(color: p.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: spec.choice!.label,
              labelStyle: TextStyle(color: p.textMuted),
              filled: true,
              fillColor: p.surface2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
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
            style: TextStyle(fontSize: 12.5, color: p.textMuted),
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
              borderRadius: BorderRadius.circular(999),
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
                TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary),
          ),
          if (fraction != null) ...[
            const SizedBox(height: 4),
            Text('${(fraction * 100).round()}%',
                style: TextStyle(fontSize: 12, color: p.textMuted)),
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
          borderRadius: BorderRadius.circular(18),
          color: p.surface2,
          border: Border.all(color: p.border),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            result.text!,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: p.textPrimary),
          ),
        ),
      );
    } else if (isImage && result.bytes != null) {
      resultZone = ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
          borderRadius: BorderRadius.circular(18),
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
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: p.textPrimary)),
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
              style: TextStyle(fontSize: 12, color: p.textMuted)),
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
          duration: Duration(seconds: 2),
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
            borderRadius: BorderRadius.circular(18),
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
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: p.textPrimary)),
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
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: p.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'This tool isn\'t available on-device yet. You can use it now at tools.farvixo.com.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textMuted),
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
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: p.textPrimary)),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: p.textMuted)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
