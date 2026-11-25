import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/secure_token_store.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../data/jwt.dart';

/// Provides the [AuthApi] data client. Consumed only by [AuthController].
final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

/// The stream of deep links arriving from outside the app.
///
/// Behind a provider so tests can supply their own: [AppLinks] opens a platform
/// channel the moment it is listened to, which a plain unit test has no binding
/// for.
final signInLinkStreamProvider = Provider<Stream<Uri>>((ref) {
  return AppLinks().uriLinkStream;
});

/// Bootstraps and exposes the current [User].
///
/// Its `build()` runs once on first read (the splash screen awaits it before
/// routing to /home), so the whole app can treat the user as resolved. Consumed
/// by: the splash/router redirect (to know when auth is ready) and any screen
/// that needs the current user. Re-runnable via [resetGuest] after the token is
/// cleared in Settings.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, User>(AuthController.new);

class AuthController extends AsyncNotifier<User> {
  SecureTokenStore get _tokenStore => ref.read(secureTokenStoreProvider);
  AuthApi get _authApi => ref.read(authApiProvider);

  StreamSubscription<Uri>? _linkSubscription;

  @override
  Future<User> build() {
    _listenForSignInLinks();
    return _bootstrap();
  }

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

  /// Reconstructs a minimal [User] from a token's claims. The backend signs
  /// `sub` (the user id), `is_guest` and, once she signs in, `email` — enough
  /// to identify her without a round-trip.
  ///
  /// These names must match the Go `auth.Claims` struct: when they did not,
  /// every launch silently failed to recognise the stored token and made a new
  /// guest, which orphaned the codes saved before.
  User? _userFromToken(String token) {
    final claims = Jwt.decodeClaims(token);
    final id = claims['sub'];
    if (id is! String || id.isEmpty) return null;
    final email = claims['email'];
    return User(
      id: id,
      email: (email is String && email.isNotEmpty) ? email : null,
      isGuest: (claims['is_guest'] as bool?) ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Opens Google's sign-in page in the system browser.
  ///
  /// The rest happens out of the app: Google returns the browser to the API,
  /// which signs her in and hands the token back over the `qrsafe://auth` deep
  /// link that [_listenForSignInLinks] is waiting on. Returns false when the
  /// browser could not be opened at all.
  Future<bool> signInWithGoogle() async {
    final url = await _authApi.googleStartUrl();
    if (url.isEmpty) return false;
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Signs out back to a fresh guest session.
  Future<void> signOut() => resetGuest();

  /// Clears the stored token and provisions a brand-new guest. Used by
  /// Settings' "Clear local data". Surfaces loading/error via the [state].
  Future<void> resetGuest() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _tokenStore.clear();
      return _createGuest();
    });
  }

  /// Watches for the deep link the API sends back after a Google sign-in.
  ///
  /// Both the cold-start link and later ones are covered: `uriLinkStream`
  /// replays the launch URI, so a sign-in that starts the app from scratch is
  /// handled the same as one that resumes it.
  void _listenForSignInLinks() {
    _linkSubscription = ref.read(signInLinkStreamProvider).listen(
      _handleLink,
      onError: (_) {},
    );
    ref.onDispose(() {
      _linkSubscription?.cancel();
      _linkSubscription = null;
    });
  }

  Future<void> _handleLink(Uri uri) async {
    if (uri.scheme != 'qrsafe' || uri.host != 'auth') return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    await applyToken(token);
  }

  /// Stores a token issued elsewhere (the Google flow) and republishes the user
  /// it describes. Ignores a token that cannot be read, so a malformed link
  /// cannot sign her out of a working session.
  Future<void> applyToken(String token) async {
    final user = _userFromToken(token);
    if (user == null || Jwt.isExpired(token)) return;
    await _tokenStore.writeToken(token);
    state = AsyncValue.data(user);
  }
}
