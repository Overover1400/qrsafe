import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'auth_models.dart';

/// Data-layer client for the auth endpoints. Thin wrapper over [Dio]; error
/// mapping happens in the Dio error interceptor (see `api_client.dart`), so
/// callers get typed `ApiException`s, not raw `DioException`s.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `POST /api/v1/auth/guest` — provisions an anonymous account and returns the
  /// user plus a signed JWT. No auth header required (this is how we get one).
  Future<AuthResponse> createGuest() async {
    final res = await mapDioErrors(
      () => _dio.post<Map<String, dynamic>>('/api/v1/auth/guest'),
    );
    return AuthResponse.fromJson(res.data ?? const {});
  }

  /// `POST /api/v1/auth/google/start` — returns the Google URL to open in a
  /// browser. The current (guest) token goes in the Authorization header, not
  /// in the URL, so the backend can hand her codes to the account she signs
  /// into without the token ever reaching browser history.
  Future<String> googleStartUrl() async {
    final res = await mapDioErrors(
      () => _dio.post<Map<String, dynamic>>('/api/v1/auth/google/start'),
    );
    return (res.data?['auth_url'] as String?) ?? '';
  }
}
