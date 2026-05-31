import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the guest JWT in the platform keystore/keychain.
///
/// Thin wrapper over [FlutterSecureStorage] so the rest of the app depends on a
/// small, testable surface (and so the storage key lives in one place). The auth
/// interceptor reads the token here on every request; the auth controller writes
/// it after bootstrapping a guest, and Settings' "Clear local data" deletes it.
class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'qrsafe_jwt';

  /// Returns the stored JWT, or `null` if none has been saved.
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  /// Persists [token], replacing any existing value.
  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  /// Removes the stored JWT (used by "Clear local data").
  Future<void> clear() => _storage.delete(key: _tokenKey);
}
