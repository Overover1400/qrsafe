import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/secure_token_store.dart';
import 'api_exception.dart';

/// Builds the configured [Dio] instance used for every API call.
///
/// Wiring (in order):
/// 1. [BaseOptions] — base URL from [Env], 10s connect / 15s receive timeouts.
/// 2. Auth interceptor — attaches `Authorization: Bearer <jwt>` when the
///    [SecureTokenStore] holds a token.
/// 3. Logging interceptor — debug builds only; logs method, path, status,
///    duration.
/// 4. Error interceptor — maps [DioException]s to typed [ApiException]s.
Dio buildApiClient(SecureTokenStore tokenStore) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(_AuthInterceptor(tokenStore));
  if (kDebugMode) {
    dio.interceptors.add(_LoggingInterceptor());
  }
  dio.interceptors.add(_ErrorInterceptor());

  return dio;
}

/// Runs a Dio [request] and unwraps failures into the typed [ApiException] the
/// [_ErrorInterceptor] stashed on `DioException.error`, so data-layer callers
/// see `AuthException`/`NetworkException`/… directly instead of raw
/// `DioException`s. Wrap every API call in this.
Future<T> mapDioErrors<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (e) {
    final mapped = e.error;
    if (mapped is ApiException) throw mapped;
    throw NetworkException(e.message ?? 'The request failed. Try again.');
  }
}

/// Reads the JWT from secure storage on every request and attaches it as a
/// bearer token. Requests made before a token exists (the first guest call) are
/// simply sent without the header.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenStore);

  final SecureTokenStore _tokenStore;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStore.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Logs request timing in debug builds only. Stores the start time on the
/// request's `extra` map so the response/error handlers can compute duration.
class _LoggingInterceptor extends Interceptor {
  static const _startKey = '_startedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _log(
      response.requestOptions,
      response.statusCode,
      response.requestOptions.extra[_startKey],
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      err.requestOptions,
      err.response?.statusCode,
      err.requestOptions.extra[_startKey],
    );
    handler.next(err);
  }

  void _log(RequestOptions options, int? status, Object? startedAt) {
    final ms = startedAt is DateTime
        ? DateTime.now().difference(startedAt).inMilliseconds
        : null;
    developer.log(
      '${options.method} ${options.path} -> ${status ?? '—'}'
      '${ms != null ? ' (${ms}ms)' : ''}',
      name: 'api',
    );
  }
}

/// Translates Dio failures into the app's typed [ApiException] hierarchy:
/// timeouts/connection errors -> [NetworkException]; 401 -> [AuthException];
/// other 4xx -> [ClientException]; 5xx -> [ServerException].
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      err.copyWith(error: _map(err)),
    );
  }

  ApiException _map(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException('The connection timed out. Try again.');
      case DioExceptionType.connectionError:
        return const NetworkException(
          "Couldn't reach QRSafe. Check your connection.",
        );
      case DioExceptionType.badCertificate:
        return const NetworkException('The server certificate was rejected.');
      case DioExceptionType.cancel:
        return const NetworkException('The request was cancelled.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return _mapResponse(err);
    }
  }

  ApiException _mapResponse(DioException err) {
    final status = err.response?.statusCode;
    final (code, message) = _envelope(err.response?.data);

    if (status == null) {
      return NetworkException(
        message ?? 'Something went wrong. Try again.',
        code: code,
      );
    }
    if (status == 401) {
      return AuthException(
        message ?? 'Your session expired.',
        code: code,
        statusCode: status,
      );
    }
    if (status >= 500) {
      return ServerException(
        message ?? 'The server had a problem. Try again later.',
        code: code,
        statusCode: status,
      );
    }
    return ClientException(
      message ?? 'The request could not be completed.',
      code: code,
      statusCode: status,
    );
  }

  /// Extracts `(code, message)` from the backend error envelope
  /// `{"error": {"code", "message"}}`. Returns nulls when absent/malformed.
  (String?, String?) _envelope(Object? data) {
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      final code = err['code'];
      final message = err['message'];
      return (code is String ? code : null, message is String ? message : null);
    }
    return (null, null);
  }
}
