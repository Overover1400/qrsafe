/// A QRSafe user. For now every user is a guest (email is null until upgrade,
/// which is a later phase). Mirrors the backend `user` object:
/// `{id, email, is_guest, created_at}`.
class User {
  const User({
    required this.id,
    required this.email,
    required this.isGuest,
    required this.createdAt,
  });

  final String id;
  final String? email;
  final bool isGuest;
  final DateTime createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: (json['id'] as String?) ?? '',
    email: json['email'] as String?,
    isGuest: (json['is_guest'] as bool?) ?? true,
    createdAt:
        DateTime.tryParse((json['created_at'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Response from `POST /api/v1/auth/guest` (and `/auth/upgrade`):
/// `{user, token}`. The token's expiry lives in its JWT `exp` claim — there is
/// no separate `expires_at` field — so it is decoded locally where needed.
class AuthResponse {
  const AuthResponse({required this.user, required this.token});

  final User user;
  final String token;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    user: User.fromJson((json['user'] as Map<String, dynamic>?) ?? const {}),
    token: (json['token'] as String?) ?? '',
  );
}
