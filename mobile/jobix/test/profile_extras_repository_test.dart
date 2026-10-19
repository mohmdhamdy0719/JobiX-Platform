import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/personal_information/profile_extras_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/slice_fakes.dart';

class ExtrasApiFake implements ProfileExtrasApi {
  final requests = <Map<String, dynamic>>[];
  Future<CareerProfile> Function(Map<String, dynamic>)? onSave;
  @override
  Future<ProfileExtras> read(String profile) async => const ProfileExtras();
  @override
  Future<CareerProfile> save(Map<String, dynamic> request) async {
    requests.add(jsonDecode(jsonEncode(request)) as Map<String, dynamic>);
    if (onSave != null) return onSave!(request);
    return CareerProfile(
      id: request['requested_profile'] as String,
      version: (request['expected_profile_version'] as int) + 1,
    );
  }
}

void main() {
  configureSqlCipher(
    testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
  );
  late Directory directory;
  late AppDatabase database;
  late DraftRepository parent;
  late ProfileExtrasRepository repository;
  late ExtrasApiFake api;
  late String encryptionKey;
  const profile = CareerProfile(id: 'profile-1', version: 1);
  const link = CustomProfileLink(
    id: '720a6e2c-3763-43a0-87bb-968db808b420',
    label: 'Publication',
    url: 'example.com/publication',
  );
  const input = ExtrasDraft(
    profileId: 'profile-1',
    version: 1,
    value: ProfileExtras(links: [link]),
  );
  const personal = PersonalDraft(
    profileId: 'profile-1',
    baseVersion: 1,
    personal: {'full_name': 'Nour Sami', 'email': 'nour@example.com'},
    resumeLanguage: 'en',
  );
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('jobix-extras-');
    encryptionKey = generateDatabaseKey();
    database = AppDatabase(
      encryptedDatabase(File('${directory.path}/db'), encryptionKey),
    );
    parent = DraftRepository(database, FakeProfileApi(), 'one', () => true);
    api = ExtrasApiFake();
    repository = ProfileExtrasRepository(parent, api);
    await parent.retain(personal);
  });
  tearDown(() async {
    await database.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'acknowledged extras save leaves no local editable profile or extras draft',
    () async {
      final result = await repository.save(input);
      expect(result.personalSafe, true);
      expect(result.hasUnsentEdits, false);
      expect(await parent.draft(profile), isNull);
      final extras = api.requests.single['extras'] as Map;
      expect((extras['links'] as List).single['id'], link.id);
      expect(
        (extras['links'] as List).single['url'],
        'https://example.com/publication',
      );
      expect(await repository.local(profile.id), isNull);
      expect(await database.pendingMutation('one', profile.id), isNull);
    },
  );

  test(
    'unknown outcome survives encrypted reopen and replays exact request without persisting edits',
    () async {
      api.onSave = (_) async {
        if (api.requests.length == 1) throw TimeoutException('unknown');
        return const CareerProfile(id: 'profile-1', version: 2);
      };
      await expectLater(
        repository.save(input),
        throwsA(isA<TimeoutException>()),
      );
      final frozen = (await repository.local(profile.id))!.pending;
      expect(frozen, isNotNull);
      await database.close();
      database = AppDatabase(
        encryptedDatabase(File('${directory.path}/db'), encryptionKey),
      );
      parent = DraftRepository(database, FakeProfileApi(), 'one', () => true);
      repository = ProfileExtrasRepository(parent, api);
      final recovered = (await repository.local(profile.id))!;
      expect(recovered.pending, frozen);
      final newer = recovered.edit(
        recovered.value.withLinks([link.edit(label: 'New title')]),
      );
      await repository.retain(newer);
      final result = await repository.save(newer);
      expect(api.requests[1], api.requests[0]);
      expect(result.hasUnsentEdits, true);
      expect(result.draft.value.links.single.label, 'New title');
      expect(await repository.local(profile.id), isNull);
      expect(await parent.draft(profile), isNull);
    },
  );

  test(
    'unsubmitted personal edits do not become persistent during extras save',
    () async {
      api.onSave = (_) async {
        await parent.retain(
          personal.edit('full_name', 'Changed during request'),
        );
        return const CareerProfile(id: 'profile-1', version: 2);
      };
      final result = await repository.save(input);
      expect(result.personalSafe, true);
      expect(await parent.draft(profile), isNull);
    },
  );

  test(
    'legacy personal drafts are discarded; frozen requests still block extras',
    () async {
      await database.saveDraft(
        'one',
        profile.id,
        const PersonalDraft(
          profileId: 'profile-1',
          baseVersion: 0,
          personal: {'full_name': 'Still retained'},
        ).encode(),
      );
      final saved = await repository.save(input);
      expect(saved.personalSafe, true);
      expect(await database.draftFor('one', profile.id), isNull);
      expect(api.requests, hasLength(1));
      await parent.retain(
        PersonalDraft(
          profileId: profile.id,
          baseVersion: 1,
          personal: personal.personal,
          commandKey: newCommandKey(),
          frozen: {
            'version': 1,
            'personal': personal.personal,
            'language': 'en',
          },
        ),
      );
      await expectLater(repository.save(input), throwsStateError);
      expect(api.requests, hasLength(1));
    },
  );

  test('entity outbox is never consumed or replaced by extras', () async {
    await database.retainPendingMutation(
      'one',
      profile.id,
      'existing-entity-request',
    );
    await expectLater(repository.save(input), throwsStateError);
    expect(
      await database.pendingMutation('one', profile.id),
      'existing-entity-request',
    );
    expect(api.requests, isEmpty);
  });

  test('explicit discard removes recovered input without saving it', () async {
    await repository.retain(input);
    await repository.discard(input);
    expect(await repository.local(profile.id), isNull);
    expect(api.requests, isEmpty);
  });

  test('ambiguous extras save cannot be deliberately discarded', () async {
    final pending = ExtrasDraft(
      profileId: input.profileId,
      version: input.version,
      value: input.value,
      pending: const {'command_key': 'request-one'},
    );
    await repository.retain(pending);
    await expectLater(repository.discard(pending), throwsStateError);
    expect((await repository.local(profile.id))!.pending, pending.pending);
  });

  test(
    'known rejection releases request and allows explicit in-memory reapply',
    () async {
      api.onSave = (_) async =>
          throw const PostgrestException(message: 'VERSION_CONFLICT');
      await expectLater(
        repository.save(input),
        throwsA(isA<PostgrestException>()),
      );
      expect(await repository.local(profile.id), isNull);
      const latest = CareerProfile(id: 'profile-1', version: 3);
      final chosen = await repository.reapply(input, latest);
      expect(chosen.version, 3);
      expect(chosen.value.links.single.id, link.id);
      expect(await repository.local(profile.id), isNull);
    },
  );

  test('photo signature, decoded limit and MIME pairing forbid SVG', () {
    expect(
      ProfileExtras.imageMime(Uint8List.fromList(utf8.encode('<svg></svg>'))),
      isNull,
    );
    expect(
      ProfileExtras.imageMime(
        Uint8List.fromList([255, 216, 255, 0, 0, 0, 0, 0]),
      ),
      'image/jpeg',
    );
    expect(
      ProfileExtras.imageMime(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      ),
      'image/png',
    );
    final huge = Uint8List(1048577)..setAll(0, [255, 216, 255]);
    expect(ProfileExtras.imageMime(huge), isNull);
    const incomplete = ProfileExtras(photoMime: 'image/png');
    expect(incomplete.valid, false);
  });

  test(
    'unsubmitted inputs are not persisted; invalid partial links do not send a request',
    () async {
      final incomplete = input.edit(
        input.value.withLinks([link.edit(label: '', url: 'not done')]),
      );
      await repository.retain(incomplete);
      expect(await repository.local(profile.id), isNull);
      final other = ProfileExtrasRepository(
        DraftRepository(database, FakeProfileApi(), 'two', () => true),
        api,
      );
      expect(await other.local(profile.id), isNull);
      final pendingCount = api.requests.length;
      await expectLater(repository.save(incomplete), throwsStateError);
      expect(api.requests.length, pendingCount);
    },
  );
}
