/// Engines for tools whose native module (microphone, TTS voice, ML model,
/// screen capture) is not integrated yet. They register normally — so no tool
/// shows "Coming soon" — but running them returns an honest, actionable
/// explanation instead of fake output, per CLAUDE.md engine rules.
library;

import '../tool_engine.dart';

/// Honest placeholder for tools awaiting a native capability.
class PendingNativeEngine extends LocalToolEngine {
  PendingNativeEngine({
    required this.actionLabel,
    required this.reason,
    this.needsFile = false,
    this.allowedExtensions,
    this.pickFromGallery = false,
    this.needsText = false,
    this.textHint = 'Enter text',
  });

  final String actionLabel;

  /// User-facing explanation of what is missing and where to do it today.
  final String reason;

  final bool needsFile;
  final List<String>? allowedExtensions;
  final bool pickFromGallery;
  final bool needsText;
  final String textHint;

  @override
  ToolSpec get spec => ToolSpec(
        actionLabel: actionLabel,
        needsFile: needsFile,
        allowedExtensions: allowedExtensions,
        pickFromGallery: pickFromGallery,
        needsText: needsText,
        textHint: textHint,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(null, 'Checking device capability');
    throw ToolFailure(reason);
  }
}
