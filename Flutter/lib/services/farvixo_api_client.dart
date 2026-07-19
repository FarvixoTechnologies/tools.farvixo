import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';

/// Result of an authenticated Farvixo Tools API call.
class FarvixoApiResult<T> {
  const FarvixoApiResult._({
    required this.ok,
    this.data,
    this.statusCode,
    this.message,
    this.notConfigured = false,
    this.unauthorized = false,
  });

  final bool ok;
  final T? data;
  final int? statusCode;
  final String? message;
  final bool notConfigured;
  final bool unauthorized;

  factory FarvixoApiResult.success(T data, {int statusCode = 200}) =>
      FarvixoApiResult._(ok: true, data: data, statusCode: statusCode);

  factory FarvixoApiResult.fail({
    required int? statusCode,
    String? message,
    bool notConfigured = false,
    bool unauthorized = false,
  }) =>
      FarvixoApiResult._(
        ok: false,
        statusCode: statusCode,
        message: message,
        notConfigured: notConfigured,
        unauthorized: unauthorized,
      );
}

/// Authenticated HTTP client for tools.farvixo.com `/api/*`.
/// Uses Supabase access token as `Authorization: Bearer`.
class FarvixoApiClient {
  FarvixoApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        headers: {'Accept': 'application/json'},
        validateStatus: (s) => s != null && s < 600,
      ),
    );
  }

  late final Dio _dio;

  String? get _accessToken =>
      SupabaseService.client?.auth.currentSession?.accessToken;

  bool get hasSession => _accessToken != null && _accessToken!.isNotEmpty;

  Future<Options> _authOptions() async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Not signed in');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  FarvixoApiResult<Map<String, dynamic>> _parse(Response<dynamic> res) {
    final code = res.statusCode ?? 0;
    final body = res.data;
    Map<String, dynamic>? map;
    if (body is Map<String, dynamic>) {
      map = body;
    } else if (body is Map) {
      map = Map<String, dynamic>.from(body);
    }

    if (code == 401) {
      return FarvixoApiResult.fail(
        statusCode: code,
        message: map?['error'] as String? ?? 'Unauthorized',
        unauthorized: true,
      );
    }
    if (code == 503) {
      return FarvixoApiResult.fail(
        statusCode: code,
        message: map?['error'] as String? ?? 'Service unavailable',
        notConfigured: true,
      );
    }
    if (code < 200 || code >= 300) {
      return FarvixoApiResult.fail(
        statusCode: code,
        message: map?['error'] as String? ?? 'Request failed ($code)',
      );
    }

    final data = map?['data'];
    if (data is Map<String, dynamic>) {
      return FarvixoApiResult.success(data, statusCode: code);
    }
    if (data is Map) {
      return FarvixoApiResult.success(
        Map<String, dynamic>.from(data),
        statusCode: code,
      );
    }
    // Some routes return raw JSON (export).
    if (map != null) {
      return FarvixoApiResult.success(map, statusCode: code);
    }
    return FarvixoApiResult.fail(
      statusCode: code,
      message: 'Unexpected response',
    );
  }

  Future<FarvixoApiResult<Map<String, dynamic>>> get(String path) async {
    if (!hasSession) {
      return FarvixoApiResult.fail(
        statusCode: 401,
        message: 'Sign in required',
        unauthorized: true,
      );
    }
    try {
      final res = await _dio.get<dynamic>(path, options: await _authOptions());
      return _parse(res);
    } on DioException catch (e) {
      debugPrint('FarvixoApiClient.get($path): $e');
      final code = e.response?.statusCode;
      return FarvixoApiResult.fail(
        statusCode: code,
        message: e.message,
        notConfigured: code == 503,
        unauthorized: code == 401,
      );
    } catch (e) {
      debugPrint('FarvixoApiClient.get($path): $e');
      return FarvixoApiResult.fail(statusCode: null, message: e.toString());
    }
  }

  /// Public GET (no auth) — tool catalog / search.
  Future<FarvixoApiResult<Map<String, dynamic>>> getPublic(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        path,
        queryParameters: query,
      );
      return _parse(res);
    } on DioException catch (e) {
      debugPrint('FarvixoApiClient.getPublic($path): $e');
      final code = e.response?.statusCode;
      return FarvixoApiResult.fail(
        statusCode: code,
        message: e.message,
        notConfigured: code == 503,
        unauthorized: code == 401,
      );
    } catch (e) {
      debugPrint('FarvixoApiClient.getPublic($path): $e');
      return FarvixoApiResult.fail(statusCode: null, message: e.toString());
    }
  }

  Future<FarvixoApiResult<Map<String, dynamic>>> post(
    String path, {
    Object? data,
  }) async {
    return _send('POST', path, data: data);
  }

  Future<FarvixoApiResult<Map<String, dynamic>>> patch(
    String path, {
    Object? data,
  }) async {
    return _send('PATCH', path, data: data);
  }

  Future<FarvixoApiResult<Map<String, dynamic>>> _send(
    String method,
    String path, {
    Object? data,
  }) async {
    if (!hasSession) {
      return FarvixoApiResult.fail(
        statusCode: 401,
        message: 'Sign in required',
        unauthorized: true,
      );
    }
    try {
      final opts = await _authOptions();
      final Response<dynamic> res;
      switch (method) {
        case 'PATCH':
          res = await _dio.patch<dynamic>(path, data: data, options: opts);
        case 'POST':
          res = await _dio.post<dynamic>(path, data: data, options: opts);
        default:
          res = await _dio.get<dynamic>(path, options: opts);
      }
      return _parse(res);
    } on DioException catch (e) {
      debugPrint('FarvixoApiClient.$method($path): $e');
      final code = e.response?.statusCode;
      return FarvixoApiResult.fail(
        statusCode: code,
        message: e.message,
        notConfigured: code == 503,
        unauthorized: code == 401,
      );
    } catch (e) {
      debugPrint('FarvixoApiClient.$method($path): $e');
      return FarvixoApiResult.fail(statusCode: null, message: e.toString());
    }
  }

  /// GET that returns raw response bytes/string (GDPR export download).
  Future<FarvixoApiResult<String>> getRaw(String path) async {
    if (!hasSession) {
      return FarvixoApiResult.fail(
        statusCode: 401,
        message: 'Sign in required',
        unauthorized: true,
      );
    }
    try {
      final res = await _dio.get<dynamic>(
        path,
        options: await _authOptions(),
      );
      final code = res.statusCode ?? 0;
      if (code == 401) {
        return FarvixoApiResult.fail(
          statusCode: code,
          message: 'Unauthorized',
          unauthorized: true,
        );
      }
      if (code == 503) {
        return FarvixoApiResult.fail(
          statusCode: code,
          message: 'Service unavailable',
          notConfigured: true,
        );
      }
      if (code < 200 || code >= 300) {
        return FarvixoApiResult.fail(
          statusCode: code,
          message: 'Request failed ($code)',
        );
      }
      if (res.data is String) {
        return FarvixoApiResult.success(res.data as String, statusCode: code);
      }
      if (res.data is Map || res.data is List) {
        return FarvixoApiResult.success(
          const JsonEncoder.withIndent('  ').convert(res.data),
          statusCode: code,
        );
      }
      return FarvixoApiResult.success(
        res.data?.toString() ?? '',
        statusCode: code,
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      return FarvixoApiResult.fail(
        statusCode: code,
        message: e.message,
        notConfigured: code == 503,
        unauthorized: code == 401,
      );
    }
  }

  /// Probe whether billing Stripe keys are configured (signed-in).
  Future<bool> probeBillingConfigured() async {
    final res = await get('/billing/status');
    if (res.ok && res.data != null) {
      return res.data!['billingConfigured'] == true;
    }
    // 503 without auth config vs billing — treat billing false.
    return false;
  }

  /// Probe whether account export endpoint is reachable for this user.
  Future<bool> probeGdprConfigured() async {
    // Lightweight: hit billing/status proves API+auth; GDPR uses same stack.
    // Prefer HEAD-like via status 401 vs 503 on export with invalid — use status.
    final res = await get('/billing/status');
    if (res.unauthorized) return false;
    if (res.notConfigured) return false;
    return res.ok || (res.statusCode != null && res.statusCode! < 500);
  }
}
