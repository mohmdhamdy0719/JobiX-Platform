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

  test('a known rejection releases the command but keeps the draft', () async {
    await repository.retainDraft(api.server.id, experience);
    server.rejectNext = 'VALIDATION_FAILED';
    await expectLater(
      repository.upsert(api.server, experience),
      throwsA(isA<PostgrestException>()),
    );
    expect(await repository.pending(api.server.id), isNull);
    expect(
      (await repository.draft(
        api.server.id,
        EntitySection.experience,
        experience.id,
      ))!.text('company'),
      'Example Co',
    );
  });

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

  test('edits made after the request froze survive acknowledgement', () async {
    await repository.retainDraft(api.server.id, experience);
    server.loseNextResponse = true;
    await expectLater(
      repository.upsert(api.server, experience),
      throwsA(isA<SocketException>()),
    );
    final edited = experience.copyWith('company', 'Edited later');
    await repository.retainDraft(api.server.id, edited);
    await repository.resume(api.server.id);
    final kept = (await repository.draft(
      api.server.id,
      EntitySection.experience,
      experience.id,
    ))!;
    expect(kept.text('company'), 'Edited later');
    // Later edits build on this device's own acknowledged write, so they
    // are not reported as changed elsewhere.
    expect(kept.version, 1);
    expect(
      draftConflict(kept, api.server.of(EntitySection.experience).single),
      DraftConflict.none,
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

  test('unsaved new items are listed until the server knows them', () async {
    await repository.retainDraft(api.server.id, experience);
    expect(
      (await repository.unsavedNew(
        api.server,
        EntitySection.experience,
      )).single.id,
      experience.id,
    );
    final saved = await repository.upsert(api.server, experience);
    expect(
      await repository.unsavedNew(saved, EntitySection.experience),
      isEmpty,
    );
  });

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
}
