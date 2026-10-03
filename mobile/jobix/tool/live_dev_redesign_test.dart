// Explicit dev-only smoke test. Real HTTPS/Auth/RPC; memory-only token adapter.
// Does not modify policy, profiles, signup settings or passwords.
// NOT a native Keystore, Samsung-device, mail-delivery or Google-OAuth test.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:jobix/core/config/app_config.dart';
import 'package:jobix/core/storage/secure_store.dart';
import 'package:jobix/features/auth/auth_repository.dart';
import 'package:jobix/features/auth/provider_settings.dart';
import 'package:jobix/features/auth/secure_session_storage.dart';
import 'package:jobix/features/boot/startup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'owner-approved dev policy: real signed-out and restored authenticated startup',
    () async {
      final config = AppConfig.parse(
        Map<String, String>.from(
          jsonDecode(File('config/dev.local.json').readAsStringSync()) as Map,
        ),
      );
      const project = 'lmouxhbjhtqdtiqijcee';
      if (Platform.environment['JOBIX_RUN_LIVE_REDESIGN'] != project ||
          config.environment != AppEnvironment.dev ||
          config.supabaseUrl.host != '$project.supabase.co') {
        throw StateError('Explicit authorized isolated-dev opt-in required');
      }
      final store = _EphemeralStore();
      final storage = SecureSessionStorage(
        store,
        'dev',
        deferRestoration: true,
      );
      final transport = IOClient(_RealHttps().createHttpClient(null));
      final transports = <IOClient>[transport];
      SupabaseClient? restored;
      var initialized = false;
      var phase = 'public provider settings';
      try {
        final settings = await transport
            .get(
              config.supabaseUrl.resolve('/auth/v1/settings'),
              headers: {'apikey': config.clientKey},
            )
            .timeout(const Duration(seconds: 20));
        if (settings.statusCode != 200) {
          throw StateError('Public settings unavailable');
        }
        final providers = AuthProviderSettings.parse(jsonDecode(settings.body));
        stdout.writeln(
          'PASS: real development Auth settings; Google enabled=${providers.googleEnabled}.',
        );
        phase = 'signed-out SDK initialization';
        await Supabase.initialize(
          url: config.supabaseUrl.toString(),
          publishableKey: config.clientKey,
          debug: false,
          httpClient: transport,
          authOptions: FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: storage,
            pkceAsyncStorage: SecurePkceStorage(store, 'dev'),
          ),
        );
        initialized = true;
        final client = Supabase.instance.client;
        final signedOut = _Services(client, storage);
        if (await startFoundation(signedOut, config.appVersion) !=
                StartupState.signedOut ||
            signedOut.policyReads != 0) {
          throw StateError('Signed-out guard failed');
        }
        stdout.writeln(
          'PASS: signed-out startup; no unauthorized policy request.',
        );
        phase = 'real confirmed email/password sign-in';
        await SupabaseAuthApi(client)
            .signIn(
              Platform.environment['JOBIX_DEV_TEST_EMAIL_A']!,
              Platform.environment['JOBIX_DEV_TEST_PASSWORD_A']!,
            )
            .timeout(const Duration(seconds: 20));
        for (var i = 0; i < 50 && await store.read(storage.key) == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        if (await store.read(storage.key) == null) {
          throw StateError('Adapter persistence unavailable');
        }
        phase =
            'deferred secure-adapter recovery and authenticated policy guard';
        final nextTransport = IOClient(_RealHttps().createHttpClient(null));
        transports.add(nextTransport);
        restored = SupabaseClient(
          config.supabaseUrl.toString(),
          config.clientKey,
          httpClient: nextTransport,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        // Same recovery barrier used by runtime providers, not a direct-token bypass.
        final recovered = _Services(restored, storage);
        if (await startFoundation(recovered, config.appVersion) !=
                StartupState.signedIn ||
            recovered.policyReads != 1) {
          throw StateError('Authenticated startup guard failed');
        }
        final row = await restored
            .rpc('read_app_policy', params: {'requested_key': 'mobile'})
            .maybeSingle();
        if (row?['minimum_supported_version'] != '1.0.0' ||
            row?['recommended_version'] != '1.0.0' ||
            row?['policy_version'] != '1') {
          throw StateError('Approved operational development policy differs');
        }
        stdout.writeln(
          'PASS: confirmed sign-in, persisted/recovered SDK session, guarded signed-in startup.',
        );
        stdout.writeln(
          'PASS: authenticated RPC returns approved dev policy 1.0.0 / 1.0.0 / 1.',
        );
        phase = 'policy table write/read protection';
        var denied = false;
        try {
          await restored.from('app_policies').select();
        } on PostgrestException {
          denied = true;
        }
        if (!denied) {
          throw StateError('Direct policy-table access unexpectedly allowed');
        }
        stdout.writeln(
          'PASS: direct client policy-table access remains denied.',
        );
      } catch (_) {
        // Never forward SDK exception bodies, tokens, email or provider details.
        fail(
          'Protected live dev check failed during $phase; sensitive details suppressed.',
        );
      } finally {
        if (restored?.auth.currentSession != null) {
          await restored!.auth.signOut(scope: SignOutScope.local);
        } else if (initialized &&
            Supabase.instance.client.auth.currentSession != null) {
          await Supabase.instance.client.auth.signOut(
            scope: SignOutScope.local,
          );
        }
        if (restored != null) await restored.dispose();
        if (initialized) await Supabase.instance.dispose();
        store.values.clear();
        for (final client in transports) {
          client.close();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealHttps extends HttpOverrides {}

class _EphemeralStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _Services implements StartupServices {
  _Services(this.client, this.storage);
  final SupabaseClient client;
  final SecureSessionStorage storage;
  var policyReads = 0;
  // Storage adapter is memory-only in this explicitly labelled service test.
  @override
  Future<void> openDatabase() async {}
  @override
  Future<void> restoreSession() => storage.restoreSession(client);
  @override
  bool get hasSession => sessionIsConfirmed(client.auth.currentSession);
  @override
  Future<String?> readMinimumVersion() async {
    policyReads++;
    final row = await client
        .rpc('read_app_policy', params: {'requested_key': 'mobile'})
        .maybeSingle();
    return row?['minimum_supported_version'] as String?;
  }
}
