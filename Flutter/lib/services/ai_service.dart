import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Gemini-backed AI service with an offline mock fallback so the
/// AI Assistant works before any API key is configured.
class AiService {
  AiService() : _dio = Dio();

  final Dio _dio;

  Future<String> sendMessage(String prompt) async {
    if (!AppConfig.geminiEnabled) {
      return _mockReply(prompt);
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '${AppConfig.geminiModel}:generateContent',
        queryParameters: {'key': AppConfig.geminiApiKey},
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      final candidates = response.data?['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        return 'Sorry, I could not generate a response. Please try again.';
      }
      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        return 'Sorry, I could not generate a response. Please try again.';
      }
      return (parts.first as Map<String, dynamic>)['text'] as String? ??
          'Sorry, empty response received.';
    } on DioException {
      return 'Network error while contacting the AI service. '
          'Please check your connection and try again.';
    }
  }

  Future<String> _mockReply(String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return 'This is a demo response — no Gemini API key is configured yet.\n\n'
        'You asked: "$prompt"\n\n'
        'Add your key via --dart-define=GEMINI_API_KEY=... (or in '
        'lib/config/app_config.dart) to enable real AI answers.';
  }
}
