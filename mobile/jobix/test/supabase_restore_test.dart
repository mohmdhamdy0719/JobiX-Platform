import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jobix/features/auth/secure_session_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_storage_test.dart' show MemorySecrets;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real Supabase SDK restores a valid session through secure adapter',
    () async {
      final secrets = MemorySecrets();
      final store = SecureSessionStorage(
        secrets,
        'dev',
        deferRestoration: true,
      );
      final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      const id = '00000000-0000-4000-8000-000000000001';
      String segment(Map<String, Object> payload) => base64Url
          .encode(utf8.encode(jsonEncode(payload)))
          .replaceAll('=', '');
      final accessToken =
          '${segment({'alg': 'HS256', 'typ': 'JWT'})}.'
          '${segment({'sub': id, 'exp': expiry, 'role': 'authenticated'})}.'
          'test-only-signature';
      // Synthetic test data only. No HTTP request, credentials or real account.
      await store.persistSession(
        jsonEncode({
          'access_token': accessToken,
          'refresh_token': 'test-only-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at': expiry,
          'user': {
            'id': id,
            'aud': 'authenticated',
            'app_metadata': <String, Object>{},
            'user_metadata': <String, Object>{},
            'created_at': '2026-10-03T00:00:00Z',
          },
        }),
      );
      await Supabase.initialize(
        url: 'https://dev.example.test',
        publishableKey: 'sb_publishable_test_only',
        debug: false,
        httpClient: _LogoutFixtureClient(),
        authOptions: FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: store,
          pkceAsyncStorage: SecurePkceStorage(secrets, 'dev'),
        ),
      );
      final client = Supabase.instance.client;
      expect(client.auth.currentSession, isNull);
      await store.restoreSession(client);
      expect(client.auth.currentSession?.user.id, id);
      expect(client.auth.currentSession?.isExpired, false);
      final signedOut = client.auth.onAuthStateChange.firstWhere(
        (event) => event.event == AuthChangeEvent.signedOut,
      );
      // Local scope still makes a server logout request; its HTTP transport is a
      // test fixture. Real server logout verification needs a dev project.
      await client.auth.signOut(scope: SignOutScope.local);
      await signedOut;
      await Future<void>.delayed(Duration.zero);
      expect(client.auth.currentSession, isNull);
      expect(await secrets.read(store.key), isNull);
      await Supabase.instance.dispose();
    },
  );
}

class _LogoutFixtureClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'POST' || request.url.path != '/auth/v1/logout') {
      throw StateError('Unexpected network request in secure restoration test');
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
