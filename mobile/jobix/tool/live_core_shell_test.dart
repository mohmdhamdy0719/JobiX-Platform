// Explicit dev-only, read-only data/API smoke test. No credit grants, account
// creation, provider configuration, database writes or policy modifications.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:jobix/core/config/app_config.dart';
import 'package:jobix/features/auth/auth_repository.dart';
import 'package:jobix/features/core_mvp/core_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real isolated-development core bootstrap and credits API reads', () async {
    final config = AppConfig.parse(
      Map<String, String>.from(
        jsonDecode(File('config/dev.local.json').readAsStringSync()) as Map,
      ),
    );
    const project = 'lmouxhbjhtqdtiqijcee';
    if (Platform.environment['JOBIX_RUN_LIVE_CORE'] != project ||
        config.environment != AppEnvironment.dev ||
        config.supabaseUrl.host != '$project.supabase.co') {
      throw StateError(
        'Explicit authorized isolated-development opt-in required',
      );
    }
    final transport = IOClient(_RealHttps().createHttpClient(null));
    final client = SupabaseClient(
      config.supabaseUrl.toString(),
      config.clientKey,
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    var phase = 'confirmed development authentication';
    try {
      final response = await client.auth
          .signInWithPassword(
            email: Platform.environment['JOBIX_DEV_TEST_EMAIL_A']!,
            password: Platform.environment['JOBIX_DEV_TEST_PASSWORD_A']!,
          )
          .timeout(const Duration(seconds: 20));
      if (!sessionIsConfirmed(response.session)) {
        throw StateError('Confirmed authentication required');
      }
      phase = 'existing application account lifecycle';
      final account = await client
          .from('users')
          .select('status')
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      if (account == null) {
        throw StateError('APPLICATION_ACCOUNT_NOT_PROVISIONED');
      }
      if (account['status'] != 'ACTIVE') {
        throw StateError('APPLICATION_ACCOUNT_NOT_ACTIVE');
      }
      final api = SupabaseCoreApi(client, config.appVersion);
      phase = 'authoritative bootstrap';
      for (final locale in ['en', 'ar']) {
        final summary = await api.bootstrap(locale);
        if (summary.profiles.isEmpty || summary.slots.isEmpty) {
          throw StateError('Existing profile or free slot missing');
        }
        stdout.writeln(
          'PASS: $locale bootstrap; real profile/slot and authoritative balance.',
        );
      }
      phase = 'protected balance ownership';
      final wallets = await client
          .from('credit_accounts')
          .select('finalized_balance,reserved_balance,version')
          .timeout(const Duration(seconds: 15));
      if (wallets.length != 1) throw StateError('Wallet RLS ownership failed');
      phase = 'real credit history';
      final history = await api.transactions();
      if (history.items.any((row) => row.containsKey('user_id'))) {
        throw StateError('Unnecessary owner data exposed');
      }
      stdout.writeln(
        'PASS: real owner-only wallet/history reads; no data writes.',
      );
      phase = 'operational startup policy';
      final policy = await client
          .rpc('read_app_policy', params: {'requested_key': 'mobile'})
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      if (policy?['minimum_supported_version'] != '1.0.0' ||
          policy?['recommended_version'] != '1.0.0' ||
          policy?['policy_version'] != '1') {
        throw StateError('Approved policy changed');
      }
      stdout.writeln(
        'PASS: existing approved development startup policy unchanged.',
      );
    } on PostgrestException catch (error) {
      const safeCodes = {
        'PGRST202',
        '42883',
        '42703',
        '42501',
        'P0001',
        '42P01',
      };
      final code = safeCodes.contains(error.code) ? error.code : 'SUPPRESSED';
      const knownFailures = {
        'AUTH_REQUIRED',
        'ACCOUNT_DELETING',
        'SERVICE_UNAVAILABLE',
        'APP_UPDATE_REQUIRED',
        'POLICY_UNAVAILABLE',
        'VALIDATION_FAILED',
      };
      final reason = knownFailures.contains(error.message)
          ? error.message
          : 'SUPPRESSED';
      throw StateError(
        'Protected core check failed at $phase: $code / $reason.',
      );
    } catch (error) {
      if (error is StateError &&
          {
            'APPLICATION_ACCOUNT_NOT_PROVISIONED',
            'APPLICATION_ACCOUNT_NOT_ACTIVE',
          }.contains(error.message)) {
        throw StateError(
          '${error.message}; no backfill or lifecycle change attempted.',
        );
      }
      throw StateError(
        'Protected live core check failed at $phase (${error.runtimeType}); sensitive details suppressed.',
      );
    } finally {
      await client.dispose();
      transport.close();
    }
  });
}

class _RealHttps extends HttpOverrides {}
