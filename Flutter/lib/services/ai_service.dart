import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
    try {
      await for (final ev in _streamViaFarvixoApi(
        usable,
        cancelToken: cancelToken,
      )) {
        yield ev;
      }
      return;
    } catch (e, st) {
      debugPrint('AiService Farvixo API fallback: $e\n$st');
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

    // 3) Offline / local demo — always available.
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

  Stream<AiChatEvent> _streamViaFarvixoApi(
    List<ChatMessage> history, {
    CancelToken? cancelToken,
  }) async* {
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
    if (code == 429) {
      throw StateError(
        'AI daily limit reached. Upgrade to Pro or try again later.',
      );
    }
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
            yield AiChatError(map['error'].toString());
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
            yield AiChatDelta(text);
          }
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
}
