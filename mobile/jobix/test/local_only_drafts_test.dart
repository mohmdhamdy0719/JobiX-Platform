import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/features/builder/save_feedback.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/career_profile/entity_repository.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:jobix/features/career_profile/text_section_repository.dart';

import 'support/entity_fakes.dart';
import 'support/slice_fakes.dart';

void main() {
  configureSqlCipher(
    testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
  );
  late Directory directory;
  late AppDatabase database;
  late String encryptionKey;
  late FakeProfileApi api;
  late FakeEntityServer server;
  DraftRepository parent([String user = 'account-one']) =>
      DraftRepository(database, api, user, () => true);
  EntityRepository repository([String user = 'account-one']) =>
      EntityRepository(parent(user), server.send);
  Future<void> reopen() async {
    await database.close();
    database = AppDatabase(
      encryptedDatabase(File('${directory.path}/drafts.db'), encryptionKey),
    );
  }

  setUp(() {
    directory = Directory.systemTemp.createTempSync('jobix-local-only-');
    encryptionKey = generateDatabaseKey();
    database = AppDatabase(
      encryptedDatabase(File('${directory.path}/drafts.db'), encryptionKey),
    );
    api = FakeProfileApi();
    server = FakeEntityServer(api);
  });
  tearDown(() async {
    await database.close();
    directory.deleteSync(recursive: true);
  });
  const partial = ProfileItem(
    id: 'local-experience',
    section: EntitySection.experience,
    values: {'job_title': 'Device-only work'},
  );
  final complete = ProfileItem(
    id: partial.id,
    section: partial.section,
    values: completeEntryValues[partial.section]!,
  );

  test(
    'incomplete Save is local across restart, isolated and absent from canonical data',
    () async {
      final original = api.server.encode();
      await repository().saveLocalDraft(api.server.id, partial);
      expect(server.requests, isEmpty);
      expect(await repository().pending(api.server.id), isNull);
      await reopen();
      api.offline = true;
      final local = (await repository().savedDrafts(
        api.server.id,
        partial.section,
      )).single;
      expect(local.isDraft, true);
      expect(local.isLocalDraft, true);
      expect(local.text('job_title'), 'Device-only work');
      expect(
        await repository(
          'another-account',
        ).savedDrafts(api.server.id, partial.section),
        isEmpty,
      );
      expect(
        await repository().savedDrafts('another-profile', partial.section),
        isEmpty,
      );
      expect(
        await repository().savedDrafts(api.server.id, EntitySection.education),
        isEmpty,
      );
      expect(api.server.encode(), original);
      expect(api.server.count(partial.section), 0);
      expect(api.server.encode(), isNot(contains('Device-only work')));
      api.offline = false;
      await parent().load();
      expect(
        server.requests,
        isEmpty,
        reason: 'Reading/reconnecting cannot submit a local Draft.',
      );
    },
  );

  test(
    'Draft eligibility ignores toggles but accepts entered section data',
    () {
      const blankExperience = ProfileItem(
        id: 'blank',
        section: EntitySection.experience,
        values: {'is_current': true},
      );
      const enteredExperience = ProfileItem(
        id: 'entered',
        section: EntitySection.experience,
        values: {'is_current': true, 'job_title': 'Engineer'},
      );
      const blankSkill = ProfileItem(
        id: 'blank-skill',
        section: EntitySection.skill,
        values: {'name': '   '},
      );
      expect(blankExperience.hasMeaningfulInput, isFalse);
      expect(enteredExperience.hasMeaningfulInput, isTrue);
      expect(blankSkill.hasMeaningfulInput, isFalse);
    },
  );

  test(
    'meaningful incomplete Education Draft remains local and incomplete',
    () async {
      const educationDraft = ProfileItem(
        id: 'local-education',
        section: EntitySection.education,
        values: {'degree': 'BSc', 'is_current': true},
      );
      final original = api.server.encode();
      await repository().saveLocalDraft(api.server.id, educationDraft);
      final saved = (await repository().savedDrafts(
        api.server.id,
        EntitySection.education,
      )).single;
      expect(saved.isDraft, isTrue);
      expect(saved.isLocalDraft, isTrue);
      expect(saved.text('degree'), 'BSc');
      expect(server.requests, isEmpty);
      expect(api.server.count(EntitySection.education), 0);
      expect(api.server.completeCount(EntitySection.education), 0);
      expect(api.server.encode(), original);
    },
  );

  test(
    'local Draft promotion waits for server confirmation and uses normal complete-save RPC',
    () async {
      await repository().saveLocalDraft(api.server.id, complete);
      final submitted = Completer<PendingMutation>();
      final acknowledgement = Completer<CareerProfile>();
      final repo = EntityRepository(parent(), (request) {
        submitted.complete(request);
        return acknowledgement.future;
      });
      final saving = repo.upsert(api.server, complete);
      final request = await submitted.future;
      expect(request.isDraft, false);
      expect(request.usesEntrySaveRpc, false);
      expect(
        await database.cachedProfile('account-one', api.server.id),
        isNull,
      );
      expect(
        (await repo.savedDrafts(api.server.id, partial.section)).single.isDraft,
        true,
      );
      expect((await repo.pending(api.server.id))!.key, request.key);
      acknowledgement.complete(await server.send(request));
      final saved = await saving;
      expect(saved.of(partial.section).single.id, partial.id);
      expect(await repo.savedDrafts(saved.id, partial.section), isEmpty);
      expect(await repo.pending(saved.id), isNull);
      expect(
        CareerProfile.fromJson(
          jsonDecode((await database.cachedProfile('account-one', saved.id))!)
              as Map<String, dynamic>,
        ).version,
        saved.version,
      );
    },
  );

  test(
    'offline complete Save creates no mutation or reconciliation requirement',
    () async {
      api.offline = true;
      await expectLater(
        repository().upsert(api.server, complete),
        throwsA(isA<LocalDraftSavedException>()),
      );
      expect(server.requests, isEmpty);
      expect(await repository().pending(api.server.id), isNull);
      expect(
        (await repository().savedDrafts(
          api.server.id,
          partial.section,
        )).single.isDraft,
        true,
      );
      expect(
        await confirmedSaveIssue(
          StateError('read failed'),
          repository(),
          api.server.id,
        ),
        SaveIssue.rejected,
      );
      api.offline = false;
      await parent().load();
      expect(server.requests, isEmpty);
      await repository().upsert(api.server, complete);
      expect(server.requests, hasLength(1));
    },
  );

  test(
    'corrupt local Draft is reported, not disguised as empty or deleted',
    () async {
      await database.retainSection(
        'account-one',
        api.server.id,
        'entry_draft:experience:bad',
        '{corrupt',
      );
      await expectLater(
        repository().savedDrafts(api.server.id, partial.section),
        throwsFormatException,
      );
      expect(
        await database.sectionDraft(
          'account-one',
          api.server.id,
          'entry_draft:experience:bad',
        ),
        '{corrupt',
      );
      expect(server.requests, isEmpty);
    },
  );

  test(
    'HTTP transport offline read keeps acknowledged cache and creates only a local Draft',
    () async {
      await parent().load();
      api.loadError = http.ClientException('synthetic disconnected transport');
      expect((await parent().load()).id, api.server.id);
      await expectLater(
        repository().upsert(api.server, complete),
        throwsA(isA<LocalDraftSavedException>()),
      );
      expect(server.requests, isEmpty);
      expect(await repository().pending(api.server.id), isNull);
      expect(
        (await repository().savedDrafts(
          api.server.id,
          complete.section,
        )).single.isLocalDraft,
        true,
      );
    },
  );

  test(
    'Personal Information offline Save is editable local data, never a server Draft or frozen request',
    () async {
      api.server = const CareerProfile(
        id: 'profile-one',
        version: 4,
        completeness: 45,
        personal: {'full_name': 'Saved name'},
      );
      await parent().load();
      final before = api.server.encode();
      api.offline = true;
      const edit = PersonalDraft(
        profileId: 'profile-one',
        baseVersion: 4,
        personal: {'full_name': 'Local name'},
        resumeLanguage: 'ar',
      );
      await expectLater(
        parent().save(edit),
        throwsA(isA<LocalDraftSavedException>()),
      );
      expect(api.requests, isEmpty);
      expect(api.server.encode(), before);
      expect(api.server.completeness, 45);
      await reopen();
      final local = (await parent().draft(await parent().load()))!;
      expect(local.localOnly, true);
      expect(local.frozen, isNull);
      expect(local.commandKey, isNull);
      expect(local.resumeLanguage, 'ar');
      expect(await parent('another-account').draft(api.server), isNull);
      api.offline = false;
      await parent().load();
      expect(api.requests, isEmpty);
      await parent().save(local);
      expect(api.requests, hasLength(1));
      expect(api.server.personal['full_name'], 'Local name');
      expect(await parent().draft(api.server), isNull);
    },
  );

  test(
    'offline Summary saves locally and never uploads on read or restart',
    () async {
      var mutations = 0;
      TextSectionRepository texts() =>
          TextSectionRepository(parent(), (request) async {
            mutations++;
            return CareerProfile(
              id: api.server.id,
              version: 2,
              summary: request.request!['text'] as String,
            );
          });
      api.offline = true;
      final draft = TextSectionDraft(
        profileId: api.server.id,
        section: 'summary',
        version: 1,
        text: 'My local summary',
      );
      await expectLater(
        texts().save(draft),
        throwsA(isA<LocalDraftSavedException>()),
      );
      expect(mutations, 0);
      await reopen();
      final local = (await texts().load(api.server, 'summary'))!;
      expect(local.localOnly, true);
      expect(local.request, isNull);
      api.offline = false;
      await parent().load();
      expect(mutations, 0);
      await texts().save(local);
      expect(mutations, 1);
      expect(await texts().load(api.server, 'summary'), isNull);
    },
  );
}
