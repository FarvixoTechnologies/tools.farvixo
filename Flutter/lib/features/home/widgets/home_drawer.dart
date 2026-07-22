import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/farvixo_logo.dart';

/// Home navigation drawer (☰ menu): logo header + quick links.
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key, required this.palette});

  final AppPalette palette;

  static const _items = [
    (Icons.person_outline_rounded, 'Profile', '/profile'),
    (Icons.download_outlined, 'Downloads', '/downloads'),
    (Icons.notifications_outlined, 'Notifications', '/notifications'),
    (Icons.settings_outlined, 'Settings', '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: palette.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(Insets.gutter),
              child: Row(
                children: [
                  const FarvixoLogo(size: 44),
                  const SizedBox(width: Space.s10),
                  Text(
                    'FARVIXO',
                    style: AppTypography.wordmark(
                      context,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final (icon, label, route) in _items)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.pop(context);
                  context.push(route);
                },
              ),
          ],
        ),
      ),
    );
  }
}
