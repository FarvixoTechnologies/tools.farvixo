import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../providers/theme_provider.dart';
import '../routes/app_router.dart';
import '../services/user_sync_coordinator.dart';
import '../theme/app_theme.dart';

class FarvixoApp extends ConsumerWidget {
  const FarvixoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(supabaseLoginSyncProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: themeMode,
      routerConfig: router,
      // Keep the transparent, edge-to-edge system bars in sync with the
      // active theme. `context` here sits under the resolved Theme, so the
      // status-bar / navigation-bar icons flip to dark in Light mode and
      // stay light in Dark/Custom mode — no page is left with invisible
      // (white-on-white) icons.
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final iconBrightness = isDark ? Brightness.light : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            systemNavigationBarIconBrightness: iconBrightness,
            // iOS status bar uses the inverse convention.
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
