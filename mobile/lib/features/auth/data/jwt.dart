import 'dart:convert';

/// Minimal, dependency-free JWT payload decoding.
///
/// We only ever need to read claims we already trust (our own freshly-issued
/// token) to decide whether to re-bootstrap — we never *verify* the signature
/// client-side, so this deliberately ignores it. The backend is the only party
/// that validates tokens.
class Jwt {
  const Jwt._();

  /// Decodes the JWT payload (the middle segment) into a claims map. Returns an
  /// empty map if the token is malformed.
  static Map<String, dynamic> decodeClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return const {};
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  /// The `exp` claim as a [DateTime] (UTC), or null if absent/unparseable.
  static DateTime? expiry(String token) {
    final exp = decodeClaims(token)['exp'];
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
    }
    return null;
  }

  /// Whether [token] is missing an expiry or already expired as of [now].
  /// A token we can't read an expiry from is treated as expired (re-bootstrap).
  static bool isExpired(String token, {DateTime? now}) {
    final exp = expiry(token);
    if (exp == null) return true;
    return !exp.isAfter((now ?? DateTime.now()).toUtc());
  }
}
