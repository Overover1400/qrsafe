/// Typed errors surfaced by the API layer.
///
/// The Dio error interceptor ([buildApiClient]) maps transport/status failures
/// into these so callers can branch on a meaningful type instead of inspecting
/// raw [DioException]s. The backend's error envelope is
/// `{"error": {"code", "message"}}`; [code]/[message] carry those through when
/// present.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});

  /// Human-readable message (from the server envelope, or a sensible default).
  final String message;

  /// Stable server error code (e.g. `invalid_request`), when the body had one.
  final String? code;

  /// HTTP status code, when the failure reached the server.
  final int? statusCode;

  @override
  String toString() => '$runtimeType($statusCode, $code): $message';
}

/// 401 — the token is missing, invalid, or expired. The app should re-bootstrap
/// a guest.
class AuthException extends ApiException {
  const AuthException(super.message, {super.code, super.statusCode = 401});
}

/// 4xx (other than 401) — a client error carrying the server's code/message.
class ClientException extends ApiException {
  const ClientException(super.message, {super.code, super.statusCode});
}

/// 5xx — the server failed to handle an otherwise valid request.
class ServerException extends ApiException {
  const ServerException(super.message, {super.code, super.statusCode});
}

/// Timeouts, DNS failures, no connectivity — the request never got a response.
class NetworkException extends ApiException {
  const NetworkException(super.message, {super.code});
}
