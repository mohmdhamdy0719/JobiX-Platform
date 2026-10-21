import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/core/navigation/router.dart';
import 'package:jobix/core/navigation/back_policy.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/features/auth/auth_repository.dart';
import 'package:jobix/features/boot/startup.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/onboarding/onboarding_controller.dart';
import 'package:jobix/features/onboarding/research_context.dart';
import 'package:jobix/features/personal_information/personal_information_validator.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/slice_fakes.dart';

void main() {
  test('Account Information Back returns to Settings', () {
    expect(backDestination(Uri.parse('/settings/account')), '/settings');
  });
  configureSqlCipher(
    testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
  );
  late Directory directory;
  late AppDatabase db;
  late FakeProfileApi api;
  late DraftRepository repository;
  late String key;
  var active = true;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('jobix-slice-');
    key = generateDatabaseKey();
    db = AppDatabase(
      encryptedDatabase(File('${directory.path}/store.db'), key),
    );
    api = FakeProfileApi();
    active = true;
    repository = DraftRepository(db, api, 'user-one', () => active);
  });
  tearDown(() async {
    await db.close();
    directory.deleteSync(recursive: true);
  });
  test(
    'stale research cannot overwrite another account or a newer anonymous snapshot',
    () async {
      const original = ResearchProgress(onboardingDone: true, stage: 'student');
      const replacement = ResearchProgress(
        onboardingDone: true,
        stage: 'working',
      );
      await db.saveOnboarding(original.encode());
      await db.setSetting('research_owner', 'user-two');
      expect(
        await db.writeOwnedResearch(
          'user-one',
          original.encode(),
          original.copy(mergedUser: 'user-one').encode(),
          () => true,
        ),
        false,
      );
      expect(await db.onboarding(), original.encode());
      await db.removeSetting('research_owner');
      await db.saveOnboarding(replacement.encode());
      expect(
        await db.writeOwnedResearch(
          'user-one',
          original.encode(),
          original.copy(mergedUser: 'user-one').encode(),
          () => true,
        ),
        false,
      );
      expect(await db.onboarding(), replacement.encode());
    },
  );
  test(
    'research ownership and its durable command are written atomically for the current account',
    () async {
      const original = ResearchProgress(onboardingDone: true, stage: 'student');
      await db.saveOnboarding(original.encode());
      final pending = original.copy(commandKey: 'command-one');
      expect(
        await db.writeOwnedResearch(
          'user-one',
          original.encode(),
          pending.encode(),
          () => false,
        ),
        false,
      );
      expect(await db.setting('research_owner'), isNull);
      expect(
        await db.writeOwnedResearch(
          'user-one',
          original.encode(),
          pending.encode(),
          () => true,
        ),
        true,
      );
      expect(await db.setting('research_owner'), 'user-one');
      expect(await db.onboarding(), pending.encode());
    },
  );
  test(
    'non-network failures never fall back to acknowledged Profile data',
    () async {
      await repository.load();
      api.loadError = const FormatException('Malformed response fixture');
      await expectLater(repository.load(), throwsFormatException);
      api.loadError = const PostgrestException(
        message: 'FORBIDDEN',
        code: '42501',
      );
      await expectLater(repository.load(), throwsA(isA<PostgrestException>()));
      api.loadError = const SocketException('Offline fixture');
      await expectLater(
        repository.load(freshOnly: true),
        throwsA(isA<SocketException>()),
      );
      expect((await repository.load()).id, api.server.id);
    },
  );

  test(
    'v1 -> v4 upgrades real encrypted storage without losing settings',
    () async {
      await db.close();
      final file = File('${directory.path}/v1.db');
      final old = sqlite3.open(file.path);
      unlockDatabase(old, key);
      old.execute(
        'CREATE TABLE infrastructure_metadata (key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL)',
      );
      old.execute(
        'CREATE TABLE local_settings (key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL)',
      );
      old.execute("INSERT INTO local_settings VALUES ('locale','ar')");
      old.execute("INSERT INTO infrastructure_metadata VALUES ('schema','1')");
      old.execute('PRAGMA user_version=1');
      old.dispose();
      db = AppDatabase(encryptedDatabase(file, key));
      expect(await db.setting('locale'), 'ar');
      await db.saveOnboarding(
        const ResearchProgress(onboardingDone: true).encode(),
      );
      expect(
        (await db.select(db.infrastructureMetadata).getSingle()).value,
        '4',
      );
    },
  );
  test(
    'research survives restart and resumes first unanswered ordered question',
    () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((_) async => db)],
      );
      var progress = await container.read(researchProvider.future);
      progress = progress
          .copy(done: true)
          .select(0, 'graduate')
          .select(1, 'unsure');
      await container.read(researchProvider.notifier).persist(progress);
      container.dispose();
      await db.close();
      db = AppDatabase(
        encryptedDatabase(File('${directory.path}/store.db'), key),
      );
      final restart = ProviderContainer(
        overrides: [databaseProvider.overrideWith((_) async => db)],
      );
      expect((await restart.read(researchProvider.future)).question, 2);
      expect((await restart.read(researchProvider.future)).goal, 'unsure');
      restart.dispose();
    },
  );
  test(
    'first-launch completion matches durable answers and survives account wipe',
    () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((_) async => db)],
      );
      addTearDown(container.dispose);
      await container.read(researchProvider.future);
      final progress = const ResearchProgress(onboardingDone: true)
          .select(0, 'graduate')
          .select(1, 'unsure')
          .select(2, 'remote')
          .select(3, 'cv');
      await container.read(researchProvider.notifier).persist(progress);
      await container.read(researchProvider.notifier).finishFirstLaunch();
      final completed = await container.read(researchProvider.future);
      expect(await db.onboarding(), completed.encode());
      await db.setSetting('registration_user', 'user-one');
      await db.setSetting('extras:user-one:profile', 'private');
      await db.setSetting('resume:user-one:profile', 'private');
      await db.clearAccount('user-one');
      expect(await db.onboarding(), isNull);
      expect(await db.setting('extras:user-one:profile'), isNull);
      expect(await db.setting('resume:user-one:profile'), isNull);
      container.invalidate(researchProvider);
      final restored = await container.read(researchProvider.future);
      expect(restored.firstLaunchComplete, isTrue);
      expect(restored.onboardingDone, isTrue);
      expect(restored.complete, isFalse);
    },
  );
  test('Q4 never exceeds three and allows deselection and replacement', () {
    var progress = const ResearchProgress();
    for (final choice in ['cv', 'skills', 'online', 'paths']) {
      progress = progress.select(3, choice);
    }
    expect(progress.help, ['cv', 'skills', 'online']);
    progress = progress.select(3, 'skills').select(3, 'paths');
    expect(progress.help, ['cv', 'online', 'paths']);
  });
  test(
    'singleton onboarding updates never create a second integer-key row',
    () async {
      await db.saveOnboarding(const ResearchProgress().encode());
      await db.saveOnboarding(
        const ResearchProgress(onboardingPage: 1).encode(),
      );
      await db.saveOnboarding(
        const ResearchProgress(onboardingDone: true).encode(),
      );
      expect((await db.select(db.localOnboarding).get()).length, 1);
      expect(
        ResearchProgress.decode(await db.onboarding()).onboardingDone,
        true,
      );
    },
  );
  test(
    'blank incomplete fields are saveable; malformed provided values are not',
    () {
      for (final f in personalFields) {
        expect(validatePersonalField(f, ''), isNull);
      }
      expect(validatePersonalField('email', 'broken'), 'email');
      expect(validatePersonalField('phone', 'active phone'), 'phone');
      expect(validatePersonalField('phone', '+20 100 123 4567'), isNull);
      expect(
        validatePersonalField('portfolio_url', 'javascript:alert(1)'),
        'link',
      );
      expect(
        validatePersonalField('portfolio_url', 'https://example.com'),
        isNull,
      );
    },
  );
  test('email confirmation and provider identity are guarded', () {
    expect(sessionIsConfirmed(null), false);
    expect(sessionIsConfirmed(testSession(confirmed: false)), false);
    expect(sessionIsConfirmed(testSession()), true);
    expect(
      sessionIsConfirmed(testSession(confirmed: false, provider: 'google')),
      true,
    );
    expect(
      validAuthCallback(
        Uri.parse('com.mhflow.jobix://auth/callback?code=test'),
      ),
      true,
    );
    expect(
      validAuthCallback(Uri.parse('https://example.com/auth?code=test')),
      false,
    );
    expect(
      validAuthCallback(
        Uri.parse('com.mhflow.jobix://evil/callback?code=test'),
      ),
      false,
    );
  });
  test(
    'Home first on returning launch; new signup goes directly to builder Step 1',
    () {
      String? guard({
        required String path,
        bool newEntry = false,
        bool recovery = false,
      }) => sliceRedirect(
        startup: StartupState.signedIn,
        path: path,
        progress: null,
        firstEntry: newEntry,
        entryLoading: false,
        recovery: recovery,
      );
      expect(guard(path: '/boot'), '/home');
      expect(guard(path: '/boot', newEntry: true), '/builder/1');
      expect(guard(path: '/builder/1'), isNull);
      expect(guard(path: '/builder/6'), isNull);
      expect(guard(path: '/builder/7'), '/home');
      expect(guard(path: '/career/personal'), isNull);
      expect(guard(path: '/settings/account'), isNull);
      expect(guard(path: '/career/edit/experience/new'), isNull);
      expect(guard(path: '/home'), isNull);
      expect(guard(path: '/home', recovery: true), '/recovery');
    },
  );
  test(
    'first-time Auth, login query, confirmation and reset cannot bypass any research question',
    () {
      var progress = const ResearchProgress();
      for (var answered = 0; answered <= 4; answered++) {
        for (final path in [
          '/auth',
          '/forgot',
          '/confirm',
          '/career/personal',
          '/builder/1',
          '/career/edit/skill/new',
        ]) {
          expect(
            sliceRedirect(
              startup: StartupState.signedOut,
              path: path,
              progress: progress,
              firstEntry: false,
              entryLoading: false,
              recovery: false,
            ),
            answered == 0 ? '/onboarding' : '/research',
          );
        }
        progress = switch (answered) {
          0 => progress.copy(done: true),
          1 => progress.select(0, 'student'),
          2 => progress.select(1, 'unsure'),
          3 => progress.select(2, 'remote'),
          _ => progress.select(3, 'cv'),
        };
      }
      expect(progress.complete, true);
      expect(
        sliceRedirect(
          startup: StartupState.signedOut,
          path: '/auth',
          progress: progress,
          firstEntry: false,
          entryLoading: false,
          recovery: false,
        ),
        isNull,
      );
    },
  );
  test(
    'onboarding skip never skips research or exposes a guarded Career screen',
    () {
      final skipped = const ResearchProgress(onboardingDone: true);
      expect(
        sliceRedirect(
          startup: StartupState.signedOut,
          path: '/boot',
          progress: skipped,
          firstEntry: false,
          entryLoading: false,
          recovery: false,
        ),
        '/research',
      );
      expect(
        sliceRedirect(
          startup: StartupState.signedOut,
          path: '/career/personal',
          progress: skipped,
          firstEntry: false,
          entryLoading: false,
          recovery: false,
        ),
        '/research',
      );
      expect(
        sliceRedirect(
          startup: StartupState.updateRequired,
          path: '/home',
          progress: skipped,
          firstEntry: false,
          entryLoading: false,
          recovery: false,
        ),
        '/update-required',
      );
    },
  );
  test(
    'unsubmitted edits are not persisted across encrypted restart',
    () async {
      await repository.retain(
        const PersonalDraft(
          profileId: 'profile-one',
          baseVersion: 1,
          personal: {'full_name': 'Unfinished العربية'},
          resumeLanguage: 'ar',
        ),
      );
      expect(await db.draftFor('user-one', 'profile-one'), isNull);
      await db.close();
      db = AppDatabase(
        encryptedDatabase(File('${directory.path}/store.db'), key),
      );
      repository = DraftRepository(db, api, 'user-one', () => active);
      final loaded = await repository.load(freshOnly: true);
      expect(loaded.personal['full_name'], isNot('Unfinished العربية'));
      expect(await db.draftFor('other-user', 'profile-one'), isNull);
    },
  );
  test(
    'Discard removes only local draft, leaving acknowledged server and cache untouched',
    () async {
      await repository.load();
      await repository.retain(
        const PersonalDraft(
          profileId: 'profile-one',
          baseVersion: 1,
          personal: {'full_name': 'Unsaved'},
        ),
      );
      await repository.discard('profile-one');
      expect(await repository.draft(api.server), isNull);
      expect(await db.cachedProfile('user-one', 'profile-one'), isNotNull);
      expect(api.server.version, 1);
      expect(api.requests, isEmpty);
    },
  );
  test(
    'incomplete explicit save is acknowledged once and clears local draft',
    () async {
      final result = await repository.save(
        const PersonalDraft(
          profileId: 'profile-one',
          baseVersion: 1,
          personal: {'full_name': '  Native User  '},
          resumeLanguage: 'ar',
        ),
      );
      expect(result.version, 2);
      expect(result.personal['email'], '');
      expect(result.resumeLanguage, 'ar');
      expect(await repository.draft(result), isNull);
    },
  );
  test(
    'offline save is local with no mutation identity; explicit online Save succeeds',
    () async {
      api.offline = true;
      const draft = PersonalDraft(
        profileId: 'profile-one',
        baseVersion: 1,
        personal: {'full_name': 'Offline'},
      );
      await expectLater(
        repository.save(draft),
        throwsA(isA<LocalDraftSavedException>()),
      );
      final pending = (await repository.draft(api.server))!;
      expect(pending.commandKey, isNull);
      expect(pending.frozen, isNull);
      expect(pending.localOnly, true);
      expect(api.requests, isEmpty);
      expect(api.server.personal, isEmpty);
      api.offline = false;
      await repository.load();
      expect(api.requests, isEmpty);
      final saved = await repository.save(pending);
      expect(saved.version, 2);
      expect(api.requests.map((r) => r.commandKey).toSet().length, 1);
    },
  );
  test(
    'uncertain save retry reuses the frozen request and drops no cloud write',
    () async {
      api.loseNextResponse = true;
      const draft = PersonalDraft(
        profileId: 'profile-one',
        baseVersion: 1,
        personal: {'full_name': 'Original'},
      );
      await expectLater(
        repository.save(draft),
        throwsA(isA<SocketException>()),
      );
      var pending = (await repository.draft(api.server))!;
      final command = pending.commandKey;
      pending = pending.edit('full_name', 'Edited after uncertainty');
      await repository.retain(pending);
      final frozenRequest = (await repository.draft(api.server))!;
      expect(frozenRequest.personal['full_name'], 'Original');
      expect(frozenRequest.frozen!['personal']['full_name'], 'Original');
      final saved = await repository.save(pending);
      expect(saved.version, 2);
      expect(saved.personal['full_name'], 'Original');
      expect(await repository.draft(saved), isNull);
      expect(api.requests.last.commandKey, command);
      expect(api.requests.last.personal['full_name'], 'Original');
    },
  );
  test(
    'a known version conflict preserves editable local state without overwriting server',
    () async {
      api.server = const CareerProfile(
        id: 'profile-one',
        version: 2,
        personal: {'full_name': 'Other device'},
      );
      await expectLater(
        repository.save(
          const PersonalDraft(
            profileId: 'profile-one',
            baseVersion: 1,
            personal: {'full_name': 'My work'},
          ),
        ),
        throwsA(isA<PostgrestException>()),
      );
      final local = (await repository.draft(api.server))!;
      expect(local.localOnly, true);
      expect(local.frozen, isNull);
      expect(local.personal['full_name'], 'My work');
      expect(api.server.personal['full_name'], 'Other device');
    },
  );
  test(
    'sign-out isolation prevents an in-flight local write reappearing',
    () async {
      active = false;
      await expectLater(
        repository.retain(
          const PersonalDraft(
            profileId: 'profile-one',
            baseVersion: 1,
            personal: {},
          ),
        ),
        throwsStateError,
      );
      expect(await db.draftFor('user-one', 'profile-one'), isNull);
    },
  );
  test(
    'account cleanup preserves app language, removes owned context/history/drafts',
    () async {
      await db.setSetting('locale', 'ar');
      await db.setSetting('research_owner', 'user-one');
      await db.setSetting('cities_user-one', 'Manual city');
      await db.saveOnboarding(const ResearchProgress().encode());
      await repository.retain(
        const PersonalDraft(
          profileId: 'profile-one',
          baseVersion: 1,
          personal: {},
        ),
      );
      await db.clearAccount('user-one');
      expect(await db.setting('locale'), 'ar');
      expect(await db.onboarding(), isNull);
      expect(await db.setting('cities_user-one'), isNull);
      expect(await db.draftFor('user-one', 'profile-one'), isNull);
    },
  );
}
