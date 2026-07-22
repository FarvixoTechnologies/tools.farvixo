import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/chat_message.dart';
import 'supabase_service.dart';

/// Thrown when AI image generation fails with a user-facing message.
class AiImageException implements Exception {
  AiImageException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Internal: the AI backend/providers are momentarily overloaded (429 /
/// queue full). Triggers an automatic retry with backoff, then fallback.
class _AiBusyException implements Exception {
  const _AiBusyException();
}

/// Stream events from [AiService.streamChat].
sealed class AiChatEvent {
  const AiChatEvent();
}

class AiChatDelta extends AiChatEvent {
  const AiChatDelta(this.text);
  final String text;
}

class AiChatProviderInfo extends AiChatEvent {
  const AiChatProviderInfo({required this.provider, this.model});
  final String provider;
  final String? model;
}

class AiChatDone extends AiChatEvent {
  const AiChatDone();
}

class AiChatError extends AiChatEvent {
  const AiChatError(this.message);
  final String message;
}

/// Gemini + Farvixo `/api/ai/chat` SSE with multi-turn context.
class AiService {
  AiService() {
    _dio = Dio(
      BaseOptions(
        // Web CORS failures should fail fast so Gemini/mock can take over.
        connectTimeout: Duration(seconds: kIsWeb ? 8 : 20),
        receiveTimeout: const Duration(minutes: 2),
        validateStatus: (s) => s != null && s < 600,
      ),
    );
  }

  late final Dio _dio;

  static const _systemPrompt =
      'You are Farvixo AI Assistant — a helpful, concise product assistant for '
      'Farvixo Tools (PDF, Image, Video, Audio, Developer, SEO, Business tools). '
      'Be practical, friendly, and accurate. Prefer short actionable answers.';

  /// Stream a reply for [history] (including the latest user message).
  /// Prefers Farvixo API SSE, then direct Gemini, then mock.
  ///
  /// Uses `await for` (not bare `yield*`) so connection/CORS failures on
  /// Flutter web reliably fall through instead of killing the chat UI.
  Stream<AiChatEvent> streamChat({
    required List<ChatMessage> history,
    CancelToken? cancelToken,
    bool streaming = true,
  }) async* {
    final usable = history
        .where((m) => m.text.trim().isNotEmpty && !m.isLoading)
        .toList();
    if (usable.isEmpty) {
      yield const AiChatError('Empty message');
      return;
    }

    // 1) Farvixo Tools API (production path — quotas + streaming).
    //    Busy providers (429 / queue full) are retried automatically with
    //    backoff BEFORE falling through, so transient congestion never
    //    surfaces as an error bubble.
    const retryDelays = [
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    String? backendError; // friendly message when the backend answered but failed
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      var emitted = false;
      try {
        await for (final ev in _streamViaFarvixoApi(
          usable,
          cancelToken: cancelToken,
        )) {
          if (ev is AiChatDelta) emitted = true;
          yield ev;
        }
        return;
      } on _AiBusyException {
        if (cancelToken?.isCancelled ?? false) return;
        if (emitted) {
          // Partial answer already shown — end gracefully, no raw error.
          yield const AiChatDone();
          return;
        }
        if (attempt < retryDelays.length) {
          debugPrint('AiService busy — retry ${attempt + 1} '
              'in ${retryDelays[attempt].inSeconds}s');
          await Future<void>.delayed(retryDelays[attempt]);
          if (cancelToken?.isCancelled ?? false) return;
          continue;
        }
        debugPrint('AiService busy after retries — falling back');
        backendError = _sanitizeAiError('429');
        break;
      } catch (e, st) {
        debugPrint('AiService Farvixo API fallback: $e\n$st');
        if (emitted) {
          yield const AiChatDone();
          return;
        }
        // The backend replied with a real (already sanitized) failure —
        // remember it so we never mask it with the demo response.
        if (e is StateError) backendError = _sanitizeAiError(e.message);
        break;
      }
    }

    // 2) Direct Gemini (dev / when server AI unavailable).
    if (AppConfig.geminiEnabled) {
      try {
        if (streaming) {
          await for (final ev in _streamViaGemini(
            usable,
            cancelToken: cancelToken,
          )) {
            yield ev;
          }
        } else {
          final text =
              await _generateViaGemini(usable, cancelToken: cancelToken);
          yield AiChatDelta(text);
          yield const AiChatDone();
        }
        return;
      } catch (e, st) {
        debugPrint('AiService Gemini fallback: $e\n$st');
        // Keep going to mock so the assistant never hard-fails on web CORS.
      }
    }

    // 3) The backend responded but failed (busy/limit): show the friendly
    //    message with no fake demo answer — the UI offers retry.
    if (backendError != null) {
      yield AiChatError(backendError);
      return;
    }

    // 4) Offline / local demo — only when no live AI is reachable at all.
    await for (final ev in _mockStream(usable.last.text)) {
      yield ev;
    }
  }

  /// One-shot helper (tests / legacy callers).
  Future<String> sendMessage(String prompt) async {
    final buf = StringBuffer();
    await for (final ev in streamChat(
      history: [ChatMessage(role: ChatRole.user, text: prompt)],
    )) {
      if (ev is AiChatDelta) buf.write(ev.text);
      if (ev is AiChatError) return ev.message;
    }
    final out = buf.toString().trim();
    return out.isEmpty ? 'Sorry, empty response received.' : out;
  }

  /// Generate an image via Farvixo `/api/ai/image-generate` (JPEG bytes).
  Future<Uint8List> generateImage({
    required String prompt,
    CancelToken? cancelToken,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      throw AiImageException('Describe the image to generate.');
    }

    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept': 'image/jpeg, image/*, application/json',
    };
    final token = SupabaseService.client?.auth.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _dio.post<List<int>>(
        '${AppConfig.apiBaseUrl}/ai/image-generate',
        data: {'prompt': trimmed},
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s < 600,
        ),
        cancelToken: cancelToken,
      );

      final code = response.statusCode ?? 0;
      if (code == 429) {
        throw AiImageException(
          'Daily image limit reached. Try again tomorrow or upgrade.',
        );
      }
      if (code < 200 || code >= 300) {
        final body = response.data;
        String msg = 'Image generation failed ($code)';
        if (body != null && body.isNotEmpty) {
          try {
            final decoded = jsonDecode(utf8.decode(body));
            if (decoded is Map && decoded['error'] != null) {
              msg = decoded['error'].toString();
            }
          } catch (_) {}
        }
        throw AiImageException(msg);
      }

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw AiImageException('Empty image response from server.');
      }
      return Uint8List.fromList(bytes);
    } on AiImageException {
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw AiImageException('Cancelled');
      }
      throw AiImageException(_friendlyError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Farvixo `/api/ai/chat` SSE
  // ---------------------------------------------------------------------------

  /// Start time of the most recent request — used to pace calls so the
  /// backend's free AI providers (1 queued request per IP) aren't slammed
  /// by back-to-back tool runs.
  static DateTime? _lastRequestAt;

  Future<void> _paceRequests() async {
    const minGap = Duration(milliseconds: 1200);
    final last = _lastRequestAt;
    if (last != null) {
      final gap = DateTime.now().difference(last);
      if (gap < minGap) await Future<void>.delayed(minGap - gap);
    }
    _lastRequestAt = DateTime.now();
  }

  Stream<AiChatEvent> _streamViaFarvixoApi(
    List<ChatMessage> history, {
    CancelToken? cancelToken,
  }) async* {
    await _paceRequests();
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };
    final token =
        SupabaseService.client?.auth.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final messages = [
      for (final m in history.take(40))
        {
          'role': m.role == ChatRole.user ? 'user' : 'assistant',
          'content': m.text,
        },
    ];

    final response = await _dio.post<ResponseBody>(
      '${AppConfig.apiBaseUrl}/ai/chat',
      data: {
        'messages': messages,
        'system': _systemPrompt,
        'temperature': 0.7,
      },
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
      ),
      cancelToken: cancelToken,
    );

    final code = response.statusCode ?? 0;
    if (code == 429) throw const _AiBusyException();
    if (code == 503 || code == 502) {
      throw StateError('AI service unavailable ($code)');
    }
    if (code < 200 || code >= 300) {
      // Try parse JSON error body from stream — often small.
      throw StateError('AI request failed ($code)');
    }

    final stream = response.data?.stream;
    if (stream == null) throw StateError('Empty AI stream');

    yield const AiChatProviderInfo(provider: 'farvixo');

    var sentText = false;
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      var raw = buffer.toString();
      while (true) {
        final idx = raw.indexOf('\n');
        if (idx < 0) break;
        final line = raw.substring(0, idx).trimRight();
        raw = raw.substring(idx + 1);
        if (line.isEmpty) continue;
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload == '[DONE]') {
          yield const AiChatDone();
          return;
        }
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          if (map['error'] != null) {
            // NEVER surface raw provider errors in chat. Busy errors are
            // thrown so the caller retries/falls back; anything else is
            // thrown to trigger the Gemini/demo fallback — unless we were
            // mid-answer, in which case end the message cleanly.
            final err = map['error'].toString();
            if (!sentText) {
              if (_looksBusy(err)) throw const _AiBusyException();
              throw StateError(_sanitizeAiError(err));
            }
            yield const AiChatDone();
            return;
          }
          if (map['provider'] != null) {
            yield AiChatProviderInfo(
              provider: map['provider'].toString(),
              model: map['model']?.toString(),
            );
          }
          final text = map['text'] as String?;
          if (text != null && text.isNotEmpty) {
            sentText = true;
            yield AiChatDelta(text);
          }
        } on _AiBusyException {
          rethrow;
        } on StateError {
          rethrow;
        } catch (_) {
          // ignore malformed SSE lines
        }
      }
      buffer
        ..clear()
        ..write(raw);
    }
    yield const AiChatDone();
  }

  // ---------------------------------------------------------------------------
  // Direct Gemini
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _geminiContents(List<ChatMessage> history) {
    return [
      for (final m in history)
        {
          'role': m.role == ChatRole.user ? 'user' : 'model',
          'parts': [
            {'text': m.text},
          ],
        },
    ];
  }

  Future<String> _generateViaGemini(
    List<ChatMessage> history, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${AppConfig.geminiModel}:generateContent',
      queryParameters: {'key': AppConfig.geminiApiKey},
      data: {
        'systemInstruction': {
          'parts': [
            {'text': _systemPrompt},
          ],
        },
        'contents': _geminiContents(history),
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
      cancelToken: cancelToken,
    );
    if ((response.statusCode ?? 0) >= 400) {
      throw StateError('Gemini error ${response.statusCode}');
    }
    final candidates = response.data?['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw StateError('Sorry, I could not generate a response.');
    }
    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw StateError('Sorry, empty response received.');
    }
    return (parts.first as Map<String, dynamic>)['text'] as String? ??
        'Sorry, empty response received.';
  }

  Stream<AiChatEvent> _streamViaGemini(
    List<ChatMessage> history, {
    CancelToken? cancelToken,
  }) async* {
    yield const AiChatProviderInfo(
      provider: 'gemini',
      model: AppConfig.geminiModel,
    );

    final response = await _dio.post<ResponseBody>(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${AppConfig.geminiModel}:streamGenerateContent',
      queryParameters: {
        'key': AppConfig.geminiApiKey,
        'alt': 'sse',
      },
      data: {
        'systemInstruction': {
          'parts': [
            {'text': _systemPrompt},
          ],
        },
        'contents': _geminiContents(history),
      },
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.stream,
      ),
      cancelToken: cancelToken,
    );

    if ((response.statusCode ?? 0) >= 400) {
      // Fall back to non-stream generate.
      final text = await _generateViaGemini(history, cancelToken: cancelToken);
      yield AiChatDelta(text);
      yield const AiChatDone();
      return;
    }

    final stream = response.data?.stream;
    if (stream == null) {
      final text = await _generateViaGemini(history, cancelToken: cancelToken);
      yield AiChatDelta(text);
      yield const AiChatDone();
      return;
    }

    final buffer = StringBuffer();
    await for (final chunk in stream) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      var raw = buffer.toString();
      while (true) {
        final idx = raw.indexOf('\n');
        if (idx < 0) break;
        final line = raw.substring(0, idx).trimRight();
        raw = raw.substring(idx + 1);
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          final candidates = map['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) continue;
          final content =
              (candidates.first as Map<String, dynamic>)['content']
                  as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts == null || parts.isEmpty) continue;
          final text =
              (parts.first as Map<String, dynamic>)['text'] as String?;
          if (text != null && text.isNotEmpty) {
            yield AiChatDelta(text);
          }
        } catch (_) {}
      }
      buffer
        ..clear()
        ..write(raw);
    }
    yield const AiChatDone();
  }

  // ---------------------------------------------------------------------------
  // Mock
  // ---------------------------------------------------------------------------

  Stream<AiChatEvent> _mockStream(String prompt) async* {
    yield const AiChatProviderInfo(provider: 'demo');
    final reply =
        'This is a demo response — configure GEMINI_API_KEY or use the '
        'Farvixo API (`API_BASE_URL`) for live AI.\n\n'
        'You asked: "$prompt"\n\n'
        'I can help with tools, writing, summarizing, translating, and more '
        'once a key is connected.';
    for (final word in reply.split(' ')) {
      yield AiChatDelta('$word ');
      await Future<void>.delayed(const Duration(milliseconds: 28));
    }
    yield const AiChatDone();
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) return 'Cancelled';
      return 'Network error while contacting the AI service. '
          'Please check your connection and try again.';
    }
    if (e is StateError) return e.message;
    return e.toString();
  }

  // ---------------------------------------------------------------------------
  // Error hygiene — raw provider/server errors must NEVER reach the chat UI.
  // ---------------------------------------------------------------------------

  /// True when an upstream error means "momentarily overloaded" — safe to
  /// retry automatically.
  static bool _looksBusy(String raw) {
    final r = raw.toLowerCase();
    return r.contains('429') ||
        r.contains('queue full') ||
        r.contains('rate limit') ||
        r.contains('too many requests') ||
        r.contains('overloaded') ||
        r.contains('capacity');
  }

  /// Convert any upstream error into a short, human message. Raw JSON,
  /// provider names, IPs and URLs are never shown to the user.
  static String _sanitizeAiError(String raw) {
    final r = raw.toLowerCase();
    if (_looksBusy(raw)) {
      return 'Farvixo AI is a little busy right now. '
          'Please try again in a few seconds.';
    }
    if (r.contains('quota') || r.contains('daily limit')) {
      return 'You have reached today\'s AI limit. '
          'Try again later or upgrade to Pro.';
    }
    final looksRaw = raw.length > 120 ||
        raw.contains('{') ||
        raw.contains('http') ||
        r.contains('provider') ||
        r.contains('deprecation');
    if (looksRaw) {
      return 'The AI service hit a temporary problem. Please try again.';
    }
    return raw;
  }
}
