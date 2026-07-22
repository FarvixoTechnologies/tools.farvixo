import 'dart:async';

import 'package:flutter/widgets.dart';

/// Tracks app lifecycle so heavy converter work can pause when backgrounded
/// (battery + thermal friendly). Engines poll [shouldPause].
class ConverterLifecycleGate with WidgetsBindingObserver {
  ConverterLifecycleGate._();
  static final instance = ConverterLifecycleGate._();

  bool _paused = false;
  bool get shouldPause => _paused;

  bool _attached = false;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
  }

  /// Yields until the app is foreground again (or [timeout]).
  Future<void> waitIfPaused({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (!_paused) return;
    final end = DateTime.now().add(timeout);
    while (_paused && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}
