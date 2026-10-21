import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/career_profile/entity_repository.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/entity_fakes.dart';
import 'support/slice_fakes.dart';

void main() {
  configureSqlCipher(
    testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
  );
  late Directory directory;
  late String key;
  late AppDatabase db;
  late FakeProfileApi api;
  late FakeEntityServer server;
  late EntityRepository repository;
  var active = true;

  EntityRepository open() => EntityRepository(
    DraftRepository(db, api, 'user-one', () => active),
    (request) {
      return server.send(request);
    },
  );

  setUp(() {
    directory = Directory.systemTemp.createTempSync('jobix-entity-');
    key = generateDatabaseKey();
    db = AppDatabase(encryptedDatabase(File('${directory.path}/db'), key));
    api = FakeProfileApi();
    server = FakeEntityServer(api);
    active = true;
    repository = open();
  });
  tearDown(() async {
    await db.close();
    directory.deleteSync(recursive: true);
  });

  const experience = ProfileItem(
    id: '7f0f8a52-3c55-4a4e-9a51-0d3b8c1f2a10',
    section: EntitySection.experience,
    values: {
      'job_title': 'Flutter Developer',
      'company': 'Example Co',
      'start_month': '2023-01',
      'is_current': true,
      'description': 'Built and shipped the mobile app end to end.',
    },
  );

  for (final section in EntitySection.values) {
    test('Complete entry cannot become a Draft: ${section.key}', () async {
      final complete = ProfileItem(
        id: 'original-${section.key}',
        section: section,
        values: completeEntryValues[section]!,
      );
      await repository.upsert(api.server, complete);
      final original = api.server.encode();
      final incomplete = complete.copyWith(section.fields.first.name, '');
      await expectLater(
        repository.upsert(api.server, incomplete),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            'VALIDATION_FAILED',
          ),
        ),
      );
      expect(api.server.encode(), original);
      expect(await repository.pending(api.server.id), isNull);
      expect(await repository.savedDrafts(api.server.id, section), isEmpty);

      // A genuine new Draft still reopens and promotes with its same ID.
      final draft = ProfileItem(id: 'new-${section.key}', section: section);
      await repository.saveLocalDraft(api.server.id, draft);
      final reopened = await open().savedDraft(
        api.server.id,
        section,
        draft.id,
      );
      expect(reopened!.isDraft, isTrue);
      expect(api.server.of(section).single.id, complete.id);
      server.loseNextResponse = true;
      await expectLater(
        repository.upsert(
          api.server,
          ProfileItem(
            id: draft.id,
            section: section,
            values: {
              ...completeEntryValues[section]!,
              if (section == EntitySection.skill ||
                  section == EntitySection.language)
                'name': 'Second ${section.key}',
            },
          ),
        ),
        throwsA(isA<SocketException>()),
      );
      final key = (await repository.pending(api.server.id))!.key;
      await open().resume(api.server.id);
      expect(server.requests.last.key, key);
      expect(
        api.server.of(section).map((i) => i.id),
        containsAll([complete.id, draft.id]),
      );
      expect(await repository.savedDrafts(api.server.id, section), isEmpty);
      await expectLater(
        repository.discardSavedDraft(api.server, section, draft.id),
        throwsA(isA<PostgrestException>()),
      );
      expect(api.server.of(section).length, 2);
    });
  }

  test('acknowledged upsert clears the outbox and the editor draft', () async {
    await repository.retainDraft(api.server.id, experience);
    final saved = await repository.upsert(api.server, experience);
    expect(saved.version, 2);
    expect(saved.of(EntitySection.experience).single.complete, true);
    expect(await repository.pending(api.server.id), isNull);
    expect(
      await repository.draft(
        api.server.id,
        EntitySection.experience,
        experience.id,
      ),
      isNull,
    );
    expect(
      await db.cachedProfile('user-one', api.server.id),
      isNotNull,
      reason: 'The acknowledged snapshot is the single read model.',
    );
  });

  test(
    'Volunteer unknown Save survives encrypted restart without credit or duplicate records',
    () async {
      const item = ProfileItem(
        id: '9f0f8a52-3c55-4a4e-9a51-0d3b8c1f2a10',
        section: EntitySection.volunteer,
        values: {
          'organization': 'Community Group',
          'role': 'Volunteer Coordinator',
          'start_month': '2024-01',
          'is_current': true,
          'description': '',
        },
      );
      api.server = CareerProfile(
        id: api.server.id,
        version: api.server.version,
        completeness: 45,
        algorithm: 'core-profile-v2',
      );
      await repository.retainDraft(api.server.id, item);
      expect(
        await repository.unsavedNew(api.server, EntitySection.volunteer),
        isEmpty,
        reason: 'Unsubmitted item fields are held by the open screen only.',
      );
      expect(api.server.count(EntitySection.volunteer), 0);
      server.loseNextResponse = true;
      await expectLater(
        repository.upsert(api.server, item),
        throwsA(isA<SocketException>()),
      );
      final frozen = (await repository.pending(api.server.id))!;
      await repository.discardDraft(api.server.id, item.section, item.id);
      expect((await repository.pending(api.server.id))!.key, frozen.key);
      await db.close();
      db = AppDatabase(encryptedDatabase(File('${directory.path}/db'), key));
      repository = open();
      final acknowledged = (await repository.resume(api.server.id))!;
      expect(server.requests.map((r) => r.key).toSet(), {frozen.key});
      expect(acknowledged.count(EntitySection.volunteer), 1);
      expect(acknowledged.completeCount(EntitySection.volunteer), 0);
      expect(acknowledged.completeness, 45);
      expect(acknowledged.algorithm, 'core-profile-v2');
      final cache = CareerProfile.fromJson(
        jsonDecode((await db.cachedProfile('user-one', acknowledged.id))!),
      );
      expect(
        cache.of(EntitySection.volunteer).single.text('role'),
        'Volunteer Coordinator',
      );
      final deleted = await repository.delete(
        acknowledged,
        item.section,
        item.id,
      );
      expect(deleted.count(EntitySection.volunteer), 0);
      expect(deleted.completeness, 45);
      expect(deleted.algorithm, 'core-profile-v2');
    },
  );

  test('a lost response is retried after restart with the same key', () async {
    server.loseNextResponse = true;
    await expectLater(
      repository.upsert(api.server, experience),
      throwsA(isA<SocketException>()),
    );
    final pending = (await repository.pending(api.server.id))!;
    expect(pending.value['id'], experience.id);
    // Nothing new may start while the first outcome is unknown.
    await expectLater(
      repository.delete(api.server, EntitySection.experience, experience.id),
      throwsA(isA<PendingSaveException>()),
    );
    await db.close();
    db = AppDatabase(encryptedDatabase(File('${directory.path}/db'), key));
    repository = open();
    final resumed = (await repository.resume(api.server.id))!;
    expect(resumed.version, 2);
    expect(resumed.of(EntitySection.experience), hasLength(1));
    expect(server.requests.map((r) => r.key).toSet(), {pending.key});
    expect(await repository.pending(api.server.id), isNull);
  });

  test(
    'a known rejection releases the command and preserves the saved local draft',
    () async {
      await repository.retainDraft(api.server.id, experience);
      server.rejectNext = 'VALIDATION_FAILED';
      await expectLater(
        repository.upsert(api.server, experience),
        throwsA(isA<PostgrestException>()),
      );
      expect(await repository.pending(api.server.id), isNull);
      expect(
        await repository.draft(
          api.server.id,
          EntitySection.experience,
          experience.id,
        ),
        isNotNull,
      );
    },
  );

  test(
    'a stale version surfaces VERSION_CONFLICT and never overwrites',
    () async {
      await repository.upsert(api.server, experience);
      final stale = CareerProfile(
        id: api.server.id,
        version: 1,
        items: api.server.items,
      );
      await expectLater(
        repository.upsert(stale, experience.copyWith('company', 'Other')),
        throwsA(
          isA<PostgrestException>().having(
            rejectionCode,
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      expect(
        api.server.of(EntitySection.experience).single.text('company'),
        'Example Co',
      );
    },
  );

  test('only the exact submitted entity survives an uncertain retry', () async {
    await repository.retainDraft(api.server.id, experience);
    server.loseNextResponse = true;
    await expectLater(
      repository.upsert(api.server, experience),
      throwsA(isA<SocketException>()),
    );
    final edited = experience.copyWith('company', 'Edited later');
    await expectLater(
      repository.retainDraft(api.server.id, edited),
      throwsA(isA<PendingSaveException>()),
    );
    expect(
      await db.sectionDraft(
        'user-one',
        api.server.id,
        'entity:experience:${experience.id}',
      ),
      isNull,
    );
    await repository.resume(api.server.id);
    expect(
      api.server.of(EntitySection.experience).single.text('company'),
      'Example Co',
    );
    expect(
      await repository.draft(
        api.server.id,
        EntitySection.experience,
        experience.id,
      ),
      isNull,
    );
  });

  test('delete removes the item and its local draft', () async {
    final saved = await repository.upsert(api.server, experience);
    await repository.retainDraft(saved.id, experience);
    final after = await repository.delete(
      saved,
      EntitySection.experience,
      experience.id,
    );
    expect(after.of(EntitySection.experience), isEmpty);
    expect(
      await repository.draft(saved.id, EntitySection.experience, experience.id),
      isNull,
    );
  });

  test(
    'unsubmitted new items are not persisted as restartable drafts',
    () async {
      await repository.retainDraft(api.server.id, experience);
      expect(
        await repository.unsavedNew(api.server, EntitySection.experience),
        isEmpty,
      );
      final saved = await repository.upsert(api.server, experience);
      expect(
        await repository.unsavedNew(saved, EntitySection.experience),
        isEmpty,
      );
    },
  );

  test('a signed-out repository cannot write or leave drafts', () async {
    active = false;
    await expectLater(
      repository.retainDraft(api.server.id, experience),
      throwsStateError,
    );
    active = true;
    expect(
      await repository.draft(
        api.server.id,
        EntitySection.experience,
        experience.id,
      ),
      isNull,
    );
  });

  test('draft baselines detect changes and removals made elsewhere', () {
    final base = experience.rebased(2);
    expect(draftConflict(experience, null), DraftConflict.none);
    expect(draftConflict(base, null), DraftConflict.removed);
    expect(draftConflict(base, base), DraftConflict.none);
    expect(draftConflict(base, experience.rebased(3)), DraftConflict.changed);
  });

  test(
    'local Draft reopens without a server query and promotes only on explicit Save',
    () async {
      final partial = ProfileItem(
        id: experience.id,
        section: EntitySection.experience,
        values: const {'job_title': 'Analyst'},
      );
      await repository.saveLocalDraft(api.server.id, partial);
      expect(server.requests, isEmpty);
      expect(api.server.of(EntitySection.experience), isEmpty);
      expect(await repository.pending(api.server.id), isNull);
      repository = open();
      final draft = (await repository.savedDrafts(
        api.server.id,
        EntitySection.experience,
      )).single;
      expect(draft.text('job_title'), 'Analyst');
      expect(draft.isDraft, isTrue);
      expect(draft.problems(), isNotEmpty);
      final completed = await repository.upsert(api.server, experience);
      expect(completed.of(EntitySection.experience).single.id, draft.id);
      expect(completed.of(EntitySection.experience).single.version, 1);
      expect(
        await repository.savedDrafts(api.server.id, EntitySection.experience),
        isEmpty,
      );
    },
  );

  test(
    'legacy uncertain server Draft survives restart with its frozen protocol',
    () async {
      server.loseNextResponse = true;
      final legacy = PendingMutation(
        profileId: api.server.id,
        key: 'legacy-draft-request',
        version: api.server.version,
        type: 'upsert_item',
        section: experience.section.key,
        value: experience.payload(),
        isDraft: true,
      );
      await db.retainPendingMutation(
        'user-one',
        api.server.id,
        legacy.encode(),
      );
      await expectLater(
        repository.resume(api.server.id),
        throwsA(isA<SocketException>()),
      );
      final commandKey = (await repository.pending(api.server.id))!.key;
      expect(server.draftItems[EntitySection.experience], hasLength(1));
      await db.close();
      db = AppDatabase(encryptedDatabase(File('${directory.path}/db'), key));
      repository = open();
      await repository.resume(api.server.id);
      expect(server.requests.last.key, commandKey);
      expect(server.requests.last.isDraft, isTrue);
      expect(server.requests.map((request) => request.key).toSet(), {
        commandKey,
      });
      expect(server.draftItems[EntitySection.experience]!.single.version, 1);
      expect(await repository.pending(api.server.id), isNull);
    },
  );

  test(
    'Draft discard is explicit, idempotent, and cannot remove a Complete row',
    () async {
      await repository.saveLocalDraft(api.server.id, experience);
      await repository.discardDraft(
        api.server.id,
        EntitySection.experience,
        experience.id,
      );
      await repository.discardDraft(
        api.server.id,
        experience.section,
        experience.id,
      );
      expect(server.requests, isEmpty);
      expect(
        await repository.savedDrafts(api.server.id, EntitySection.experience),
        isEmpty,
      );
      await repository.upsert(api.server, experience);
      await expectLater(
        repository.discardSavedDraft(
          api.server,
          EntitySection.experience,
          experience.id,
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(api.server.of(EntitySection.experience), hasLength(1));
      expect(await repository.pending(api.server.id), isNull);
    },
  );

  test(
    'offline complete save is local, does not auto-upload, and is account/profile scoped',
    () async {
      api.offline = true;
      await expectLater(
        repository.upsert(api.server, experience),
        throwsA(isA<LocalDraftSavedException>()),
      );
      expect(server.draftItems, isEmpty);
      expect(server.requests, isEmpty);
      expect(await repository.pending(api.server.id), isNull);
      expect(
        (await repository.savedDrafts(
          api.server.id,
          experience.section,
        )).single.isLocalDraft,
        true,
      );
      final other = EntityRepository(
        DraftRepository(db, api, 'user-two', () => true),
        server.send,
      );
      expect(
        await other.savedDrafts(api.server.id, experience.section),
        isEmpty,
      );
      expect(
        await repository.savedDrafts('another-profile', experience.section),
        isEmpty,
      );
      api.offline = false;
      await repository.parent.load();
      expect(
        server.requests,
        isEmpty,
        reason: 'Reconnection and reads never upload local Drafts.',
      );
      await repository.upsert(api.server, experience);
      expect(server.requests.single.isDraft, false);
      expect(
        await repository.savedDrafts(api.server.id, experience.section),
        isEmpty,
      );
      active = false;
      await expectLater(
        repository.savedDrafts(api.server.id, EntitySection.experience),
        throwsStateError,
      );
    },
  );

  test('legacy pending commands retain their original RPC protocol', () {
    final decoded = PendingMutation.decode(
      jsonEncode({
        'profile': api.server.id,
        'key': 'legacy-command',
        'version': 1,
        'type': 'upsert_item',
        'section': 'experience',
        'value': experience.toJson(),
      }),
    );
    expect(decoded.usesEntrySaveRpc, isFalse);
    expect(PendingMutation.decode(decoded.encode()).usesEntrySaveRpc, isFalse);
  });

  test(
    'canonical client snapshot defensively excludes injected Draft items',
    () {
      final profile = CareerProfile(
        id: api.server.id,
        version: 1,
        items: {
          EntitySection.experience: [
            experience,
            ProfileItem(
              id: 'draft-id',
              section: EntitySection.experience,
              isDraft: true,
              values: experience.values,
            ),
          ],
        },
      );
      expect(profile.of(EntitySection.experience), [experience]);
      expect((profile.toJson()['experiences'] as List), hasLength(1));
    },
  );
}
