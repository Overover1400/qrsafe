import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qrsafe_mobile/core/api/api_providers.dart';
import 'package:qrsafe_mobile/core/theme/app_theme.dart';
import 'package:qrsafe_mobile/features/codes/presentation/code_detail_screen.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _env({required bool isDynamic}) => {
  'code': {
    'id': 'id1',
    'type': 'url',
    'payload': {'url': 'https://example.com'},
    'label': 'Original',
    'is_dynamic': isDynamic,
    'created_at': '2026-05-31T00:00:00Z',
    'updated_at': '2026-05-31T00:00:00Z',
  },
  if (isDynamic)
    'dynamic': {
      'slug': 's',
      'destination': 'https://example.com',
      'redirect_url': 'https://api.qrsafe.flemby.com/r/s',
    },
};

Response<Map<String, dynamic>> _resp(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/api/v1/codes/id1'),
      statusCode: 200,
      data: data,
    );

void main() {
  late _MockDio dio;

  setUp(() {
    dio = _MockDio();
    // Analytics call from the scan-count line — keep it from throwing.
    when(() => dio.get<Map<String, dynamic>>('/api/v1/codes/id1/analytics'))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/codes/id1/analytics'),
        statusCode: 200,
        data: {
          'analytics': {
            'code_id': 'id1',
            'total_scans': 0,
            'unique_visitors': 0,
            'daily': const [],
            'top_user_agents': const [],
          },
        },
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CodeDetailScreen(id: 'id1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('static code: no Destination row', (tester) async {
    when(() => dio.get<Map<String, dynamic>>('/api/v1/codes/id1'))
        .thenAnswer((_) async => _resp(_env(isDynamic: false)));

    await pump(tester);
    expect(find.text('Destination'), findsNothing);
    expect(find.text('Original'), findsOneWidget);
  });

  testWidgets('dynamic code: shows Destination with a Change button',
      (tester) async {
    when(() => dio.get<Map<String, dynamic>>('/api/v1/codes/id1'))
        .thenAnswer((_) async => _resp(_env(isDynamic: true)));

    await pump(tester);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('edit label flow calls PATCH with the new label', (tester) async {
    when(() => dio.get<Map<String, dynamic>>('/api/v1/codes/id1'))
        .thenAnswer((_) async => _resp(_env(isDynamic: false)));
    when(() => dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _resp(_env(isDynamic: false)));

    await pump(tester);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final data = verify(
      () => dio.patch<Map<String, dynamic>>(
        '/api/v1/codes/id1',
        data: captureAny(named: 'data'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(data['label'], 'Renamed');
  });

  testWidgets('delete flow confirms then calls DELETE', (tester) async {
    when(() => dio.get<Map<String, dynamic>>('/api/v1/codes/id1'))
        .thenAnswer((_) async => _resp(_env(isDynamic: false)));
    when(() => dio.delete<void>(any())).thenAnswer(
      (_) async => Response<void>(
        requestOptions: RequestOptions(path: '/api/v1/codes/id1'),
        statusCode: 204,
      ),
    );

    await pump(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Delete code?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => dio.delete<void>('/api/v1/codes/id1')).called(1);
  });
}
