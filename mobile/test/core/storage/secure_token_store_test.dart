import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qrsafe_mobile/core/storage/secure_token_store.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late SecureTokenStore store;

  setUp(() {
    storage = _MockStorage();
    store = SecureTokenStore(storage: storage);
  });

  test('readToken returns the stored value', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'jwt-123');

    expect(await store.readToken(), 'jwt-123');
    verify(() => storage.read(key: 'qrsafe_jwt')).called(1);
  });

  test('readToken returns null when nothing is stored', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);

    expect(await store.readToken(), isNull);
  });

  test('writeToken persists under the token key', () async {
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});

    await store.writeToken('jwt-abc');

    verify(() => storage.write(key: 'qrsafe_jwt', value: 'jwt-abc')).called(1);
  });

  test('clear deletes the token key', () async {
    when(() => storage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});

    await store.clear();

    verify(() => storage.delete(key: 'qrsafe_jwt')).called(1);
  });
}
