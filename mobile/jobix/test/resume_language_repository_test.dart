import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/features/resume/resume_language_repository.dart';

void main() {
  configureSqlCipher(
    testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
  );

  test(
    'language save freezes one request, isolates accounts, and reconciles retry',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var actor = 'account-one';
      var failAfterDispatch = true;
      var reads = 0;
      final requests = <Map<String, dynamic>>[];
      ResumeLanguageRepository repository(String user) =>
          ResumeLanguageRepository(
            database: database,
            user: user,
            profileId: 'profile-one',
            isCurrentUser: () => actor == user,
            readRemote: (profileId) async {
              reads++;
              expect(profileId, 'profile-one');
              return {'language': 'en', 'version': 4};
            },
            saveRemote: (request) async {
              requests.add(Map<String, dynamic>.from(request));
              if (failAfterDispatch) throw const SocketException('timeout');
              return {
                'profile_id': 'profile-one',
                'language': request['language'],
                'version': 5,
              };
            },
          );

      final initial = await repository('account-one').load(
        profileLanguage: null,
        appLanguage: 'ar',
      );
      expect(initial.language, 'en');
      expect(initial.version, 4);
      expect(reads, 1);

      final first = repository('account-one');
      await expectLater(
        first.save('ar', initial.version),
        throwsA(isA<SocketException>()),
      );
      expect(requests, hasLength(1));
      final frozen = Map<String, dynamic>.from(requests.single);
      expect(frozen['expected_version'], 4);
      expect(frozen['language'], 'ar');
      expect(frozen['template_id'], 'resume_ats_ar_v1');

      final restarted = repository('account-one');
      final pending = await restarted.load(
        profileLanguage: 'en',
        appLanguage: 'en',
      );
      expect(pending.pending, isTrue);
      expect(pending.language, 'ar');
      expect(reads, 1, reason: 'a frozen request is not replaced by a new read');

      actor = 'account-two';
      await expectLater(
        restarted.save('ar', pending.version),
        throwsA(isA<StateError>()),
      );
      expect(requests, hasLength(1));
      actor = 'account-one';
      failAfterDispatch = false;
      expect(await restarted.save('ar', pending.version), 5);
      expect(requests, hasLength(2));
      expect(requests[1], frozen, reason: 'retry reuses the exact request key');
      expect(await database.setting(restarted.key), isNull);
    },
  );
}
