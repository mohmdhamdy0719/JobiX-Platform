// Opt-in isolated-dev round trip for repeatable sections. Only configured test
// actor A is edited; temporary items are deleted again, Credits never change,
// and actor B verifies owner isolation.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:jobix/core/config/app_config.dart';
import 'package:jobix/features/auth/auth_repository.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'isolated-dev section upsert, replay, conflict, delete and isolation',
    () async {
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
      final created = <(EntitySection, String)>[];
      String phase = 'authentication';
      Future<CareerProfile> read() =>
          SupabaseProfileApi(clients.first).firstProfile();
      Future<CareerProfile> mutate(
        CareerProfile profile,
        String type,
        EntitySection section,
        Map<String, Object?> value, {
        String? key,
      }) async => acknowledgedProfile(
        await clients.first.rpc(
          'profile_mutate',
          params: {
            'command_key': key ?? newCommandKey(),
            'requested_profile': profile.id,
            'expected_profile_version': profile.version,
            'mutation': {'type': type, 'section': section.key, 'value': value},
          },
        ),
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
        final original = await read();
        expect(original.slot, 1);
        final credits = await clients.first.rpc('credit_balance');
        final before = original.completeness;

        phase = 'personal via unified mutation';
        final personalAck = acknowledgedProfile(
          await clients.first.rpc(
            'profile_mutate',
            params: {
              'command_key': newCommandKey(),
              'requested_profile': original.id,
              'expected_profile_version': original.version,
              'mutation': {
                'type': 'upsert_item',
                'section': 'personal',
                'value': {
                  'personal': {
                    for (final f in personalFields)
                      f: original.personal[f] ?? '',
                  },
                  'resume_language': original.resumeLanguage,
                },
              },
            },
          ),
        );
        expect(personalAck.personal, original.personal);
        expect(personalAck.completeness, before);
        final afterPersonal = await read();

        phase = 'experience upsert';
        final experience = ProfileItem(
          id: newCommandKey(),
          section: EntitySection.experience,
          values: const {
            'job_title': 'Temporary verification role',
            'company': 'Development check',
            'start_month': '2024-01',
            'is_current': true,
            'description': 'Temporary development verification entry; removed.',
          },
        );
        created.add((EntitySection.experience, experience.id));
        final key = newCommandKey();
        final saved = await mutate(
          afterPersonal,
          'upsert_item',
          EntitySection.experience,
          experience.payload(),
          key: key,
        );
        expect(saved.version, afterPersonal.version + 1);
        final item = saved
            .of(EntitySection.experience)
            .singleWhere((i) => i.id == experience.id);
        expect(item.complete, true);
        expect(item.text('start_month'), '2024-01');

        phase = 'idempotent replay';
        final replay = await mutate(
          afterPersonal,
          'upsert_item',
          EntitySection.experience,
          experience.payload(),
          key: key,
        );
        expect(replay.version, saved.version);

        phase = 'reload readback';
        final reloaded = await read();
        expect(
          reloaded.of(EntitySection.experience).map((i) => i.id),
          contains(experience.id),
        );

        phase = 'stale version';
        Object? conflict;
        try {
          await mutate(
            afterPersonal,
            'upsert_item',
            EntitySection.experience,
            experience.copyWith('company', 'Should not apply').payload(),
          );
        } catch (error) {
          conflict = error;
        }
        expect(
          conflict,
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('VERSION_CONFLICT'),
          ),
        );

        phase = 'validation';
        Object? invalid;
        try {
          await mutate(reloaded, 'upsert_item', EntitySection.project, {
            'id': newCommandKey(),
            'name': 'x',
            'url': 'http://insecure.example',
          });
        } catch (error) {
          invalid = error;
        }
        expect(
          invalid,
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('VALIDATION_FAILED'),
          ),
        );

        phase = 'skill duplicate';
        final skillId = newCommandKey();
        created.add((EntitySection.skill, skillId));
        final withSkill = await mutate(
          reloaded,
          'upsert_item',
          EntitySection.skill,
          {'id': skillId, 'name': 'Temporaryverificationskill'},
        );
        Object? duplicate;
        try {
          await mutate(withSkill, 'upsert_item', EntitySection.skill, {
            'id': newCommandKey(),
            'name': '  temporaryverificationskill ',
          });
        } catch (error) {
          duplicate = error;
        }
        expect(
          duplicate,
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('DUPLICATE_ITEM'),
          ),
        );

        phase = 'cross-owner read';
        final foreign = await clients[1]
            .from('profile_experiences')
            .select('id')
            .eq('id', experience.id);
        expect(foreign, isEmpty);

        phase = 'cleanup delete';
        var current = withSkill;
        for (final (section, id) in [...created]) {
          current = await mutate(current, 'delete_item', section, {'id': id});
          created.remove((section, id));
        }
        final restored = await read();
        expect(
          restored.of(EntitySection.experience).map((i) => i.id),
          isNot(contains(experience.id)),
        );
        expect(
          restored.of(EntitySection.skill).map((i) => i.id),
          isNot(contains(skillId)),
        );
        expect(restored.completeness, before);
        expect(await clients.first.rpc('credit_balance'), credits);
        stdout.writeln(
          'PASS: section upsert/replay/readback, VERSION_CONFLICT, VALIDATION_FAILED, DUPLICATE_ITEM, owner isolation, delete; temporary items removed, completeness and Credits unchanged.',
        );
      } catch (_) {
        throw StateError(
          'Protected live section check failed at $phase; sensitive details suppressed.',
        );
      } finally {
        for (final (section, id) in [...created]) {
          try {
            await mutate(await read(), 'delete_item', section, {'id': id});
          } catch (_) {
            stdout.writeln(
              'ATTENTION: temporary item cleanup requires isolated-dev review; do not retry blindly.',
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
    },
  );
}

class _Network extends HttpOverrides {}
