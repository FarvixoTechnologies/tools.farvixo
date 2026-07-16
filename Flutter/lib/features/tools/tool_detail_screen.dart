import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/tools_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/tool_card.dart';

/// Universal tool page — premium galaxy backdrop, glowing tool header, glass
/// workspace (upload → process → download) and related tools.
/// Processing is simulated until the backend engine is wired in.
class ToolDetailScreen extends StatefulWidget {
  const ToolDetailScreen({super.key, required this.toolId});

  final String toolId;

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

enum _ToolState { empty, fileSelected, processing, done }

class _ToolDetailScreenState extends State<ToolDetailScreen> {
  _ToolState _state = _ToolState.empty;

  Future<void> _selectFile() async {
    // TODO: integrate file_picker once backend processing is wired in.
    setState(() => _state = _ToolState.fileSelected);
  }

  Future<void> _process() async {
    setState(() => _state = _ToolState.processing);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _state = _ToolState.done);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tool = ToolsData.toolById(widget.toolId);
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
                const Expanded(
                  child: PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Tool not found',
                    message: 'This tool is no longer available.',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final category = ToolsData.categoryOf(tool);
    final related = ToolsData.byCategory(tool.categoryId)
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
    switch (_state) {
      case _ToolState.empty:
      case _ToolState.fileSelected:
        final selected = _state == _ToolState.fileSelected;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _selectFile,
              child: Container(
                height: 184,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? AppColors.success : accent,
                    width: 1.5,
                  ),
                  color: (selected ? AppColors.success : accent)
                      .withValues(alpha: .06),
                  boxShadow: [
                    BoxShadow(
                        color: (selected ? AppColors.success : accent)
                            .withValues(alpha: .18),
                        blurRadius: 24),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.cloud_upload_rounded,
                      size: 50,
                      color: selected ? AppColors.success : accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selected
                          ? 'sample-file selected (demo)'
                          : 'Tap to select a file',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: p.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text('Demo mode — processing engine coming soon',
                        style: TextStyle(fontSize: 12, color: p.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Process Now',
              onPressed: selected ? _process : null,
            ),
          ],
        );
      case _ToolState.processing:
        return GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 44),
          glowColor: accent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: accent),
              const SizedBox(height: 16),
              Text('Processing your file...',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: p.textPrimary)),
            ],
          ),
        );
      case _ToolState.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 184,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AppColors.success.withValues(alpha: 0.08),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.success.withValues(alpha: .2),
                      blurRadius: 24),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 50, color: AppColors.success),
                  const SizedBox(height: 12),
                  Text('Done! Your file is ready.',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: p.textPrimary)),
                  const SizedBox(height: 4),
                  Text('(Demo result — real output when engine is live)',
                      style: TextStyle(fontSize: 12, color: p.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Download',
              icon: Icons.download_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Demo mode — nothing to download yet.')),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _state = _ToolState.empty),
              child: const Text('Process Another File'),
            ),
          ],
        );
    }
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
