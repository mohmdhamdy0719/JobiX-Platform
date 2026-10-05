// Opt-in isolated-dev verification: actual Flutter screens, Auth, RPC and
// SQLCipher. Platform links and Keystore are not available in this host test.
// Session storage is memory-only; the profile database is closed/reopened.
// Only configured test actor A is edited; original data is restored.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:jobix/app.dart';
import 'package:jobix/core/config/app_config.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/core/navigation/router.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/core/storage/secure_store.dart';
import 'package:jobix/features/auth/auth_controller.dart';
import 'package:jobix/features/auth/auth_repository.dart';
import 'package:jobix/features/auth/provider_settings.dart';
import 'package:jobix/features/auth/secure_session_storage.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:jobix/features/onboarding/research_context.dart';
import 'package:jobix/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets(
    'live development builder screens and interrupted-save restart',
    (tester) async {
      const project = 'lmouxhbjhtqdtiqijcee';
      final config = AppConfig.parse(
        Map<String, String>.from(
          jsonDecode(File('config/dev.local.json').readAsStringSync()) as Map,
        ),
      );
      if (Platform.environment['JOBIX_RUN_LIVE_CORE'] != project ||
          config.environment != AppEnvironment.dev ||
          config.supabaseUrl.host != '$project.supabase.co') {
        throw StateError('Explicit isolated-development opt-in required');
      }
      configureSqlCipher(
        testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
      );
      final directory = Directory.systemTemp.createTempSync('jobix-live-ui-');
      final key = generateDatabaseKey();
      final store = _SessionStore();
      final storage = SecureSessionStorage(
        store,
        'dev',
        deferRestoration: true,
      );
      final transport = _LiveTransport();
      AppDatabase? database;
      ProviderContainer? container;
      CareerProfile? original;
      final created = <(EntitySection, String)>[];
      var initialized = false;
      var editedText = false;
      var phase = 'initialization';
      late AuthProviderSettings settings;
      SupabaseClient getClient() => Supabase.instance.client;
      Future<CareerProfile> read() =>
          SupabaseProfileApi(getClient()).firstProfile();
      String path() => container!
          .read(routerProvider)
          .routeInformationProvider
          .value
          .uri
          .path;

      Future<void> initialize() async {
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
        await storage.restoreSession(getClient());
        database = AppDatabase(
          encryptedDatabase(File('${directory.path}/profile.db'), key),
        );
        await database!.setting('locale');
      }

      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 200; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (ready()) {
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull);
            return;
          }
        }
        throw StateError('Timed out during $phase');
      }

      Future<void> mount() async {
        container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            databaseProvider.overrideWith((_) async => database!),
            supabaseClientProvider.overrideWith((_) async => getClient()),
            secretStoreProvider.overrideWithValue(store),
            // Real metadata fetched below; only platform link plugin omitted.
            authProviderSettingsProvider.overrideWith((_) async => settings),
            authLinkServiceProvider.overrideWith((_) async {}),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container!,
            child: const JobixApp(),
          ),
        );
        await waitFor(() => path() == '/auth' || path() == '/home');
      }

      Future<void> go(String route, Key ready) async {
        container!.read(routerProvider).go(route);
        await waitFor(() => find.byKey(ready).evaluate().isNotEmpty);
      }

      Future<void> tap(Key key) async {
        final finder = find.byKey(key);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> enter(Key key, String text) async {
        final finder = find.byKey(key);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, text);
        await tester.pump();
      }

      Future<void> add(
        EntitySection section,
        int step,
        Map<String, String> values,
      ) async {
        await tap(Key('add-${section.key}'));
        await waitFor(
          () => find.byKey(const Key('editor-save')).evaluate().isNotEmpty,
        );
        for (final entry in values.entries) {
          await enter(Key('field-${entry.key}'), entry.value);
        }
        if (section == EntitySection.experience && created.isEmpty) {
          final beforeInvalid = (await tester.runAsync(read))!;
          await enter(const Key('field-start_month'), '2024-13');
          await tap(const Key('editor-save'));
          final copy = AppLocalizations.of(
            tester.element(find.byType(Scaffold).first),
          )!;
          expect(find.text(copy.problemMonth), findsOneWidget);
          expect((await tester.runAsync(read))!.version, beforeInvalid.version);
          await enter(const Key('field-start_month'), values['start_month']!);
        }
        await tap(const Key('editor-save'));
        await waitFor(() => path() == '/builder/$step');
        final current = (await tester.runAsync(read))!;
        final oldIds = {
          ...original!.of(section).map((item) => item.id),
          ...created.where((item) => item.$1 == section).map((item) => item.$2),
        };
        final added = current
            .of(section)
            .singleWhere((item) => !oldIds.contains(item.id));
        created.add((section, added.id));
        expect(
          find.byKey(Key('card-${section.key}-${added.id}')),
          findsOneWidget,
        );
      }

      try {
        tester.view.physicalSize = const Size(402, 1100);
        tester.view.devicePixelRatio = 1;
        await tester.binding.setSurfaceSize(const Size(402, 1100));
        await tester.runAsync(() async {
          await initialize();
          final response = await transport.get(
            config.supabaseUrl.resolve('/auth/v1/settings'),
            headers: {'apikey': config.clientKey},
          );
          if (response.statusCode != 200) {
            throw StateError('Auth settings unavailable');
          }
          settings = AuthProviderSettings.parse(jsonDecode(response.body));
          await database!.saveOnboarding(
            const ResearchProgress(
              onboardingDone: true,
              stage: 'student',
              goal: 'unsure',
              location: 'remote',
              help: ['cv'],
            ).encode(),
          );
          await database!.setSetting('locale', 'en');
        });
        await mount();
        phase = 'real login through Flutter UI';
        await go('/auth?mode=login', const Key('auth-submit'));
        await enter(
          const Key('auth-email'),
          Platform.environment['JOBIX_DEV_TEST_EMAIL_A']!,
        );
        await enter(
          const Key('auth-password'),
          Platform.environment['JOBIX_DEV_TEST_PASSWORD_A']!,
        );
        await tap(const Key('auth-submit'));
        await waitFor(() => path() == '/home');
        expect(sessionIsConfirmed(getClient().auth.currentSession), isTrue);
        original = (await tester.runAsync(read))!;
        // A private recovery snapshot survives an unexpected harness exit.
        // No session credentials are stored here; delete it after restoration.
        await tester.runAsync(() async {
          final permissions = await Process.run('chmod', [
            '700',
            directory.path,
          ]);
          if (permissions.exitCode != 0) {
            throw StateError('Private fixture snapshot directory required');
          }
          await File(
            '${directory.path}/original-profile.json',
          ).writeAsString(original!.encode(), flush: true);
        });
        final repeat = (await tester.runAsync(read))!;
        expect(repeat.id, original.id);
        expect(original.slot, 1);
        final rows = await tester.runAsync(
          () => getClient()
              .from('career_profiles')
              .select('id')
              .eq('slot_number', 1),
        );
        expect(rows, hasLength(1));
        stdout.writeln(
          'PASS LIVE UI: confirmed login; one stable Profile #1 across repeated reads.',
        );

        phase = 'personal and summary Continue/Back';
        await go('/builder/1', const Key('resume-en'));
        await tap(const Key('resume-en'));
        await waitFor(
          () =>
              find.byKey(const Key('personal-full_name')).evaluate().isNotEmpty,
        );
        editedText = true;
        await enter(
          const Key('personal-full_name'),
          'Development verification',
        );
        await tap(const Key('builder-continue'));
        await waitFor(() => path() == '/builder/2');
        await waitFor(
          () => find.byKey(const Key('editor-summary')).evaluate().isNotEmpty,
        );
        await enter(
          const Key('editor-summary'),
          'Temporary development verification summary, restored after this test.',
        );
        await tap(const Key('builder-continue'));
        await waitFor(() => path() == '/builder/3');
        await tap(const Key('builder-back'));
        await waitFor(() => path() == '/builder/2');
        await tap(const Key('builder-continue'));
        await waitFor(() => path() == '/builder/3');

        phase = 'live entity Add/Save and multiple entries';
        await add(EntitySection.experience, 3, {
          'job_title': 'Development verification role',
          'company': 'Temporary test entry',
          'start_month': '2024-01',
          'end_month': '2024-12',
          'description':
              'Temporary test description, removed after verification.',
        });
        await add(EntitySection.experience, 3, {
          'job_title': 'Second development verification role',
          'start_month': '2023-01',
        });
        await tap(const Key('builder-continue'));
        await waitFor(() => path() == '/builder/4');
        await add(EntitySection.education, 4, {
          'degree': 'Development verification degree',
          'institution': 'Temporary test institution',
          'field_of_study': 'Verification',
          'start_month': '2020-01',
          'end_month': '2023-12',
        });
        await add(EntitySection.certification, 4, {
          'name': 'Development verification certification',
          'issuer': 'Temporary test issuer',
          'issue_month': '2024-01',
        });
        await add(EntitySection.achievement, 4, {
          'title': 'Development verification achievement',
          'issuer': 'Temporary test issuer',
          'achieved_month': '2024-01',
          'description':
              'Temporary test description, removed after verification.',
        });
        await tap(const Key('builder-continue'));
        await waitFor(() => path() == '/builder/5');
        await add(EntitySection.project, 5, {
          'name': 'Development verification project',
          'role': 'Verification',
          'project_month': '2024-01',
          'description':
              'Temporary test description, removed after verification.',
        });
        final unique = newCommandKey().substring(0, 8);
        await enter(const Key('skill-input'), 'Verification $unique');
        await tap(const Key('skill-add'));
        await waitFor(
          () => find.text('Verification $unique').evaluate().isNotEmpty,
        );
        final withSkill = (await tester.runAsync(read))!;
        created.add((
          EntitySection.skill,
          withSkill
              .of(EntitySection.skill)
              .singleWhere(
                (item) => item.text('name') == 'Verification $unique',
              )
              .id,
        ));
        await tap(const Key('add-language'));
        await waitFor(
          () => find.byKey(const Key('language-name')).evaluate().isNotEmpty,
        );
        await enter(const Key('language-name'), 'Verification $unique');
        await tap(const Key('language-level'));
        await tester.tap(
          find
              .text(
                AppLocalizations.of(
                  tester.element(find.byType(Scaffold).first),
                )!.profBasic,
              )
              .last,
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tap(const Key('language-save'));
        await waitFor(
          () => find.byKey(const Key('language-name')).evaluate().isEmpty,
        );
        await waitFor(
          () =>
              find.textContaining('Verification $unique').evaluate().length >=
              2,
        );
        final withLanguage = (await tester.runAsync(read))!;
        created.add((
          EntitySection.language,
          withLanguage
              .of(EntitySection.language)
              .singleWhere(
                (item) => item.text('name') == 'Verification $unique',
              )
              .id,
        ));
        await tap(const Key('builder-continue'));
        await waitFor(() => path() == '/builder/6');
        stdout.writeln(
          'PASS LIVE UI: six steps; real personal/text and all seven entity-section saves; multiple entries.',
        );

        phase = 'Review Edit and interrupted acknowledgement';
        final experienceId = created.first.$2;
        await tap(Key('review-experience-$experienceId'));
        await waitFor(
          () => find.byKey(const Key('field-company')).evaluate().isNotEmpty,
        );
        await enter(
          const Key('field-company'),
          'Recovered live acknowledgement',
        );
        transport.dropNextMutationAck = true;
        await tap(const Key('editor-save'));
        await waitFor(
          () => find.byKey(const Key('save-issue')).evaluate().isNotEmpty,
        );
        expect(path(), '/career/edit/experience/$experienceId');
        final accepted = (await tester.runAsync(read))!;
        expect(
          accepted
              .of(EntitySection.experience)
              .firstWhere((item) => item.id == experienceId)
              .text('company'),
          'Recovered live acknowledgement',
        );
        await tester.pumpWidget(const SizedBox());
        container!.dispose();
        container = null;
        await tester.runAsync(() async {
          await database!.close();
          database = null;
          await Supabase.instance.dispose();
          initialized = false;
          await initialize();
        });
        await mount();
        expect(sessionIsConfirmed(getClient().auth.currentSession), isTrue);
        await go('/builder/3', const Key('add-experience'));
        await waitFor(
          () => find
              .textContaining('Recovered live acknowledgement')
              .evaluate()
              .isNotEmpty,
        );
        // Recovery replays the same outbox command, not a second mutation.
        await waitFor(
          () =>
              container!.read(firstProfileProvider).valueOrNull?.version ==
              accepted.version,
        );
        final pending = await tester.runAsync(
          () => database!.pendingMutation(
            getClient().auth.currentUser!.id,
            original!.id,
          ),
        );
        expect(pending, isNull);
        final restored = (await tester.runAsync(read))!;
        expect(restored.id, original.id);
        expect(restored.version, accepted.version);
        expect(
          restored.summary,
          'Temporary development verification summary, restored after this test.',
        );
        for (final (section, id) in created) {
          expect(
            restored.of(section).where((item) => item.id == id),
            hasLength(1),
          );
        }
        await go('/builder/6', const Key('review-edit-experience'));
        await tap(Key('review-experience-$experienceId'));
        await waitFor(
          () => find.byKey(const Key('field-company')).evaluate().isNotEmpty,
        );
        await enter(
          const Key('field-company'),
          'Review edit live verification',
        );
        await tap(const Key('editor-save'));
        await waitFor(() => path() == '/builder/6');
        expect(
          find.textContaining('Review edit live verification'),
          findsWidgets,
        );
        stdout.writeln(
          'PASS LIVE UI: SQLCipher close/reopen, SDK session recovery, interrupted live save replayed once; Review/Edit/Save/Review.',
        );

        phase = 'live Delete through Flutter UI';
        await go('/builder/3', const Key('add-experience'));
        final deletedId = created[1].$2;
        await tap(Key('menu-experience-$deletedId'));
        await tester.pumpAndSettle();
        final copy = AppLocalizations.of(
          tester.element(find.byType(Scaffold).first),
        )!;
        await tester.tap(find.text(copy.removeAction).last);
        await tester.pumpAndSettle();
        await tap(const Key('confirm-remove'));
        await waitFor(
          () =>
              find.byKey(Key('card-experience-$deletedId')).evaluate().isEmpty,
        );
        expect(
          (await tester.runAsync(read))!
              .of(EntitySection.experience)
              .where((item) => item.id == deletedId),
          isEmpty,
        );
        created.removeAt(1);
        await go('/career', const Key('career-review'));
        expect((await tester.runAsync(read))!.id, original.id);
        stdout.writeln(
          'PASS LIVE UI: delete confirmation/readback; Career uses the same Profile #1.',
        );
      } catch (_) {
        // Do not forward credentials, SDK responses or profile records.
        fail(
          'Protected live Flutter flow failed during $phase; sensitive details suppressed.',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        container?.dispose();
        transport.dropNextMutationAck = false;
        await tester.runAsync(() async {
          if (initialized &&
              sessionIsConfirmed(getClient().auth.currentSession) &&
              original != null) {
            for (final (section, id) in [...created]) {
              await _mutate(getClient(), await read(), section.key, {
                'id': id,
              }, delete: true);
            }
            if (editedText) {
              await _mutate(getClient(), await read(), 'personal', {
                'personal': original.personal,
                'resume_language': original.resumeLanguage,
              });
              await _mutate(getClient(), await read(), 'summary', {
                'text': original.summary,
              });
            }
            final clean = await read();
            expect(clean.personal, original.personal);
            expect(clean.resumeLanguage, original.resumeLanguage);
            expect(clean.summary, original.summary);
            for (final section in EntitySection.values) {
              expect(
                clean.of(section).map((item) => item.toJson()).toList(),
                original.of(section).map((item) => item.toJson()).toList(),
              );
            }
            stdout.writeln(
              'PASS: temporary live fixtures removed; original test-account data restored.',
            );
            await getClient().auth.signOut(scope: SignOutScope.local);
          }
          await database?.close();
          if (initialized) await Supabase.instance.dispose();
          transport.close();
          store.values.clear();
          directory.deleteSync(recursive: true);
        });
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> _mutate(
  SupabaseClient client,
  CareerProfile profile,
  String section,
  Map<String, Object?> value, {
  bool delete = false,
}) async {
  acknowledgedProfile(
    await client.rpc(
      'profile_mutate',
      params: {
        'command_key': newCommandKey(),
        'requested_profile': profile.id,
        'expected_profile_version': profile.version,
        'mutation': {
          'type': delete ? 'delete_item' : 'upsert_item',
          'section': section,
          'value': value,
        },
      },
    ),
  );
}

class _Network extends HttpOverrides {}

class _LiveTransport extends http.BaseClient {
  final http.Client inner = IOClient(_Network().createHttpClient(null));
  bool dropNextMutationAck = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    if (dropNextMutationAck &&
        request.url.path.endsWith('/rpc/profile_mutate') &&
        response.statusCode == 200) {
      dropNextMutationAck = false;
      await response.stream.drain<void>();
      throw const SocketException('Injected acknowledgement interruption');
    }
    return response;
  }

  @override
  void close() => inner.close();
}

class _SessionStore implements SecretStore {
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
