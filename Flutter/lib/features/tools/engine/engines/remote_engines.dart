import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../models/chat_message.dart';
import '../../../../services/ai_service.dart';
import '../tool_engine.dart';

/// Base for engines that execute against the existing Farvixo AI backend.
/// Symmetric to [LocalToolEngine] — the UI and [ToolExecutionController] treat
/// every engine as a [ToolEngine], so local and remote are interchangeable.
abstract class RemoteToolEngine extends ToolEngine {}

const _kRunTimeout = Duration(seconds: 90);

/// Turn any thrown error into an offline-aware, user-facing [ToolFailure].
/// Rethrows [ToolCanceled] / [ToolFailure] unchanged.
Never _mapError(Object e) {
  if (e is ToolCanceled) throw e;
  if (e is ToolFailure) throw e;
  if (e is AiImageException) throw ToolFailure(e.message);
  if (e is TimeoutException) {
    throw const ToolFailure('This took too long and timed out. Please try again.');
  }
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.cancel:
        throw const ToolCanceled();
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        throw const ToolFailure(
            "You appear to be offline. Check your connection and try again.");
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        throw const ToolFailure('The request timed out. Please try again.');
      default:
        throw const ToolFailure('The AI service is busy. Please try again.');
    }
  }
  throw const ToolFailure('Something went wrong. Please try again.');
}

/// Bridge the controller's [isCanceled] poll to a Dio [CancelToken] so an
/// in-flight request is actually aborted. Caller must dispose the returned
/// record's timer in a `finally`.
({CancelToken token, Timer timer}) _cancelBridge(bool Function() isCanceled) {
  final token = CancelToken();
  final timer = Timer.periodic(const Duration(milliseconds: 150), (t) {
    if (token.isCancelled) {
      t.cancel();
    } else if (isCanceled()) {
      token.cancel();
      t.cancel();
    }
  });
  return (token: token, timer: timer);
}

/// Stream a chat completion for [prompt] and collect it to text. Shared by the
/// chat + prompt-template engines. Honours progress, cancellation and timeout.
Future<String> _runChat(
  AiService ai,
  String prompt, {
  required ToolProgress onProgress,
  required bool Function() isCanceled,
}) async {
  final bridge = _cancelBridge(isCanceled);
  final buffer = StringBuffer();
  final deadline = DateTime.now().add(_kRunTimeout);
  try {
    onProgress(null, 'Thinking…');
    await for (final ev in ai.streamChat(
      history: [ChatMessage(role: ChatRole.user, text: prompt)],
      cancelToken: bridge.token,
    )) {
      if (isCanceled()) throw const ToolCanceled();
      if (DateTime.now().isAfter(deadline)) {
        bridge.token.cancel();
        throw TimeoutException('AI run exceeded ${_kRunTimeout.inSeconds}s');
      }
      if (ev is AiChatDelta) {
        buffer.write(ev.text);
        onProgress(null, 'Generating…');
      } else if (ev is AiChatError) {
        throw ToolFailure(ev.message);
      } else if (ev is AiChatDone) {
        break;
      }
    }
  } catch (e) {
    _mapError(e);
  } finally {
    bridge.timer.cancel();
  }

  final text = buffer.toString().trim();
  if (text.isEmpty) {
    throw const ToolFailure('No response received — please try again.');
  }
  return text;
}

/// AI Chat — one prompt in, streamed answer out.
class RemoteChatEngine extends RemoteToolEngine {
  RemoteChatEngine(this._ai);
  final AiService _ai;

  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Ask AI',
        needsText: true,
        textHint: 'Ask anything…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final prompt = input.text?.trim() ?? '';
    if (prompt.isEmpty) throw const ToolFailure('Enter a question or prompt.');
    final text = await _runChat(_ai, prompt,
        onProgress: onProgress, isCanceled: isCanceled);
    return ToolResult.text(text);
  }
}

/// Instruction-templated AI tool (Summarizer, Writer, Email Writer, …). Reuses
/// the existing chat endpoint with an instruction prefix — no new API.
class RemotePromptEngine extends RemoteToolEngine {
  RemotePromptEngine(
    this._ai, {
    required this.actionLabel,
    required this.textHint,
    required this.instruction,
  });

  final AiService _ai;
  final String actionLabel;
  final String textHint;
  final String instruction;

  @override
  ToolSpec get spec => ToolSpec(
        actionLabel: actionLabel,
        needsText: true,
        textHint: textHint,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final content = input.text?.trim() ?? '';
    if (content.isEmpty) throw const ToolFailure('Enter some text first.');
    final text = await _runChat(_ai, '$instruction\n\n$content',
        onProgress: onProgress, isCanceled: isCanceled);
    return ToolResult.text(text);
  }
}

/// AI Translator — text + target language (minimal selector) over the existing
/// chat endpoint. No dedicated translate API is session-reachable, so this
/// reuses `/api/ai/chat` with a translator instruction.
class RemoteTranslateEngine extends RemoteToolEngine {
  RemoteTranslateEngine(this._ai);
  final AiService _ai;

  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Translate',
        needsText: true,
        textHint: 'Text to translate…',
        choice: ToolChoiceSpec(
          optionKey: 'to',
          label: 'Translate to',
          options: [
            'Spanish',
            'French',
            'German',
            'Hindi',
            'Arabic',
            'Chinese',
            'Japanese',
            'Portuguese',
            'Russian',
            'English',
          ],
          defaultValue: 'Spanish',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final content = input.text?.trim() ?? '';
    if (content.isEmpty) throw const ToolFailure('Enter text to translate.');
    final to = input.option<String>('to') ?? 'Spanish';
    final prompt =
        'Translate the following text to $to. Output only the translation, '
        'with no notes or quotes:\n\n$content';
    final text = await _runChat(_ai, prompt,
        onProgress: onProgress, isCanceled: isCanceled);
    return ToolResult.text(text, summary: 'Translated to $to');
  }
}

/// AI Image Generator — prompt in, JPEG bytes out (reuses AiService).
class RemoteImageGenEngine extends RemoteToolEngine {
  RemoteImageGenEngine(this._ai);
  final AiService _ai;

  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Generate',
        needsText: true,
        textHint: 'Describe the image…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final prompt = input.text?.trim() ?? '';
    if (prompt.isEmpty) throw const ToolFailure('Describe the image to generate.');

    final bridge = _cancelBridge(isCanceled);
    try {
      onProgress(null, 'Generating image…');
      final bytes = await _ai
          .generateImage(prompt: prompt, cancelToken: bridge.token)
          .timeout(_kRunTimeout);
      if (isCanceled()) throw const ToolCanceled();
      return ToolResult.file(
        bytes,
        fileName: 'farvixo-ai-image.jpg',
        mime: 'image/jpeg',
        summary: 'AI-generated image',
      );
    } catch (e) {
      _mapError(e);
    } finally {
      bridge.timer.cancel();
    }
  }
}
