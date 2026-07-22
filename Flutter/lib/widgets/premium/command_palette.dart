/// Command palette — jump to any of the 143 tools from anywhere.
///
/// Open with [showCommandPalette]. Fuzzy-matches name, description and id;
/// shows recent tools when the query is empty; fully keyboard-navigable
/// (arrows + Enter + Escape) for desktop and web.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/tools_data.dart';
import '../../models/tool_model.dart';
import '../../providers/tool_activity_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/design_tokens.dart';
import '../../theme/tool_identity.dart';
import 'app_haptics.dart';

/// Shows the palette as a top-aligned glass sheet.
Future<void> showCommandPalette(BuildContext context) {
  AppHaptics.tap();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close command palette',
    barrierColor: const Color(0x99000000),
    transitionDuration: Motion.of(context, Motion.base),
    transitionBuilder: (context, anim, _, child) {
      final t = Motion.curveOf(context, Motion.easeOut).transform(anim.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -24),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, _) => const _CommandPalette(),
  );
}

class _CommandPalette extends ConsumerStatefulWidget {
  const _CommandPalette();

  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  int _highlighted = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Tool> get _results {
    if (_query.trim().isEmpty) {
      final recents = ref.read(recentToolsProvider);
      final byId = {for (final t in ToolsData.tools) t.id: t};
      final recentTools =
          recents.map((id) => byId[id]).whereType<Tool>().take(6).toList();
      if (recentTools.isNotEmpty) return recentTools;
      return ToolsData.tools.take(8).toList();
    }
    return ToolsData.search(_query).take(10).toList();
  }

  void _open(Tool tool) {
    AppHaptics.tick();
    ref.read(recentToolsProvider.notifier).recordUse(tool.id);
    Navigator.of(context).pop();
    GoRouter.of(context).push('/tool/${tool.id}');
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final results = _results;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlighted =
          results.isEmpty ? 0 : (_highlighted + 1) % results.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlighted = results.isEmpty
          ? 0
          : (_highlighted - 1 + results.length) % results.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (results.isNotEmpty) {
        _open(results[_highlighted.clamp(0, results.length - 1)]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final results = _results;
    final showingRecents = _query.trim().isEmpty;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.md, Insets.xxl, Insets.md, Insets.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: Radii.brSheet,
                  border: Border.all(color: p.border),
                  boxShadow: Elevations.level(p, 5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.md, Insets.smd, Insets.md, Insets.xs),
                      child: Focus(
                        onKeyEvent: _onKey,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          autofocus: true,
                          onChanged: (v) => setState(() {
                            _query = v;
                            _highlighted = 0;
                          }),
                          style: AppTypography.bodyLarge(context,
                              color: p.textPrimary),
                          decoration: InputDecoration(
                            icon: Icon(Icons.search_rounded,
                                color: p.textMuted),
                            hintText: 'Search 143 tools…',
                            hintStyle: AppTypography.bodyLarge(context,
                                color: p.textMuted),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: p.border),
                    Flexible(
                      child: results.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(Insets.xl),
                              child: Text(
                                'No tools match "$_query"',
                                style: AppTypography.bodyMedium(context,
                                    color: p.textMuted),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                  vertical: Insets.sm),
                              itemCount: results.length +
                                  (showingRecents ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (showingRecents && i == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        Insets.md, Insets.xs,
                                        Insets.md, Insets.xs),
                                    child: Text(
                                      'Recent',
                                      style: AppTypography.overline(
                                          context, color: p.textMuted),
                                    ),
                                  );
                                }
                                final index = showingRecents ? i - 1 : i;
                                final tool = results[index];
                                return _PaletteRow(
                                  tool: tool,
                                  highlighted: index == _highlighted,
                                  onTap: () => _open(tool),
                                  onHover: () =>
                                      setState(() => _highlighted = index),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.tool,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
  });

  final Tool tool;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final identity = ToolIdentity.of(tool.id, categoryId: tool.categoryId);
    final accent = identity.accent(context);

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.instant),
          color: highlighted
              ? accent.withValues(alpha: p.isDark ? 0.14 : 0.08)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.md, vertical: Insets.sm),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: identity.surfaceGradient(context),
                  borderRadius: Radii.brSm,
                  border: Border.all(color: identity.border(context)),
                ),
                child: Icon(tool.icon, size: 17, color: accent),
              ),
              const SizedBox(width: Insets.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(context,
                          color: p.textPrimary,
                          weight: FontWeights.semibold),
                    ),
                    Text(
                      tool.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium(context,
                          color: p.textMuted),
                    ),
                  ],
                ),
              ),
              if (highlighted)
                Icon(Icons.keyboard_return_rounded,
                    size: 16, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
