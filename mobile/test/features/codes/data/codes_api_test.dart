import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qrsafe_mobile/core/api/api_exception.dart';
import 'package:qrsafe_mobile/features/codes/data/codes_api.dart';
import 'package:qrsafe_mobile/features/generator/data/code_payload.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _envelope(String id, {bool dynamic = false}) => {
  'code': {
    'id': id,
    'type': 'url',
    'payload': {'url': 'https://example.com'},
    'label': 'L',
    'is_dynamic': dynamic,
    'created_at': '2026-05-31T00:00:00Z',
    'updated_at': '2026-05-31T00:00:00Z',
  },
  if (dynamic)
    'dynamic': {
      'slug': 'abc123',
      'destination': 'https://example.com',
      'redirect_url': 'https://api.qrsafe.flemby.com/r/abc123',
    },
};

void main() {
  late _MockDio dio;
  late CodesApi api;

  setUp(() {
    dio = _MockDio();
    api = CodesApi(dio);
  });

  test('list parses codes and a present next_cursor', () async {
    when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/codes'),
        statusCode: 200,
        data: {
          'codes': [_envelope('a'), _envelope('b', dynamic: true)],
          'next_cursor': 'cursor-xyz',
        },
      ),
    );

    final page = await api.list(limit: 20);
    expect(page.codes, hasLength(2));
    expect(page.codes[1].isDynamic, isTrue);
    expect(page.codes[1].dynamicInfo?.slug, 'abc123');
    expect(page.nextCursor, 'cursor-xyz');
    expect(page.hasMore, isTrue);
  });

  test('list treats null next_cursor as no more pages', () async {
    when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/codes'),
        statusCode: 200,
        data: {'codes': [_envelope('a')], 'next_cursor': null},
      ),
    );

    final page = await api.list();
    expect(page.hasMore, isFalse);
  });

  test('list forwards cursor and limit query params', () async {
    when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/codes'),
        statusCode: 200,
        data: {'codes': const [], 'next_cursor': null},
      ),
    );

    await api.list(cursor: 'c1', limit: 5);
    final params = verify(
      () => dio.get<Map<String, dynamic>>(
        '/api/v1/codes',
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(params['cursor'], 'c1');
    expect(params['limit'], 5);
  });

  test('error mapping surfaces typed ApiException', () async {
    when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/codes'),
        error: const AuthException('expired'),
      ),
    );

    expect(() => api.list(), throwsA(isA<AuthException>()));
  });

  test('create posts type/payload/is_dynamic and parses the result', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/codes'),
        statusCode: 201,
        data: _envelope('made', dynamic: true),
      ),
    );

    final code = await api.create(
      type: CodeType.url,
      payload: {'url': 'https://example.com'},
      label: 'L',
      isDynamic: true,
    );
    expect(code.id, 'made');
    expect(code.dynamicInfo?.redirectUrl, contains('/r/abc123'));
  });

  test('delete issues a DELETE for the id', () async {
    when(() => dio.delete<void>(any())).thenAnswer(
      (_) async => Response<void>(
        requestOptions: RequestOptions(path: '/api/v1/codes/x'),
        statusCode: 204,
      ),
    );

    await api.delete('x');
    verify(() => dio.delete<void>('/api/v1/codes/x')).called(1);
  });
}
