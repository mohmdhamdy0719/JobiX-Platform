import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/storage/secure_store.dart';
import 'package:jobix/features/auth/secure_session_storage.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  test(
    'session adapter persists, restores, removes, and isolates environments',
    () async {
      final store = MemorySecrets();
      final dev = SecureSessionStorage(store, 'dev');
      final prod = SecureSessionStorage(store, 'prod');
      await dev.initialize();
      expect(await dev.hasAccessToken(), false);
      await dev.persistSession('test-only-session');
      expect(
        await SecureSessionStorage(store, 'dev').accessToken(),
        'test-only-session',
      );
      expect(await prod.accessToken(), isNull);
      await dev.removePersistedSession();
      expect(await dev.hasAccessToken(), false);
    },
  );
  test('PKCE secrets also isolated and removable', () async {
    final store = MemorySecrets();
    final dev = SecurePkceStorage(store, 'dev');
    final prod = SecurePkceStorage(store, 'prod');
    await dev.setItem(key: 'verifier', value: 'test-only');
    expect(await dev.getItem(key: 'verifier'), 'test-only');
    expect(await prod.getItem(key: 'verifier'), isNull);
    await dev.removeItem(key: 'verifier');
    expect(await dev.getItem(key: 'verifier'), isNull);
  });
}
