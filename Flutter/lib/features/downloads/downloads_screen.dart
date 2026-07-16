import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/premium_kit.dart';

/// Downloads — premium galaxy backdrop, glass header, animated empty state.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: 'Downloads',
                    subtitle: 'Your processed files',
                    emoji: '📥',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                  ),
                ),
              ),
              Expanded(
                child: PremiumEmptyState(
                  icon: Icons.download_rounded,
                  title: 'No downloads yet',
                  message:
                      'Files you process with Farvixo tools will appear here.',
                  actionLabel: 'Explore Tools',
                  onAction: () => context.go('/tools'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
