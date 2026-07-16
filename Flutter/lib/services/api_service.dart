import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Dio-based HTTP client for the Farvixo API.
class ApiService {
  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      LogInterceptor(requestBody: false, responseBody: false),
    );
  }

  late final Dio _dio;

  Dio get client => _dio;

  Future<Response<T>> get<T>(String path,
          {Map<String, dynamic>? queryParameters}) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post<T>(path, data: data);
}
