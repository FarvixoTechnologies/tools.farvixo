import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../providers/app_settings_provider.dart';
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
    final reduceMotion =
        ref.watch(settingsPrefProvider(SettingsPrefKey.reduceMotion));
    final boldText =
        ref.watch(settingsPrefProvider(SettingsPrefKey.boldText));
    final highContrast =
        ref.watch(settingsPrefProvider(SettingsPrefKey.highContrast));
    final animationsOn =
        ref.watch(settingsPrefProvider(SettingsPrefKey.animations));

    final light = AppTheme.light(
      accent,
      boldText: boldText,
      highContrast: highContrast,
    );
    final dark = AppTheme.dark(
      accent,
      boldText: boldText,
      highContrast: highContrast,
    );

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final iconBrightness = isDark ? Brightness.light : Brightness.dark;
        final media = MediaQuery.of(context);
        final disableAnims = reduceMotion || !animationsOn;
        Widget content = child ?? const SizedBox.shrink();
        if (disableAnims) {
          content = MediaQuery(
            data: media.copyWith(disableAnimations: true),
            child: content,
          );
        }
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            systemNavigationBarIconBrightness: iconBrightness,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: content,
        );
      },
    );
  }
}
