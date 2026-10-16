import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/core/providers.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final library = Platform.environment['JOBIX_SQLCIPHER_LIBRARY'];
  if (library == null) {
    throw StateError('Encryption tests require JOBIX_SQLCIPHER_LIBRARY');
  }
  configureSqlCipher(testLibrary: library);

  late Directory directory;
  late File file;
  late String key;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('jobix-encrypted-test-');
    file = File('${directory.path}/foundation.sqlite');
    key = generateDatabaseKey();
  });
  tearDown(() => directory.deleteSync(recursive: true));

  test(
    'encrypted v0 -> v4 creates infrastructure and real slice storage',
    () async {
      final db = AppDatabase(encryptedDatabase(file, key));
      await db.setSetting('locale', 'ar');
      expect(await db.setting('locale'), 'ar');
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
          )
          .get();
      expect(tables.map((row) => row.read<String>('name')), [
        'infrastructure_metadata',
        'local_drafts',
        'local_onboarding',
        'local_pending_mutations',
        'local_profiles',
        'local_section_drafts',
        'local_settings',
      ]);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        4,
      );
      expect(
        (await db.select(db.infrastructureMetadata).getSingle()).value,
        '4',
      );
      await db.close();
      expect(
        file.readAsBytesSync().take(16).toList(),
        isNot('SQLite format 3\u0000'.codeUnits),
      );
    },
  );
  test('v3 -> v4 keeps drafts and adds the pending-save store', () async {
    final db = AppDatabase(encryptedDatabase(file, key));
    await db.retainSection('u1', 'p1', 'summary', '{"text":"kept"}');
    await db.customStatement('DROP TABLE local_pending_mutations');
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();
    final upgraded = AppDatabase(encryptedDatabase(file, key));
    expect(
      await upgraded.sectionDraft('u1', 'p1', 'summary'),
      '{"text":"kept"}',
    );
    await upgraded.retainPendingMutation('u1', 'p1', '{"key":"k"}');
    expect(await upgraded.pendingMutation('u1', 'p1'), '{"key":"k"}');
    await upgraded.clearAccount('u1');
    expect(await upgraded.pendingMutation('u1', 'p1'), isNull);
    expect(await upgraded.sectionDraft('u1', 'p1', 'summary'), isNull);
    await upgraded.close();
  });
  test('correct key reopens settings without repeating migration', () async {
    final db = AppDatabase(encryptedDatabase(file, key));
    await db.setSetting('locale', 'ar');
    await db.close();
    final reopened = AppDatabase(encryptedDatabase(file, key));
    expect(await reopened.setting('locale'), 'ar');
    await reopened.removeSetting('locale');
    expect(await reopened.setting('locale'), isNull);
    await reopened.close();
  });
  test(
    'completed profile journey survives account-local edit cleanup',
    () async {
      final db = AppDatabase(encryptedDatabase(file, key));
      await db.setSetting('resume_complete:u1', 'true');
      await db.setSetting('resume:u1:journey:p1', '{"step":6,"complete":true}');
      await db.clearAccount('u1');
      expect(await db.setting('resume_complete:u1'), 'true');
      expect(await db.setting('resume:u1:journey:p1'), isNull);
      await db.close();
    },
  );
  test('wrong key cannot read encrypted pages', () async {
    final db = AppDatabase(encryptedDatabase(file, key));
    await db.setSetting('locale', 'en');
    await db.close();
    final wrong = AppDatabase(encryptedDatabase(file, generateDatabaseKey()));
    await expectLater(wrong.setting('locale'), throwsA(isA<SqliteException>()));
    await wrong.close();
  });
  test('missing key cannot open encrypted database', () async {
    final db = AppDatabase(encryptedDatabase(file, key));
    await db.setSetting('locale', 'ar');
    await db.close();
    final raw = sqlite3.open(file.path);
    expect(
      () => raw.select('SELECT * FROM sqlite_master'),
      throwsA(isA<SqliteException>()),
    );
    raw.dispose();
  });
  test('invalid key rejected before database opens', () {
    final raw = sqlite3.openInMemory();
    expect(() => unlockDatabase(raw, 'invalid'), throwsFormatException);
    raw.dispose();
  });
  test('keys are 256-bit cryptographically random hex', () {
    expect(generateDatabaseKey(), matches(r'^[0-9a-f]{64}$'));
    expect(generateDatabaseKey(), isNot(generateDatabaseKey()));
  });
  test(
    'locale controller persists override and restores device default',
    () async {
      final db = AppDatabase(encryptedDatabase(file, key));
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      expect(await container.read(localeProvider.future), isNull);
      await container.read(localeProvider.notifier).setOverride('ar');
      expect(await db.setting('locale'), 'ar');
      container.dispose();
      final restarted = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      expect(await restarted.read(localeProvider.future), 'ar');
      await expectLater(
        restarted.read(localeProvider.notifier).setOverride('fr'),
        throwsArgumentError,
      );
      await restarted.read(localeProvider.notifier).setOverride(null);
      expect(await db.setting('locale'), isNull);
      restarted.dispose();
      await db.close();
    },
  );
}
