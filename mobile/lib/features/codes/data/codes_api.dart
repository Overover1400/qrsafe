import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../generator/data/code_payload.dart';
import 'code_models.dart';

/// Data-layer client for the `/api/v1/codes` endpoints (+ per-code analytics).
/// The bearer token is attached by the Dio auth interceptor; failures are mapped
/// to typed `ApiException`s via [mapDioErrors].
class CodesApi {
  CodesApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/codes?limit=&cursor=` → one page of the user's codes.
  Future<PaginatedCodes> list({String? cursor, int? limit}) async {
    final res = await mapDioErrors(
      () => _dio.get<Map<String, dynamic>>(
        '/api/v1/codes',
        queryParameters: {
          // Empty cursor → first page (omit it).
          'cursor': ?(cursor != null && cursor.isNotEmpty ? cursor : null),
          'limit': ?limit,
        },
      ),
    );
    return PaginatedCodes.fromJson(res.data ?? const {});
  }

  /// `GET /api/v1/codes/{id}` → one code.
  Future<Code> get(String id) async {
    final res = await mapDioErrors(
      () => _dio.get<Map<String, dynamic>>('/api/v1/codes/$id'),
    );
    return Code.fromEnvelope(res.data ?? const {});
  }

  /// `POST /api/v1/codes` → create a static or dynamic code.
  Future<Code> create({
    required CodeType type,
    required Map<String, dynamic> payload,
    String? label,
    bool isDynamic = false,
  }) async {
    final effectiveLabel = (label != null && label.isNotEmpty) ? label : null;
    final res = await mapDioErrors(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/codes',
        data: {
          'type': type.wire,
          'payload': payload,
          'label': ?effectiveLabel,
          'is_dynamic': isDynamic,
        },
      ),
    );
    return Code.fromEnvelope(res.data ?? const {});
  }

  /// `PATCH /api/v1/codes/{id}` → update the label and/or (dynamic) destination.
  Future<Code> update(
    String id, {
    String? label,
    String? destination,
  }) async {
    final res = await mapDioErrors(
      () => _dio.patch<Map<String, dynamic>>(
        '/api/v1/codes/$id',
        data: {
          'label': ?label,
          'destination': ?destination,
        },
      ),
    );
    return Code.fromEnvelope(res.data ?? const {});
  }

  /// `DELETE /api/v1/codes/{id}`.
  Future<void> delete(String id) async {
    await mapDioErrors(() => _dio.delete<void>('/api/v1/codes/$id'));
  }

  /// `GET /api/v1/codes/{id}/analytics` → all-time scan stats for one code.
  Future<CodeAnalytics> analytics(String id) async {
    final res = await mapDioErrors(
      () => _dio.get<Map<String, dynamic>>('/api/v1/codes/$id/analytics'),
    );
    return CodeAnalytics.fromEnvelope(res.data ?? const {});
  }
}
