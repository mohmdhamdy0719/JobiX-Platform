import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/storage/secure_store.dart';

/// Supabase never persists tokens in its default SharedPreferences store.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(
    this.store,
    this.environment, {
    this.deferRestoration = false,
  });
  final SecretStore store;
  final String environment;
  final bool deferRestoration;
  String get key => 'supabase_session_$environment';

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async =>
      !deferRestoration && await store.read(key) != null;
  @override
  Future<String?> accessToken() =>
      deferRestoration ? Future.value(null) : store.read(key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      store.write(key, persistSessionString);
  @override
  Future<void> removePersistedSession() => store.delete(key);

  /// Supabase.initialize launches recovery without awaiting it. Defer its
  /// implicit reads, then restore explicitly before guards or sign-out become
  /// usable. This prevents background recovery resurrecting a logged-out user.
  Future<void> restoreSession(SupabaseClient client) async {
    final snapshot = await store.read(key);
    if (snapshot != null) {
      await client.auth.recoverSession(snapshot);
    }
  }
}

/// Supabase's PKCE adapter also avoids its default SharedPreferences backend.
class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(this.store, this.environment);
  final SecretStore store;
  final String environment;
  String key(String key) => 'pkce_${environment}_$key';

  @override
  Future<String?> getItem({required String key}) => store.read(this.key(key));
  @override
  Future<void> setItem({required String key, required String value}) =>
      store.write(this.key(key), value);
  @override
  Future<void> removeItem({required String key}) => store.delete(this.key(key));
}
