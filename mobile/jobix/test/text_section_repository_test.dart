import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/career_profile/text_section_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/slice_fakes.dart';

void main() {
  configureSqlCipher(
    testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
  );
  late Directory directory;
  late AppDatabase db;
  late DraftRepository parent;
  late String key;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('jobix-text-');
    key = generateDatabaseKey();
    db = AppDatabase(encryptedDatabase(File('${directory.path}/db'), key));
    parent = DraftRepository(db, FakeProfileApi(), 'one', () => true);
  });
  tearDown(() async {
    await db.close();
    directory.deleteSync(recursive: true);
  });
  const profile = CareerProfile(id: 'profile', version: 1);
  TextSectionDraft draft(String section, String text) => TextSectionDraft(
    profileId: profile.id,
    section: section,
    version: 1,
    text: text,
  );
  test(
    'unsubmitted text is not persisted and account wipe remains owner-scoped',
    () async {
      final repo = TextSectionRepository(
        parent,
        (_) => throw StateError('not sent'),
      );
      await repo.retain(draft('summary', 'summary draft'));
      await repo.retain(draft('target_role', 'target draft'));
      await db.saveDraft('one', profile.id, 'personal draft');
      await db.retainSection('two', profile.id, 'summary', 'other account');
      expect(await repo.load(profile, 'summary'), isNull);
      expect(await repo.load(profile, 'target_role'), isNull);
      expect(await db.sectionDraft('one', profile.id, 'summary'), isNull);
      expect(await db.draftFor('one', profile.id), 'personal draft');
      await db.clearAccount('one');
      expect(await db.hasSectionDrafts('one', profile.id), false);
      expect(
        await db.sectionDraft('two', profile.id, 'summary'),
        'other account',
      );
    },
  );
  test(
    'unknown outcome survives restart and reuses the exact submitted request',
    () async {
      final requests = <TextSectionDraft>[];
      var repo = TextSectionRepository(parent, (request) async {
        requests.add(request);
        if (requests.length == 1) throw const SocketException('unknown');
        return CareerProfile(
          id: profile.id,
          version: 2,
          summary: request.request!['text'] as String,
        );
      });
      await expectLater(
        repo.save(draft('summary', 'original')),
        throwsA(isA<SocketException>()),
      );
      await expectLater(repo.discard(profile, 'summary'), throwsStateError);
      await db.close();
      db = AppDatabase(encryptedDatabase(File('${directory.path}/db'), key));
      parent = DraftRepository(db, FakeProfileApi(), 'one', () => true);
      repo = TextSectionRepository(parent, (request) async {
        requests.add(request);
        return CareerProfile(
          id: profile.id,
          version: 2,
          summary: request.request!['text'] as String,
        );
      });
      final pending = (await repo.load(profile, 'summary'))!;
      await repo.retain(pending.edit('new edit'));
      await repo.save(pending.edit('new edit'));
      expect(requests[0].key, requests[1].key);
      expect(requests[1].request!['text'], 'original');
      expect(await repo.load(profile, 'summary'), isNull);
    },
  );
  test(
    'known conflict releases the request and leaves no persisted edit',
    () async {
      final repo = TextSectionRepository(parent, (_) async {
        throw const PostgrestException(
          message: 'VERSION_CONFLICT',
          code: 'P0001',
        );
      });
      await expectLater(
        repo.save(draft('target_role', 'Engineer')),
        throwsA(isA<PostgrestException>()),
      );
      expect(await repo.load(profile, 'target_role'), isNull);
    },
  );
  test('v2 upgrade preserves existing personal drafts and settings', () async {
    await db.setSetting('locale', 'ar');
    await db.saveDraft('one', profile.id, 'retained');
    // A real v2 file has neither v3 section drafts nor the v4 outbox.
    await db.customStatement('DROP TABLE local_section_drafts');
    await db.customStatement('DROP TABLE local_pending_mutations');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();
    db = AppDatabase(encryptedDatabase(File('${directory.path}/db'), key));
    expect(await db.setting('locale'), 'ar');
    expect(await db.draftFor('one', profile.id), 'retained');
    expect(await db.hasAnySectionDrafts('one'), false);
    await db.retainSection('one', profile.id, 'summary', 'new section');
    expect(await db.sectionDraft('one', profile.id, 'summary'), 'new section');
  });
}
