// Explicitly invoked by verify_live_supabase.py, never by ordinary unit tests.
// Real HTTPS/Auth/PostgREST; session storage is memory-only, NOT native evidence.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:jobix/core/config/app_config.dart';
import 'package:jobix/core/storage/secure_store.dart';
import 'package:jobix/features/auth/secure_session_storage.dart';
import 'package:jobix/features/boot/startup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'isolated-dev real Auth and Foundation checks',
    () async {
      final config = AppConfig.parse(
        Map<String, String>.from(
          jsonDecode(await File('config/dev.local.json').readAsString()) as Map,
        ),
      );
      const project = 'lmouxhbjhtqdtiqijcee';
      _check(
        Platform.environment['JOBIX_RUN_LIVE_FOUNDATION'] == project &&
            config.environment == AppEnvironment.dev &&
            config.supabaseUrl.host == '$project.supabase.co',
        'explicit isolated-dev opt-in',
      );
      final secrets = _EphemeralSecrets();
      final storage = SecureSessionStorage(
        secrets,
        'dev',
        deferRestoration: true,
      );
      final clients = <SupabaseClient>[];
      final transports = <_TrackedTransport>[];
      final issuedAccessTokens = <String>{};
      var initialized = false;
      var phase = 'initialization';

      Future<SupabaseClient> initialize() async {
        // Bypass flutter_test's fake-400 HTTP client, without disabling TLS checks.
        final transport = _TrackedTransport(
          IOClient(_RealHttps().createHttpClient(null)),
        );
        transports.add(transport);
        await Supabase.initialize(
          url: config.supabaseUrl.toString(),
          publishableKey: config.clientKey,
          debug: false,
          httpClient: transport,
          authOptions: FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: storage,
            pkceAsyncStorage: SecurePkceStorage(secrets, 'dev'),
          ),
        );
        initialized = true;
        final client = Supabase.instance.client;
        clients.add(client);
        return client;
      }

      try {
        var client = await initialize();
        phase = 'real password sign-in';
        final a = await client.auth.signInWithPassword(
          email: Platform.environment['JOBIX_DEV_TEST_EMAIL_A'],
          password: Platform.environment['JOBIX_DEV_TEST_PASSWORD_A']!,
        );
        _check(a.session != null, phase);
        issuedAccessTokens.add(a.session!.accessToken);
        final aId = a.user!.id;
        // Allow the SDK persistence event to settle, and fail if it never does.
        for (
          var i = 0;
          i < 50 && await secrets.read(storage.key) == null;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        _check(
          await secrets.read(storage.key) != null,
          'SDK session persistence',
        );
        _pass('real Auth sign-in persisted through Foundation session adapter');

        phase = 'authenticated owner isolation';
        final bTransport = _TrackedTransport(
          IOClient(_RealHttps().createHttpClient(null)),
        );
        transports.add(bTransport);
        final bClient = SupabaseClient(
          config.supabaseUrl.toString(),
          config.clientKey,
          httpClient: bTransport,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        clients.add(bClient);
        final b = await bClient.auth.signInWithPassword(
          email: Platform.environment['JOBIX_DEV_TEST_EMAIL_B'],
          password: Platform.environment['JOBIX_DEV_TEST_PASSWORD_B']!,
        );
        final bId = b.user!.id;
        issuedAccessTokens.add(b.session!.accessToken);
        _check(aId != bId, phase);
        final aRows = await client.from('users').select('id');
        final bRows = await bClient.from('users').select('id');
        _check(aRows.length == 1 && aRows.single['id'] == aId, phase);
        _check(bRows.length == 1 && bRows.single['id'] == bId, phase);
        _check(
          (await client.from('users').select('id').eq('id', bId)).isEmpty,
          phase,
        );
        _check(
          (await bClient.from('users').select('id').eq('id', aId)).isEmpty,
          phase,
        );
        await _denied(() async {
          await client.from('app_policies').select();
        });
        await _denied(() async {
          await client
              .from('users')
              .update({'status': 'DELETED'})
              .eq('id', aId);
        });
        await _denied(() async {
          await client.from('users').delete().eq('id', aId);
        });
        await _denied(() async {
          await client.from('users').insert({'id': aId});
        });
        await _denied(() async {
          await client
              .from('app_policies')
              .update({'minimum_supported_version': '0.0.0'})
              .eq('policy_key', 'mobile');
        });
        _pass(
          'two real Auth identities are isolated; raw policy and client writes denied',
        );

        phase = 'safe RPC and live minimum-version guard';
        final row = await client
            .rpc('read_app_policy', params: {'requested_key': 'mobile'})
            .single();
        final keys = row.keys.toSet();
        _check(
          keys.length == 4 &&
              keys.containsAll({
                'policy_key',
                'minimum_supported_version',
                'recommended_version',
                'policy_version',
              }) &&
              row['minimum_supported_version'] == '2.0.0',
          phase,
        );
        final services = _LiveStartup(client, storage);
        _check(
          await startFoundation(services, config.appVersion) ==
              StartupState.updateRequired,
          'approved build version blocked by higher live minimum',
        );
        _check(
          await startFoundation(services, '2.0.0') == StartupState.signedIn,
          'version equal to live minimum allowed',
        );
        final missing = _LiveStartup(
          client,
          storage,
          policyKey: 'nonexistent_foundation_verification_policy',
        );
        var failedClosed = false;
        try {
          await startFoundation(missing, config.appVersion);
        } on StateError {
          failedClosed = true;
        } on PostgrestException catch (error) {
          // The installed SDK recognizes only the older zero-row error text
          // for RPC maybeSingle. A newer server can instead surface HTTP 406.
          // Either explicit failure must block startup, never allow entry.
          if (error.code != 'PGRST116' && error.code != '406') rethrow;
          failedClosed = true;
        }
        _check(failedClosed, 'missing live policy fails closed');
        _pass(
          'safe RPC projection; higher minimum blocks; equal minimum allows; missing policy fails',
        );

        phase = 'SDK restart and immediate sign-out';
        // Refresh and await persistence BEFORE the restart. Once recovery returns,
        // sign out without any intervening HTTP request or settling delay.
        final verifiedUser = await client.auth.getUser();
        _check(verifiedUser.user?.id == aId, 'session accepted by live Auth');
        await client.auth.refreshSession();
        issuedAccessTokens.add(client.auth.currentSession!.accessToken);
        final refreshToken = client.auth.currentSession!.refreshToken!;
        bool latestSessionPersisted(String? snapshot) =>
            snapshot != null &&
            (jsonDecode(snapshot) as Map)['refresh_token'] == refreshToken;
        for (
          var i = 0;
          i < 50 && !latestSessionPersisted(await secrets.read(storage.key));
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        _check(
          latestSessionPersisted(await secrets.read(storage.key)),
          'refreshed real session persisted before restart',
        );
        await Supabase.instance.dispose();
        clients.remove(client);
        initialized = false;
        client = await initialize();
        _check(
          client.auth.currentSession == null,
          'implicit recovery deferred',
        );
        await storage.restoreSession(client);
        _check(
          client.auth.currentSession?.user.id == aId,
          'real session restored',
        );
        _check(
          client.auth.currentSession?.refreshToken == refreshToken,
          'latest real session restored',
        );
        final signedOut = client.auth.onAuthStateChange.firstWhere(
          (event) => event.event == AuthChangeEvent.signedOut,
        );
        await client.auth.signOut(scope: SignOutScope.local);
        await signedOut.timeout(const Duration(seconds: 10));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        _check(client.auth.currentSession == null, 'immediate local sign-out');
        _check(
          await secrets.read(storage.key) == null,
          'persisted session removed',
        );
        _check(
          transports.last.successfulLogouts == 1,
          'live server logout succeeded',
        );
        var refreshRejected = false;
        try {
          await client.auth.refreshSession(refreshToken);
        } on AuthException catch (error) {
          refreshRejected =
              error.statusCode == '400' ||
              error.statusCode == '401' ||
              error.statusCode == '403';
        }
        _check(refreshRejected, 'revoked refresh token rejected by live Auth');
        _check(
          client.auth.currentSession == null,
          'failed refresh cannot resurrect session',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        _check(
          await secrets.read(storage.key) == null,
          'no delayed recovery resurrection',
        );
        _pass(
          'real session restored, refreshed and immediately signed out; refresh revoked',
        );

        await Supabase.instance.dispose();
        clients.remove(client);
        initialized = false;
        client = await initialize();
        await storage.restoreSession(client);
        final rpcBefore = transports.last.policyRequests;
        _check(
          await startFoundation(
                _LiveStartup(client, storage),
                config.appVersion,
              ) ==
              StartupState.signedOut,
          'restart after sign-out stays signed out',
        );
        _check(
          transports.last.policyRequests == rpcBefore,
          'signed-out guard skips policy',
        );
        _pass(
          'restart after sign-out remains signed out without policy access',
        );
      } catch (error) {
        // Never print SDK errors or assertion values containing credentials/PII.
        // Test runner captures zone prints, not the tester process's raw stdout.
        // ignore: avoid_print
        print('LIVE FAIL: $phase (${error.runtimeType})');
        if (error is _LiveFailure) {
          // ignore: avoid_print
          print('LIVE FAIL: ${error.label}');
        }
        throw StateError('Live Foundation check failed during $phase');
      } finally {
        var cleanupFailed = false;
        for (final client in clients) {
          if (client.auth.currentSession != null) {
            try {
              await client.auth.signOut(scope: SignOutScope.local);
            } catch (_) {
              cleanupFailed = true;
            }
          }
        }
        if (initialized) {
          final singleton = Supabase.instance.client;
          await Supabase.instance.dispose();
          clients.remove(singleton);
        }
        for (final client in clients) {
          await client.dispose();
        }
        // Revoke even sessions whose SDK was disposed during the restart, or
        // whose test failed before a replacement SDK could recover the snapshot.
        final cleanupHttp = IOClient(_RealHttps().createHttpClient(null));
        try {
          for (final token in issuedAccessTokens) {
            final response = await cleanupHttp.post(
              config.supabaseUrl.resolve('/auth/v1/logout?scope=local'),
              headers: {
                'apikey': config.clientKey,
                'Authorization': 'Bearer $token',
              },
            );
            if (response.statusCode != 204 &&
                response.statusCode != 401 &&
                response.statusCode != 403) {
              cleanupFailed = true;
            }
          }
        } catch (_) {
          cleanupFailed = true;
        } finally {
          cleanupHttp.close();
        }
        for (final transport in transports) {
          transport.close();
        }
        secrets.values.clear();
        _check(!cleanupFailed, 'test session cleanup');
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}

void _check(bool value, String label) {
  if (!value) throw _LiveFailure(label);
}

class _LiveFailure implements Exception {
  _LiveFailure(this.label);
  final String label;
}

// ignore: avoid_print
void _pass(String label) => print('LIVE PASS: $label');

Future<void> _denied(Future<void> Function() action) async {
  try {
    await action();
  } on PostgrestException catch (error) {
    _check(error.code == '42501', 'database permission denial');
    return;
  }
  throw StateError('Forbidden client operation unexpectedly succeeded');
}

class _EphemeralSecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _LiveStartup implements StartupServices {
  _LiveStartup(this.client, this.storage, {this.policyKey = 'mobile'});
  final SupabaseClient client;
  final SecureSessionStorage storage;
  final String policyKey;
  // Native encrypted database opening is deliberately not claimed by this test.
  @override
  Future<void> openDatabase() async {}
  @override
  Future<void> restoreSession() => storage.restoreSession(client);
  @override
  bool get hasSession => client.auth.currentSession != null;
  @override
  Future<String?> readMinimumVersion() async {
    final row = await client
        .rpc('read_app_policy', params: {'requested_key': policyKey})
        .maybeSingle();
    return row?['minimum_supported_version'] as String?;
  }
}

class _RealHttps extends HttpOverrides {}

class _TrackedTransport extends http.BaseClient {
  _TrackedTransport(this.inner);
  final http.Client inner;
  var successfulLogouts = 0;
  var policyRequests = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/rest/v1/rpc/read_app_policy') policyRequests++;
    final response = await inner.send(request);
    if (request.url.path == '/auth/v1/logout' && response.statusCode == 204) {
      successfulLogouts++;
    }
    return response;
  }

  @override
  void close() => inner.close();
}
