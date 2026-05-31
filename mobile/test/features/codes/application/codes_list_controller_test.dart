import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qrsafe_mobile/core/api/api_providers.dart';
import 'package:qrsafe_mobile/features/codes/application/codes_list_controller.dart';
import 'package:qrsafe_mobile/features/codes/data/code_models.dart';
import 'package:qrsafe_mobile/features/generator/data/code_payload.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _env(String id) => {
  'code': {
    'id': id,
    'type': 'text',
    'payload': {'text': 'hi'},
    'label': null,
    'is_dynamic': false,
    'created_at': '2026-05-31T00:00:00Z',
    'updated_at': '2026-05-31T00:00:00Z',
  },
};

Response<Map<String, dynamic>> _listResp(List<String> ids, String? next) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/api/v1/codes'),
    statusCode: 200,
    data: {'codes': ids.map(_env).toList(), 'next_cursor': next},
  );
}

Code _code(String id) => Code(
  id: id,
  type: CodeType.text,
  payload: const {'text': 'hi'},
  label: null,
  isDynamic: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late _MockDio dio;

  setUp(() => dio = _MockDio());

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(c.dispose);
    return c;
  }

  test('initial load fetches the first page', () async {
    when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => _listResp(['a', 'b'], 'next1'));

    final container = makeContainer();
    final page = await container.read(codesListControllerProvider.future);
    expect(page.codes.map((c) => c.id), ['a', 'b']);
    expect(page.hasMore, isTrue);
  });

  test('loadMore appends the next page and updates the cursor', () async {
    final responses = [
      _listResp(['a', 'b'], 'next1'),
      _listResp(['c', 'd'], null),
    ];
    var call = 0;
    when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => responses[call++]);

    final container = makeContainer();
    await container.read(codesListControllerProvider.future);
    await container.read(codesListControllerProvider.notifier).loadMore();

    final page = container.read(codesListControllerProvider).requireValue;
    expect(page.codes.map((c) => c.id), ['a', 'b', 'c', 'd']);
    expect(page.hasMore, isFalse);
  });

  test('loadMore is a no-op when there is no next cursor', () async {
    when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => _listResp(['a'], null));

    final container = makeContainer();
    await container.read(codesListControllerProvider.future);
    await container.read(codesListControllerProvider.notifier).loadMore();

    // Only the initial fetch happened.
    verify(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .called(1);
  });

  test('refresh reloads the first page', () async {
    final responses = [
      _listResp(['a'], 'n'),
      _listResp(['x', 'y'], null),
    ];
    var call = 0;
    when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => responses[call++]);

    final container = makeContainer();
    await container.read(codesListControllerProvider.future);
    await container.read(codesListControllerProvider.notifier).refresh();

    final page = container.read(codesListControllerProvider).requireValue;
    expect(page.codes.map((c) => c.id), ['x', 'y']);
  });

  test('optimistic add prepends, remove deletes by id', () async {
    when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => _listResp(['a', 'b'], null));

    final container = makeContainer();
    await container.read(codesListControllerProvider.future);
    final notifier = container.read(codesListControllerProvider.notifier);

    notifier.optimisticallyAddCode(_code('new'));
    expect(container.read(codesListControllerProvider).requireValue.codes.first.id, 'new');

    notifier.optimisticallyRemoveCode('a');
    final ids =
        container.read(codesListControllerProvider).requireValue.codes.map((c) => c.id);
    expect(ids, ['new', 'b']);
  });
}
