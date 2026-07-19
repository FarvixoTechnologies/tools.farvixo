import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import 'engines/image_engines.dart';
import 'engines/local_util_engines.dart';
import 'engines/pdf_engines.dart';
import 'engines/remote_engines.dart';
import 'engines/text_engines.dart';
import 'tool_engine.dart';

/// Maps tool slugs → engines. Registering a `RemoteToolEngine` here instead of a
/// `LocalToolEngine` for a given slug is the ONLY change needed to move that
/// tool server-side — the UI and controller are engine-agnostic.
class ToolEngineRegistry {
  ToolEngineRegistry(this._engines);
  final Map<String, ToolEngine> _engines;

  ToolEngine? forSlug(String slug) => _engines[slug];
  bool supports(String slug) => _engines.containsKey(slug);
}

final toolEngineRegistryProvider = Provider<ToolEngineRegistry>((ref) {
  // Remote engines reuse the existing AiService (Supabase-authed, streaming).
  final ai = ref.watch(aiServiceProvider);
  final qr = QrEngine();
  final base64 = Base64Engine();
  final json = JsonEngine();
  final textStats = TextStatsEngine();
  return ToolEngineRegistry({
    // --- Local (on-device) engines ---
    // PDF (syncfusion)
    'merge-pdf': MergePdfEngine(),
    'image-to-pdf': ImageToPdfEngine(),
    'protect-pdf': ProtectPdfEngine(),
    // Image (image pkg)
    'image-compressor': ImageCompressEngine(),
    'image-resizer': ImageResizeEngine(),
    'image-converter': ImageConvertEngine(),
    'rotate-flip-image': ImageRotateFlipEngine(),
    // Utility (crypto / qr_flutter, offline)
    'hash-generator': HashEngine(),
    'uuid-generator': UuidEngine(),
    'qr-generator': qr, // local-catalog slug
    'qr-code-generator': qr, // backend-catalog slug
    // Text / developer (pure-Dart, offline)
    'base64': base64, // local-catalog slug
    'base64-encoder-decoder': base64, // backend-catalog slug
    'json-formatter': json,
    'json-validator': json,
    'word-counter': textStats,
    'character-counter': textStats,
    'case-converter': CaseConverterEngine(),
    'password-generator': PasswordEngine(),
    'lorem-ipsum-generator': LoremEngine(),

    // --- Remote engines (existing Farvixo AI backend) ---
    'ai-chat': RemoteChatEngine(ai),
    'ai-image-generator': RemoteImageGenEngine(ai),
    'ai-translator': RemoteTranslateEngine(ai),
    'ai-summarizer': RemotePromptEngine(
      ai,
      actionLabel: 'Summarize',
      textHint: 'Paste text to summarize…',
      instruction: 'Summarize the following text clearly and concisely:',
    ),
    'ai-writer': RemotePromptEngine(
      ai,
      actionLabel: 'Write',
      textHint: 'What should I write about?',
      instruction: 'Write high-quality, well-structured content for this brief:',
    ),
    'ai-email-writer': RemotePromptEngine(
      ai,
      actionLabel: 'Draft Email',
      textHint: 'Describe the email you need…',
      instruction:
          'Draft a clear, professional email based on this description:',
    ),
  });
});

/// UI-facing execution state. Mirrors the detail screen's existing visual
/// states (empty/selected/processing/done) without redesigning them.
sealed class ToolExecState {
  const ToolExecState();
}

class ToolIdle extends ToolExecState {
  const ToolIdle();
}

class ToolRunning extends ToolExecState {
  const ToolRunning({this.fraction, this.stage});
  final double? fraction;
  final String? stage;
}

class ToolSuccess extends ToolExecState {
  const ToolSuccess(this.result);
  final ToolResult result;
}

class ToolFailed extends ToolExecState {
  const ToolFailed(this.message);
  final String message;
}

/// Per-tool execution controller. autoDispose+family: one instance per open
/// tool page, released when the page is popped. Cancellation is cooperative and
/// run-scoped (a stale run can never overwrite a newer state).
final toolExecutionProvider = NotifierProvider.autoDispose
    .family<ToolExecutionController, ToolExecState, String>(
  ToolExecutionController.new,
);

class ToolExecutionController
    extends AutoDisposeFamilyNotifier<ToolExecState, String> {
  bool _canceled = false;
  int _runId = 0;

  @override
  ToolExecState build(String arg) => const ToolIdle();

  ToolEngine? get engine =>
      ref.read(toolEngineRegistryProvider).forSlug(arg);

  bool get isSupported => engine != null;

  void cancel() {
    _canceled = true;
    state = const ToolIdle();
  }

  void reset() {
    _canceled = false;
    state = const ToolIdle();
  }

  Future<void> run(ToolInput input) async {
    final eng = engine;
    if (eng == null) {
      state = const ToolFailed('This tool is coming soon on mobile.');
      return;
    }
    _canceled = false;
    final myRun = ++_runId;
    state = const ToolRunning(stage: 'Starting');
    try {
      final result = await eng.run(
        input,
        onProgress: (fraction, stage) {
          if (myRun == _runId && !_canceled) {
            state = ToolRunning(fraction: fraction, stage: stage);
          }
        },
        isCanceled: () => _canceled || myRun != _runId,
      );
      if (myRun != _runId || _canceled) return; // superseded/canceled
      state = ToolSuccess(result);
    } on ToolCanceled {
      if (myRun == _runId) state = const ToolIdle();
    } on ToolFailure catch (e) {
      if (myRun == _runId) state = ToolFailed(e.message);
    } catch (_) {
      if (myRun == _runId) {
        state = const ToolFailed('Processing failed. Please try again.');
      }
    }
  }
}
