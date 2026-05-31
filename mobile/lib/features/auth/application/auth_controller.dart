import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/secure_token_store.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../data/jwt.dart';

/// Provides the [AuthApi] data client. Consumed only by [AuthController].
final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

/// Bootstraps and exposes the current [User].
///
/// Its `build()` runs once on first read (the splash screen awaits it before
/// routing to /home), so the whole app can treat the user as resolved. Consumed
/// by: the splash/router redirect (to know when auth is ready) and any screen
/// that needs the current user. Re-runnable via [refresh] after the token is
/// cleared in Settings.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, User>(AuthController.new);

class AuthController extends AsyncNotifier<User> {
  SecureTokenStore get _tokenStore => ref.read(secureTokenStoreProvider);
  AuthApi get _authApi => ref.read(authApiProvider);

  @override
  Future<User> build() => _bootstrap();

  /// Resolve a usable session:
  /// 1. If a stored token exists and isn't expired, rebuild the user from its
  ///    claims (no server round-trip).
  /// 2. Otherwise provision a fresh guest and persist the new token.
  Future<User> _bootstrap() async {
    final existing = await _tokenStore.readToken();
    if (existing != null &&
        existing.isNotEmpty &&
        !Jwt.isExpired(existing)) {
      final fromClaims = _userFromToken(existing);
      if (fromClaims != null) return fromClaims;
    }
    return _createGuest();
  }

  Future<User> _createGuest() async {
    final res = await _authApi.createGuest();
    await _tokenStore.writeToken(res.token);
    return res.user;
  }

  /// Reconstructs a minimal [User] from a token's claims (`uid`, `guest`). The
  /// backend includes these in every token, so a valid stored token is enough
  /// to identify the user without re-hitting the server. Returns null if the
  /// token has no usable subject.
  User? _userFromToken(String token) {
    final claims = Jwt.decodeClaims(token);
    final id = claims['uid'];
    if (id is! String || id.isEmpty) return null;
    return User(
      id: id,
      email: null,
      isGuest: (claims['guest'] as bool?) ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Clears the stored token and provisions a brand-new guest. Used by
  /// Settings' "Clear local data". Surfaces loading/error via the [state].
  Future<void> resetGuest() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _tokenStore.clear();
      return _createGuest();
    });
  }
}
