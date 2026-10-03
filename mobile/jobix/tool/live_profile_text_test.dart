// Opt-in isolated-dev round trip. Only configured test actor A is edited;
// original text is restored, Credits never change, actor B verifies isolation.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:jobix/core/config/app_config.dart';
import 'package:jobix/features/auth/auth_repository.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('isolated-dev text mutation, replay, owner isolation and restoration', () async {
    const project = 'lmouxhbjhtqdtiqijcee';
    final config = AppConfig.parse(
      Map<String, String>.from(
        jsonDecode(File('config/dev.local.json').readAsStringSync()) as Map,
      ),
    );
    if (Platform.environment['JOBIX_RUN_LIVE_CORE'] != project ||
        config.environment != AppEnvironment.dev ||
        config.supabaseUrl.host != '$project.supabase.co') {
      throw StateError('Authorized isolated dev opt-in required');
    }
    final clients = <SupabaseClient>[];
    final transports = <IOClient>[];
    CareerProfile? original;
    String phase = 'authentication';
    bool changed = false;
    Future<CareerProfile> read() =>
        SupabaseProfileApi(clients.first).firstProfile();
    Future<Map<String, dynamic>> mutate(
      CareerProfile profile,
      String section,
      String text,
      String key,
    ) async => Map<String, dynamic>.from(
      await clients.first.rpc(
            'profile_mutate',
            params: {
              'command_key': key,
              'requested_profile': profile.id,
              'expected_profile_version': profile.version,
              'mutation': {
                'type': 'upsert_item',
                'section': section,
                'value': {'text': text},
              },
            },
          )
          as Map,
    );
    try {
      for (final actor in ['A', 'B']) {
        final transport = IOClient(_Network().createHttpClient(null));
        transports.add(transport);
        final client = SupabaseClient(
          config.supabaseUrl.toString(),
          config.clientKey,
          httpClient: transport,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        clients.add(client);
        final session = await client.auth.signInWithPassword(
          email: Platform.environment['JOBIX_DEV_TEST_EMAIL_$actor']!,
          password: Platform.environment['JOBIX_DEV_TEST_PASSWORD_$actor']!,
        );
        if (!sessionIsConfirmed(session.session)) {
          throw StateError('Confirmed authentication required');
        }
      }
      phase = 'canonical read';
      original = await read();
      final credits = await clients.first.rpc('credit_balance');
      phase = 'versioned save';
      final key = newCommandKey();
      changed = true;
      final text = original.summary.isEmpty
          ? 'Temporary development verification draft. This text is not professional profile content.'
          : original.summary;
      final result = await mutate(original, 'summary', text, key);
      final replay = await mutate(original, 'summary', text, key);
      expect(replay, result);
      expect(result['authoritative_version'], original.version + 1);
      final accepted = await read();
      expect(accepted.summary, text);
      phase = 'cross-owner read';
      final foreign = await clients[1]
          .from('profile_summaries')
          .select('text')
          .eq('profile_id', original.id);
      expect(foreign, isEmpty);
      phase = 'target role';
      final role = await mutate(
        accepted,
        'target_role',
        original.targetRole,
        newCommandKey(),
      );
      expect(role['state'], 'SUCCEEDED');
      phase = 'personal compatibility';
      final current = await read();
      final response = await clients.first.rpc(
        'save_personal_information',
        params: {
          'command_key': newCommandKey(),
          'requested_profile': current.id,
          'expected_version': current.version,
          'personal': current.personal,
          'resume_language': current.resumeLanguage,
        },
      );
      expect((response as Map)['summary'], text);
      phase = 'restoration';
      await mutate(await read(), 'summary', original.summary, newCommandKey());
      changed = false;
      expect((await read()).targetRole, original.targetRole);
      expect((await read()).summary, original.summary);
      expect(await clients.first.rpc('credit_balance'), credits);
      stdout.writeln(
        'PASS: real text saves/replay, owner isolation, complete personal acknowledgement; original text restored, Credits unchanged.',
      );
    } catch (_) {
      throw StateError(
        'Protected live text check failed at $phase; sensitive details suppressed.',
      );
    } finally {
      if (changed && original != null) {
        try {
          await mutate(
            await read(),
            'summary',
            original.summary,
            newCommandKey(),
          );
        } catch (_) {
          stdout.writeln(
            'ATTENTION: test-text restoration requires isolated-dev review; do not retry blindly.',
          );
        }
      }
      for (final client in clients) {
        await client.dispose();
      }
      for (final transport in transports) {
        transport.close();
      }
    }
  });
}

class _Network extends HttpOverrides {}
