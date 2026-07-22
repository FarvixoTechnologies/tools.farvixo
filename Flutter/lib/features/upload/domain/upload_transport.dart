import 'dart:async';
import 'dart:math' as math;

import '../../../theme/upload_theme.dart';
import 'upload_item.dart';

/// One chunk of transfer progress reported back to the controller.
class ChunkProgress {
  const ChunkProgress({
    required this.transferredBytes,
    required this.bytesPerSecond,
  });

  final int transferredBytes;
  final double bytesPerSecond;
}

/// The boundary between the Lightning Upload UI and whatever actually moves
/// bytes.
///
/// The UI never talks to Supabase, Firebase Storage or the Farvixo API
/// directly — it drives this interface. That keeps the backend untouched (see
/// CLAUDE.md § DO NOT CHANGE) and makes the whole queue testable without a
/// network.
///
/// A production implementation wraps the existing storage service and emits
/// one [ChunkProgress] per completed chunk, supporting resume by starting at
/// `fromByte`.
abstract class UploadTransport {
  /// Streams progress for [item], starting at [fromByte] for resume.
  ///
  /// Must complete when the last chunk lands, or emit an error the controller
  /// can surface. Cancelling the subscription must abort the transfer.
  Stream<ChunkProgress> send(UploadItem item, {int fromByte});

  /// Chunk size in bytes. Smaller chunks = finer progress + cheaper resume,
  /// at the cost of more round trips.
  int get chunkBytes => 256 * 1024;
}

/// Local transport that simulates a realistic chunked transfer.
///
/// This is what ships until the backend upload endpoint is wired. It models
/// variable throughput and honours cancellation and resume exactly like a real
/// transport, so every queue behaviour — pause, resume, retry, ETA, speed —
/// is exercised for real rather than faked in the UI.
class SimulatedUploadTransport implements UploadTransport {
  const SimulatedUploadTransport({
    this.targetBytesPerSecond = 3 * 1024 * 1024,
    this.failureRate = 0,
    this.seed = 7,
  });

  /// Nominal throughput; actual rate jitters around this.
  final double targetBytesPerSecond;

  /// 0–1 chance a given transfer fails partway, for exercising the error path.
  final double failureRate;

  final int seed;

  @override
  int get chunkBytes => 256 * 1024;

  @override
  Stream<ChunkProgress> send(UploadItem item, {int fromByte = 0}) async* {
    final rnd = math.Random(seed + item.id.hashCode);
    var sent = fromByte;

    const tick = UploadStage.chunkTick;

    while (sent < item.sizeBytes) {
      await Future<void>.delayed(tick);

      // Jitter throughput ±35% so speed and ETA behave like a real network.
      final jitter = 0.65 + rnd.nextDouble() * 0.7;
      final rate = targetBytesPerSecond * jitter;
      final delta = (rate * tick.inMilliseconds / 1000).round();

      sent = math.min(item.sizeBytes, sent + math.max(1, delta));

      if (failureRate > 0 && rnd.nextDouble() < failureRate * 0.02) {
        throw const UploadFailure('Connection lost during transfer');
      }

      yield ChunkProgress(transferredBytes: sent, bytesPerSecond: rate);
    }
  }
}

/// A transfer error the controller can present to the user.
class UploadFailure implements Exception {
  const UploadFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
