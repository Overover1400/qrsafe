import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qrsafe_mobile/core/api/api_providers.dart';
import 'package:qrsafe_mobile/core/storage/secure_token_store.dart';
import 'package:qrsafe_mobile/features/auth/application/auth_controller.dart';

class _MockDio extends Mock implements Dio {}

class _MockTokenStore extends Mock implements SecureTokenStore {}

/// Builds an (unsigned-for-test) JWT carrying the given claims. Only the payload
/// segment matters — the app never verifies the signature client-side.
String _makeJwt({
  required String uid,
  required DateTime exp,
  bool guest = true,
}) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = seg({'alg': 'HS256', 'typ': 'JWT'});
  final payload = seg({
    'uid': uid,
    'guest': guest,
    'exp': exp.millisecondsSinceEpoch ~/ 1000,
  });
  return '$header.$payload.sig';
}

Response<Map<String, dynamic>> _guestResponse(String token, String userId) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/api/v1/auth/guest'),
    statusCode: 201,
    data: {
      'user': {
        'id': userId,
        'email': null,
        'is_guest': true,
        'created_at': '2026-05-31T00:00:00Z',
      },
      'token': token,
    },
  );
}

void main() {
  late _MockDio dio;
  late _MockTokenStore tokenStore;

  setUp(() {
    dio = _MockDio();
    tokenStore = _MockTokenStore();
    when(() => tokenStore.writeToken(any())).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        secureTokenStoreProvider.overrideWithValue(tokenStore),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('bootstraps a fresh guest when no token is stored', () async {
    when(() => tokenStore.readToken()).thenAnswer((_) async => null);
    final token = _makeJwt(
      uid: 'guest-1',
      exp: DateTime.now().toUtc().add(const Duration(days: 30)),
    );
    when(() => dio.post<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => _guestResponse(token, 'guest-1'));

    final container = makeContainer();
    final user = await container.read(authControllerProvider.future);

    expect(user.id, 'guest-1');
    expect(user.isGuest, isTrue);
    verify(() => tokenStore.writeToken(token)).called(1);
    verify(() => dio.post<Map<String, dynamic>>('/api/v1/auth/guest')).called(1);
  });

  test('reuses a stored, unexpired token without hitting the server', () async {
    final token = _makeJwt(
      uid: 'existing-user',
      exp: DateTime.now().toUtc().add(const Duration(days: 5)),
    );
    when(() => tokenStore.readToken()).thenAnswer((_) async => token);

    final container = makeContainer();
    final user = await container.read(authControllerProvider.future);

    expect(user.id, 'existing-user');
    verifyNever(() => dio.post<Map<String, dynamic>>(any()));
    verifyNever(() => tokenStore.writeToken(any()));
  });

  test('re-bootstraps when the stored token is expired', () async {
    final expired = _makeJwt(
      uid: 'old-user',
      exp: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );
    when(() => tokenStore.readToken()).thenAnswer((_) async => expired);
    final fresh = _makeJwt(
      uid: 'new-user',
      exp: DateTime.now().toUtc().add(const Duration(days: 30)),
    );
    when(() => dio.post<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => _guestResponse(fresh, 'new-user'));

    final container = makeContainer();
    final user = await container.read(authControllerProvider.future);

    expect(user.id, 'new-user');
    verify(() => tokenStore.writeToken(fresh)).called(1);
  });
}
