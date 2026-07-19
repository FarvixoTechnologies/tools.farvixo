/// Yield to the event loop so the UI can paint / cancellation can be observed
/// between heavy synchronous steps (no isolates yet — see Phase 5A notes).
Future<void> yieldFrame() => Future<void>.delayed(Duration.zero);

/// Strip a trailing extension from a file name ("photo.jpg" -> "photo").
String stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

/// Human-readable byte size ("1.4 MB").
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

/// "2.3 MB → 1.1 MB (52% smaller)" style summary for size-changing tools.
String sizeDeltaSummary(int before, int after) {
  final pct = before > 0 ? ((before - after) / before * 100).round() : 0;
  final change = pct >= 0 ? '$pct% smaller' : '${-pct}% larger';
  return '${formatBytes(before)} → ${formatBytes(after)} ($change)';
}
