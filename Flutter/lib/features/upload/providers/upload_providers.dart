import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/upload_theme.dart';
import '../domain/upload_item.dart';
import '../domain/upload_source.dart';
import '../domain/upload_status.dart';
import '../domain/upload_transport.dart';

/// The byte mover. Swap this override to point Lightning Upload at the real
/// backend without touching a single widget.
final uploadTransportProvider = Provider<UploadTransport>(
  (ref) => const SimulatedUploadTransport(),
);

/// Whether the device currently has a connection.
///
/// Defaults to online. Override with a `connectivity_plus` stream to make the
/// offline queue live.
final uploadOnlineProvider = StateProvider<bool>((ref) => true);

/// Maximum simultaneous transfers. More is not always faster — beyond ~3 the
/// per-file rate drops and ETA accuracy degrades.
final uploadConcurrencyProvider = StateProvider<int>((ref) => 3);

/// The current platform, used for source lists and layout.
final uploadPlatformProvider = Provider<UploadPlatform>(
  (ref) => UploadPlatform.current,
);

/// Sources available on this device.
final uploadSourcesProvider = Provider<List<UploadSource>>(
  (ref) => UploadSource.forPlatform(ref.watch(uploadPlatformProvider)),
);

/// The upload queue.
final uploadQueueProvider =
    NotifierProvider<UploadQueueController, List<UploadItem>>(
  UploadQueueController.new,
);

/// Aggregate view driving the hero and header.
final uploadSummaryProvider = Provider<UploadSummary>((ref) {
  return UploadSummary(
    items: ref.watch(uploadQueueProvider),
    isOnline: ref.watch(uploadOnlineProvider),
  );
});

/// Owns the queue and every transfer lifecycle.
///
/// Responsibilities: admission (duplicate detection), scheduling (priority +
/// concurrency), transfer (chunked, resumable), and recovery (auto-retry with
/// backoff, offline parking).
class UploadQueueController extends Notifier<List<UploadItem>> {
  final Map<String, StreamSubscription<ChunkProgress>> _subs = {};
  final Map<String, int> _resumeAt = {};
  Timer? _pump;

  /// Auto-retry ceiling before an item is left in [UploadStatus.failed].
  static const int maxAttempts = 3;

  @override
  List<UploadItem> build() {
    ref.onDispose(_disposeAll);
    // Re-pump when connectivity returns so parked items resume themselves.
    ref.listen(uploadOnlineProvider, (_, online) {
      if (online) {
        state = [
          for (final i in state)
            i.status == UploadStatus.offlineQueued
                ? i.copyWith(status: UploadStatus.resuming)
                : i,
        ];
        _schedule();
      } else {
        _parkOffline();
      }
    });
    return const [];
  }

  void _disposeAll() {
    _pump?.cancel();
    for (final s in _subs.values) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }

  // -------------------------------------------------------------------
  // Admission
  // -------------------------------------------------------------------

  /// Adds files to the queue and starts pumping.
  ///
  /// Duplicates (same name + size as an existing non-failed item) are flagged
  /// rather than dropped, so the user decides.
  void enqueue(List<UploadItem> incoming) {
    if (incoming.isEmpty) return;
    final next = [...state];
    for (final item in incoming) {
      final duplicate = next.any(
        (e) =>
            e.name == item.name &&
            e.sizeBytes == item.sizeBytes &&
            e.status != UploadStatus.failed,
      );
      next.add(item.copyWith(
        status: UploadStatus.preparing,
        isDuplicate: duplicate,
      ));
    }
    state = next;
    _schedule();
  }

  void remove(String id) {
    unawaited(_subs.remove(id)?.cancel());
    _resumeAt.remove(id);
    state = state.where((i) => i.id != id).toList();
    _schedule();
  }

  void clearCompleted() {
    state = state.where((i) => i.status != UploadStatus.completed).toList();
  }

  void clearAll() {
    _disposeAll();
    _resumeAt.clear();
    state = const [];
  }

  // -------------------------------------------------------------------
  // User controls
  // -------------------------------------------------------------------

  void pause(String id) {
    final item = _find(id);
    if (item == null || !item.status.canPause) return;
    unawaited(_subs.remove(id)?.cancel());
    _resumeAt[id] = item.transferredBytes;
    _patch(id, (i) => i.copyWith(status: UploadStatus.paused, bytesPerSecond: 0));
    _schedule();
  }

  void resume(String id) {
    final item = _find(id);
    if (item == null || !item.status.canResume) return;
    _patch(id, (i) => i.copyWith(status: UploadStatus.resuming));
    _schedule();
  }

  void retry(String id) {
    final item = _find(id);
    if (item == null || !item.status.canRetry) return;
    _resumeAt[id] = item.transferredBytes;
    _patch(
      id,
      (i) => i.copyWith(
        status: UploadStatus.retrying,
        attempt: 1,
        clearError: true,
      ),
    );
    _schedule();
  }

  void cancel(String id) {
    unawaited(_subs.remove(id)?.cancel());
    _resumeAt.remove(id);
    _patch(
      id,
      (i) => i.copyWith(status: UploadStatus.cancelled, bytesPerSecond: 0),
    );
    _schedule();
  }

  void setPriority(String id, UploadPriority priority) {
    _patch(id, (i) => i.copyWith(priority: priority));
    _schedule();
  }

  void pauseAll() {
    for (final i in state.where((i) => i.status.canPause).toList()) {
      pause(i.id);
    }
  }

  void resumeAll() {
    for (final i in state.where((i) => i.status.canResume).toList()) {
      resume(i.id);
    }
  }

  void retryAll() {
    for (final i in state.where((i) => i.status.canRetry).toList()) {
      retry(i.id);
    }
  }

  // -------------------------------------------------------------------
  // Scheduling
  // -------------------------------------------------------------------

  /// Starts as many transfers as the concurrency budget allows, highest
  /// priority first, then oldest.
  void _schedule() {
    if (!ref.read(uploadOnlineProvider)) {
      _parkOffline();
      return;
    }

    final limit = ref.read(uploadConcurrencyProvider);
    final running = _subs.length;
    if (running >= limit) return;

    final waiting = state
        .where((i) => _isStartable(i.status))
        .toList()
      ..sort((a, b) {
        final byPriority = b.priority.index.compareTo(a.priority.index);
        if (byPriority != 0) return byPriority;
        return state.indexOf(a).compareTo(state.indexOf(b));
      });

    for (final item in waiting.take(limit - running)) {
      _start(item);
    }
  }

  bool _isStartable(UploadStatus s) => const {
        UploadStatus.preparing,
        UploadStatus.resuming,
        UploadStatus.retrying,
      }.contains(s);

  void _parkOffline() {
    for (final s in _subs.values) {
      unawaited(s.cancel());
    }
    _subs.clear();
    state = [
      for (final i in state)
        i.status.isTerminal || i.status == UploadStatus.paused
            ? i
            : i.copyWith(
                status: UploadStatus.offlineQueued,
                bytesPerSecond: 0,
              ),
    ];
  }

  // -------------------------------------------------------------------
  // Transfer
  // -------------------------------------------------------------------

  void _start(UploadItem item) {
    final transport = ref.read(uploadTransportProvider);
    final from = _resumeAt[item.id] ?? item.transferredBytes;

    _patch(item.id, (i) => i.copyWith(status: UploadStatus.uploading));

    final sub = transport.send(item, fromByte: from).listen(
      (chunk) {
        _patch(
          item.id,
          (i) => i.copyWith(
            status: UploadStatus.uploading,
            transferredBytes: chunk.transferredBytes,
            // Exponential smoothing keeps the speed readout from flickering.
            bytesPerSecond: i.bytesPerSecond == 0
                ? chunk.bytesPerSecond
                : i.bytesPerSecond * 0.7 + chunk.bytesPerSecond * 0.3,
          ),
        );
        _resumeAt[item.id] = chunk.transferredBytes;
      },
      onError: (Object e) => _fail(item.id, e),
      onDone: () => _finish(item.id),
      cancelOnError: true,
    );

    _subs[item.id] = sub;
  }

  /// Runs the post-transfer pipeline, then marks the item complete.
  Future<void> _finish(String id) async {
    unawaited(_subs.remove(id)?.cancel());
    _resumeAt.remove(id);

    // Verify → complete. Each stage is visible on the hero.
    _patch(
      id,
      (i) => i.copyWith(
        status: UploadStatus.verifying,
        transferredBytes: i.sizeBytes,
        bytesPerSecond: 0,
      ),
    );
    await Future<void>.delayed(UploadStage.verifyDwell);
    if (_find(id) == null) return;

    _patch(
      id,
      (i) => i.copyWith(
        status: UploadStatus.completed,
        transferredBytes: i.sizeBytes,
        bytesPerSecond: 0,
      ),
    );
    _schedule();
  }

  /// Auto-retries with linear backoff, then gives up and surfaces the error.
  void _fail(String id, Object error) {
    unawaited(_subs.remove(id)?.cancel());
    final item = _find(id);
    if (item == null) return;

    if (item.attempt < maxAttempts) {
      final attempt = item.attempt + 1;
      _patch(
        id,
        (i) => i.copyWith(
          status: UploadStatus.retrying,
          attempt: attempt,
          bytesPerSecond: 0,
        ),
      );
      Timer(UploadStage.retryBackoff * attempt, () {
        if (_find(id) != null) _schedule();
      });
      return;
    }

    _patch(
      id,
      (i) => i.copyWith(
        status: UploadStatus.failed,
        bytesPerSecond: 0,
        error: error is UploadFailure ? error.message : '$error',
      ),
    );
    _schedule();
  }

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------

  UploadItem? _find(String id) {
    for (final i in state) {
      if (i.id == id) return i;
    }
    return null;
  }

  void _patch(String id, UploadItem Function(UploadItem) update) {
    var changed = false;
    final next = <UploadItem>[];
    for (final i in state) {
      if (i.id == id) {
        final updated = update(i);
        changed = changed || updated != i;
        next.add(updated);
      } else {
        next.add(i);
      }
    }
    if (changed) state = next;
  }

  @visibleForTesting
  int get activeTransfers => _subs.length;
}
