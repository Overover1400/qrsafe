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

  // upgrade() is intentionally omitted for this phase (email/password upgrade
  // is a later brief).
}
