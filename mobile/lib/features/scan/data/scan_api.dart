import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'scan_models.dart';

/// Data-layer client for the safety-check endpoint. The bearer token is added
/// automatically by the Dio auth interceptor; error mapping to typed
/// `ApiException`s also happens in the interceptor.
class ScanApi {
  ScanApi(this._dio);

  final Dio _dio;

  /// `POST /api/v1/scan/check` with `{url}` → a [ScanResult]. The server returns
  /// 200 even for malicious URLs (the verdict *is* the result), so any thrown
  /// error here is a real transport/auth/server failure.
  Future<ScanResult> check(String url) async {
    final res = await mapDioErrors(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/scan/check',
        data: {'url': url},
      ),
    );
    return ScanResult.fromJson(res.data ?? const {});
  }
}
