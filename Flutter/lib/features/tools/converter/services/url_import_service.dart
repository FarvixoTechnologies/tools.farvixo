import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../engine/tool_engine.dart';

/// Fetches a remote file (PDF / office / image) for the converter.
/// Public URLs only — no Farvixo proxy required.
class UrlImportService {
  UrlImportService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const maxBytes = 25 * 1024 * 1024; // 25 MB free-tier soft cap

  Future<({String name, Uint8List bytes})> fetch(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      throw const ToolFailure('Enter a file URL.');
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const ToolFailure('URL must start with http:// or https://');
    }

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 20),
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw const ToolFailure('Downloaded file is empty.');
      }
      if (data.length > maxBytes) {
        throw ToolFailure(
          'File is larger than ${maxBytes ~/ (1024 * 1024)} MB. '
          'Upgrade to Pro for larger imports.',
        );
      }
      final name = _fileNameFrom(uri, response.headers.value('content-type'));
      return (name: name, bytes: Uint8List.fromList(data));
    } on DioException catch (e) {
      throw ToolFailure('Could not download file: ${e.message ?? e.type.name}');
    }
  }

  String _fileNameFrom(Uri uri, String? contentType) {
    final pathName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (pathName.contains('.') && pathName.length < 120) return pathName;
    final ext = switch (contentType?.split(';').first.trim()) {
      'application/pdf' => 'pdf',
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'text/plain' => 'txt',
      'text/html' => 'html',
      'text/csv' => 'csv',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
        'docx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
        'xlsx',
      _ => 'pdf',
    };
    return 'import.$ext';
  }
}
