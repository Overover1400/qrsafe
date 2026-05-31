import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qrsafe_mobile/core/api/api_exception.dart';
import 'package:qrsafe_mobile/core/api/api_providers.dart';
import 'package:qrsafe_mobile/features/scan/application/scan_controller.dart';
import 'package:qrsafe_mobile/features/scan/data/scan_models.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;

  setUp(() {
    dio = _MockDio();
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('happy path: maps a backend verdict into AsyncData', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/scan/check'),
        statusCode: 200,
        data: {
          'url': 'https://example.com',
          'verdict': 'safe',
          'reasons': <dynamic>[],
          'cached': false,
        },
      ),
    );

    final container = makeContainer();
    final result =
        await container.read(scanControllerProvider.notifier).check('https://example.com');

    expect(result, isNotNull);
    expect(result!.verdict, Verdict.safe);
    final state = container.read(scanControllerProvider);
    expect(state.value?.verdict, Verdict.safe);
    expect(state.hasError, isFalse);
  });

  test('maps backend "malicious" to Verdict.danger', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/scan/check'),
        statusCode: 200,
        data: {
          'url': 'http://evil.example',
          'verdict': 'malicious',
          'reasons': [
            {'code': 'blocklisted_host', 'message': 'host is on the blocklist'},
          ],
          'cached': true,
        },
      ),
    );

    final container = makeContainer();
    final result =
        await container.read(scanControllerProvider.notifier).check('http://evil.example');

    expect(result!.verdict, Verdict.danger);
    expect(result.reasons.single.code, 'blocklisted_host');
  });

  test('401 surfaces as an AuthException error state', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/scan/check'),
        error: const AuthException('Your session expired.'),
      ),
    );

    final container = makeContainer();
    final result =
        await container.read(scanControllerProvider.notifier).check('https://x.com');

    expect(result, isNull);
    final state = container.read(scanControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<AuthException>());
  });

  test('network failure surfaces as a NetworkException error state', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/scan/check'),
        type: DioExceptionType.connectionError,
        error: const NetworkException("Couldn't reach QRSafe."),
      ),
    );

    final container = makeContainer();
    final result =
        await container.read(scanControllerProvider.notifier).check('https://x.com');

    expect(result, isNull);
    final state = container.read(scanControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<NetworkException>());
  });
}
