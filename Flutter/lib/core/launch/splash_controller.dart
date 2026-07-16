import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import 'assets_loader.dart';
import 'config_manager.dart';
import 'decision_engine.dart';
import 'launch_manager.dart';
import 'models/splash_config.dart';

enum LaunchPhase { initializing, ready, error }

/// State rendered by the splash screen.
class LaunchState {
  const LaunchState({
    this.phase = LaunchPhase.initializing,
    this.progress = 0,
    this.message = 'Initializing...',
    this.targetRoute,
    this.config = const SplashConfig(),
  });

  final LaunchPhase phase;
  final double progress;
  final String message;
  final String? targetRoute;
  final SplashConfig config;

  LaunchState copyWith({
    LaunchPhase? phase,
    double? progress,
    String? message,
    String? targetRoute,
    SplashConfig? config,
  }) {
    return LaunchState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      targetRoute: targetRoute ?? this.targetRoute,
      config: config ?? this.config,
    );
  }
}

final splashControllerProvider =
    StateNotifierProvider.autoDispose<SplashController, LaunchState>((ref) {
  final manager = LaunchManager(
    configManager: ConfigManager(),
    assetsLoader: AssetsLoader(),
    decisionEngine: DecisionEngine(
      ref.watch(storageServiceProvider),
      ref.watch(secureStorageProvider),
    ),
    warmUpServices: () async {
      // Session restore + service warm-up (never blocks the UI thread).
      ref.read(authProvider);
      ref.read(apiServiceProvider);
      ref.read(aiServiceProvider);
    },
  );
  return SplashController(manager);
});

/// Riverpod glue between [LaunchManager] and the splash UI —
/// exposes progress, the loaded [SplashConfig], errors and Retry.
class SplashController extends StateNotifier<LaunchState> {
  SplashController(this._manager) : super(const LaunchState());

  final LaunchManager _manager;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    state = const LaunchState();
    try {
      final route = await _manager.run(onProgress: (progress, message) {
        if (!mounted) return;
        state = state.copyWith(
          progress: progress,
          message: message,
          config: _manager.config,
        );
      });
      if (!mounted) return;
      state = state.copyWith(
        phase: LaunchPhase.ready,
        progress: 1,
        targetRoute: route,
      );
    } on LaunchException catch (e) {
      if (!mounted) return;
      state = state.copyWith(phase: LaunchPhase.error, message: e.message);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        phase: LaunchPhase.error,
        message: "We couldn't load resources. Please try again.",
      );
    } finally {
      _running = false;
    }
  }

  /// Auto Retry Mechanism (section 10) — user-triggered retry.
  Future<void> retry() => start();
}
