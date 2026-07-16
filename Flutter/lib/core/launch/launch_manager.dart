import 'dart:async';

import 'package:flutter/foundation.dart';

import 'assets_loader.dart';
import 'config_manager.dart';
import 'decision_engine.dart';
import 'models/splash_config.dart';

/// Progress callback: (progress 0..1, message).
typedef LaunchProgress = void Function(double progress, String message);

/// Thrown when startup cannot continue (Error & Fallback Handling,
/// section 10) — the UI shows the fallback splash with Retry.
class LaunchException implements Exception {
  const LaunchException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Launch Manager — orchestrates the launch flow (section 1):
/// Preload & Init → Decision Engine → Next Screen, respecting
/// min/max durations, offline-first behavior and auto-retry.
class LaunchManager {
  LaunchManager({
    required this.configManager,
    required this.assetsLoader,
    required this.decisionEngine,
    this.warmUpServices,
  });

  final ConfigManager configManager;
  final AssetsLoader assetsLoader;
  final DecisionEngine decisionEngine;

  /// Hook for app-level service warm-up (session restore, AI engine).
  final Future<void> Function()? warmUpServices;

  SplashConfig config = const SplashConfig();

  /// Runs the full launch pipeline and returns the target route.
  Future<String> run({required LaunchProgress onProgress}) async {
    final stopwatch = Stopwatch()..start();

    // Initialize System — load config first so timings/colors apply.
    onProgress(0.15, 'Loading configuration...');
    config = await configManager.load();

    try {
      await _initialize(onProgress)
          .timeout(Duration(milliseconds: config.maxDuration));
    } on TimeoutException {
      // Offline First — never hang past maxDuration; continue with
      // whatever initialized (section 3: "Works without internet").
      debugPrint('LaunchManager: maxDuration reached — continuing');
    } catch (e) {
      debugPrint('LaunchManager: fatal init error: $e');
      throw const LaunchException(
          "We couldn't load resources. Please try again.");
    }

    onProgress(0.9, 'Initializing AI Engine...');
    final route = await decisionEngine.decide(config);

    // Respect minDuration so branding never flashes.
    final remaining =
        Duration(milliseconds: config.minDuration) - stopwatch.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    onProgress(1.0, 'Ready');
    debugPrint('LaunchManager: startup ${stopwatch.elapsedMilliseconds} ms');
    return route;
  }

  Future<void> _initialize(LaunchProgress onProgress) async {
    onProgress(0.35, 'Preloading assets...');
    await assetsLoader.preload();

    onProgress(0.55, 'Checking for updates...');
    // TODO(backend): lightweight update/announcement check (never blocking).

    onProgress(0.75, 'Validating session...');
    await warmUpServices?.call();
  }
}
