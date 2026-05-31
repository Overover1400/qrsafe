import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_token_store.dart';
import 'api_client.dart';

/// Provides the singleton [SecureTokenStore].
///
/// Consumed by: the Dio auth interceptor (via [dioProvider]), the auth
/// controller (writes the bootstrapped token), and Settings (clears it).
/// Overridden in tests with a fake store.
final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return SecureTokenStore();
});

/// Provides the configured [Dio] client (auth + logging + error interceptors).
///
/// Consumed by: every data-layer API class (`AuthApi`, `ScanApi`).
/// Overridden in tests with a Dio whose `HttpClientAdapter` is mocked.
final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(secureTokenStoreProvider);
  return buildApiClient(tokenStore);
});
