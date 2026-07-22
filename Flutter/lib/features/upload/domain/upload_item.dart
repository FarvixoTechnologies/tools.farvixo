import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'upload_source.dart';
import 'upload_status.dart';

/// Transfer priority within the queue.
enum UploadPriority { low, normal, high }

/// One file in the upload queue.
///
/// Immutable — the controller replaces items rather than mutating them, so
/// Riverpod `select()` watchers rebuild only the row that actually changed.
@immutable
class UploadItem {
  const UploadItem({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.source,
    this.status = UploadStatus.idle,
    this.transferredBytes = 0,
    this.bytesPerSecond = 0,
    this.priority = UploadPriority.normal,
    this.mimeType,
    this.localPath,
    this.sha256,
    this.remoteUrl,
    this.error,
    this.isDuplicate = false,
    this.attempt = 1,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final UploadSource source;
  final UploadStatus status;
  final int transferredBytes;

  /// Instantaneous transfer rate, smoothed by the controller.
  final double bytesPerSecond;

  final UploadPriority priority;
  final String? mimeType;
  final String? localPath;

  /// Integrity digest, filled in during [UploadStatus.verifying].
  final String? sha256;

  /// Final location, filled in on completion.
  final String? remoteUrl;

  /// Human-readable failure reason.
  final String? error;

  /// Another queued item has the same name and size.
  final bool isDuplicate;

  /// 1 on first try; incremented by auto-retry.
  final int attempt;

  /// 0.0–1.0. Completed items always read 1.0 even if size was unknown.
  double get progress {
    if (status == UploadStatus.completed) return 1;
    if (sizeBytes <= 0) return 0;
    return (transferredBytes / sizeBytes).clamp(0.0, 1.0);
  }

  int get remainingBytes => math.max(0, sizeBytes - transferredBytes);

  /// Estimated time to completion, or null when it cannot be known yet.
  Duration? get eta {
    if (!status.isActive || bytesPerSecond <= 0 || remainingBytes <= 0) {
      return null;
    }
    final seconds = remainingBytes / bytesPerSecond;
    if (!seconds.isFinite || seconds > const Duration(days: 1).inSeconds) {
      return null;
    }
    return Duration(seconds: seconds.ceil());
  }

  /// `1.4 MB` — binary units, one decimal above KB.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }

  /// `2.4 MB/s`
  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '—';
    return '${formatBytes(bytesPerSecond.round())}/s';
  }

  /// `1m 20s` / `45s`
  static String formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  String get sizeLabel => formatBytes(sizeBytes);
  String get speedLabel => formatSpeed(bytesPerSecond);
  String get transferredLabel =>
      '${formatBytes(transferredBytes)} / ${formatBytes(sizeBytes)}';
  String get etaLabel {
    final e = eta;
    return e == null ? '—' : formatDuration(e);
  }

  /// File extension without the dot, lowercased. Empty when there is none.
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  UploadItem copyWith({
    UploadStatus? status,
    int? transferredBytes,
    double? bytesPerSecond,
    UploadPriority? priority,
    String? sha256,
    String? remoteUrl,
    String? error,
    bool? isDuplicate,
    int? attempt,
    bool clearError = false,
  }) {
    return UploadItem(
      id: id,
      name: name,
      sizeBytes: sizeBytes,
      source: source,
      status: status ?? this.status,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      priority: priority ?? this.priority,
      mimeType: mimeType,
      localPath: localPath,
      sha256: sha256 ?? this.sha256,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      error: clearError ? null : (error ?? this.error),
      isDuplicate: isDuplicate ?? this.isDuplicate,
      attempt: attempt ?? this.attempt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadItem &&
          other.id == id &&
          other.status == status &&
          other.transferredBytes == transferredBytes &&
          other.bytesPerSecond == bytesPerSecond &&
          other.priority == priority &&
          other.error == error &&
          other.isDuplicate == isDuplicate &&
          other.attempt == attempt;

  @override
  int get hashCode => Object.hash(
        id,
        status,
        transferredBytes,
        bytesPerSecond,
        priority,
        error,
        isDuplicate,
        attempt,
      );
}

/// Aggregate view of the whole queue — what the hero and the header render.
@immutable
class UploadSummary {
  const UploadSummary({
    required this.items,
    required this.isOnline,
  });

  final List<UploadItem> items;
  final bool isOnline;

  bool get isEmpty => items.isEmpty;
  int get total => items.length;

  int get completed =>
      items.where((i) => i.status == UploadStatus.completed).length;
  int get failed => items.where((i) => i.status == UploadStatus.failed).length;
  int get active => items.where((i) => i.status.isActive).length;

  int get totalBytes =>
      items.fold(0, (sum, i) => sum + i.sizeBytes);
  int get transferredBytes =>
      items.fold(0, (sum, i) => sum + i.transferredBytes);

  /// Combined progress across the queue, weighted by file size.
  double get progress {
    if (items.isEmpty) return 0;
    final total = totalBytes;
    if (total <= 0) return completed / items.length;
    return (transferredBytes / total).clamp(0.0, 1.0);
  }

  /// Sum of active transfer rates.
  double get bytesPerSecond => items
      .where((i) => i.status.isActive)
      .fold(0.0, (sum, i) => sum + i.bytesPerSecond);

  /// Time until the whole queue drains.
  Duration? get eta {
    final rate = bytesPerSecond;
    final remaining = totalBytes - transferredBytes;
    if (rate <= 0 || remaining <= 0) return null;
    final seconds = remaining / rate;
    if (!seconds.isFinite) return null;
    return Duration(seconds: seconds.ceil());
  }

  /// The item the hero should be reporting on: first active, else first
  /// pending, else the last one touched.
  UploadItem? get focus {
    for (final i in items) {
      if (i.status.isActive) return i;
    }
    for (final i in items) {
      if (!i.status.isTerminal) return i;
    }
    return items.isEmpty ? null : items.last;
  }

  /// The status the whole stage should display.
  UploadStatus get status {
    if (items.isEmpty) return UploadStatus.idle;
    if (!isOnline && items.any((i) => !i.status.isTerminal)) {
      return UploadStatus.offlineQueued;
    }
    final f = focus;
    if (f == null) return UploadStatus.idle;
    if (f.status.isTerminal && completed == total) return UploadStatus.completed;
    if (f.status.isTerminal && failed > 0) return UploadStatus.failed;
    return f.status;
  }

  String get speedLabel => UploadItem.formatSpeed(bytesPerSecond);
  String get etaLabel {
    final e = eta;
    return e == null ? '—' : UploadItem.formatDuration(e);
  }

  String get transferredLabel =>
      '${UploadItem.formatBytes(transferredBytes)} / '
      '${UploadItem.formatBytes(totalBytes)}';
}
