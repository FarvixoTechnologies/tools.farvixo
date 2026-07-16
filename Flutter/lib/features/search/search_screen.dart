import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/tools_data.dart';
import '../../models/tool_model.dart';
import '../../theme/app_palette.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/tool_card.dart';

/// Search — premium galaxy backdrop, glass search field, animated empty /
/// no-result states and a staggered results grid.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<Tool> _results = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    setState(() => _results = ToolsData.search(query));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ---------- glass search bar ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: FadeSlideIn(
                  child: Row(
                    children: [
                      CircleGlassButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/home'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: p.surface.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: p.accent.withValues(alpha: .5)),
                            boxShadow: [
                              BoxShadow(
                                  color: p.accent.withValues(alpha: .12),
                                  blurRadius: 16),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  size: 20, color: p.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focus,
                                  onChanged: _onChanged,
                                  style: TextStyle(color: p.textPrimary),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    hintText: 'Search any tool...',
                                    hintStyle: TextStyle(color: p.textMuted),
                                    border: InputBorder.none,
                                    filled: false,
                                  ),
                                ),
                              ),
                              if (hasQuery)
                                InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    _controller.clear();
                                    _onChanged('');
                                  },
                                  child: Icon(Icons.close_rounded,
                                      size: 18, color: p.textMuted),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ---------- body ----------
              Expanded(child: _buildBody(hasQuery)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool hasQuery) {
    if (!hasQuery) {
      return const PremiumEmptyState(
        icon: Icons.search_rounded,
        title: 'Search across all tools',
        message:
            'Find any of Farvixo\'s 120+ tools by name, category or what it does.',
      );
    }
    if (_results.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No tools found',
        message: 'Nothing matched "${_controller.text.trim()}". '
            'Try a different keyword.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: _results.length,
      itemBuilder: (context, i) =>
          FadeSlideIn(index: i, child: ToolCard(tool: _results[i])),
    );
  }
}
