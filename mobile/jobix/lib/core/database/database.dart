import 'package:drift/drift.dart';
import 'tables/slice_tables.dart';

part 'database.g.dart';

class InfrastructureMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    InfrastructureMetadata,
    LocalSettings,
    LocalOnboarding,
    LocalProfiles,
    LocalDrafts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSectionDrafts();
      await into(infrastructureMetadata).insert(
        InfrastructureMetadataCompanion.insert(key: 'schema', value: '3'),
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 1 || from > 2 || to != 3) {
        throw StateError('Unsupported database migration $from -> $to');
      }
      if (from == 1) {
        await m.createTable(localOnboarding);
        await m.createTable(localProfiles);
        await m.createTable(localDrafts);
      }
      await _createSectionDrafts();
      await into(infrastructureMetadata).insertOnConflictUpdate(
        InfrastructureMetadataCompanion.insert(key: 'schema', value: '3'),
      );
    },
  );

  // This table shares the same SQLCipher connection and account wipe boundary.
  Future<void> _createSectionDrafts() => customStatement('''
    CREATE TABLE local_section_drafts (
      user_id TEXT NOT NULL, profile_id TEXT NOT NULL, section TEXT NOT NULL,
      draft TEXT NOT NULL, PRIMARY KEY(user_id,profile_id,section)
    )
  ''');
  Future<String?> sectionDraft(
    String user,
    String profile,
    String section,
  ) async => (await customSelect(
    'SELECT draft FROM local_section_drafts WHERE user_id=? AND profile_id=? AND section=?',
    variables: [Variable(user), Variable(profile), Variable(section)],
  ).getSingleOrNull())?.read<String>('draft');
  Future<void> retainSection(
    String user,
    String profile,
    String section,
    String draft,
  ) => customStatement(
    'INSERT INTO local_section_drafts VALUES(?,?,?,?) ON CONFLICT(user_id,profile_id,section) DO UPDATE SET draft=excluded.draft',
    [user, profile, section, draft],
  );
  Future<void> discardSection(
    String user,
    String profile,
    String section,
  ) => customStatement(
    'DELETE FROM local_section_drafts WHERE user_id=? AND profile_id=? AND section=?',
    [user, profile, section],
  );
  Future<bool> hasSectionDrafts(
    String user,
    String profile,
  ) async => (await customSelect(
    'SELECT 1 FROM local_section_drafts WHERE user_id=? AND profile_id=? LIMIT 1',
    variables: [Variable(user), Variable(profile)],
  ).get()).isNotEmpty;
  Future<bool> hasAnySectionDrafts(String user) async => (await customSelect(
    'SELECT 1 FROM local_section_drafts WHERE user_id=? LIMIT 1',
    variables: [Variable(user)],
  ).get()).isNotEmpty;

  Future<String?> setting(String key) async => (await (select(
    localSettings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) =>
      into(localSettings).insertOnConflictUpdate(
        LocalSettingsCompanion.insert(key: key, value: value),
      );

  Future<void> removeSetting(String key) =>
      (delete(localSettings)..where((t) => t.key.equals(key))).go();

  Future<String?> onboarding() async =>
      (await select(localOnboarding).getSingleOrNull())?.progress;
  Future<bool> writeOwnedResearch(
    String user,
    String expected,
    String value,
    bool Function() isCurrent,
  ) => transaction(() async {
    if (!isCurrent()) return false;
    final owner = await setting('research_owner');
    if ((owner != null && owner != user) ||
        await onboarding() != expected ||
        !isCurrent()) {
      return false;
    }
    await setSetting('research_owner', user);
    await saveOnboarding(value);
    if (!isCurrent()) {
      await clearAccount(user);
      return false;
    }
    return true;
  });
  Future<void> saveOnboarding(String progress) =>
      into(localOnboarding).insertOnConflictUpdate(
        LocalOnboardingCompanion.insert(id: const Value(1), progress: progress),
      );
  Future<String?> cachedProfile(String user, String profile) async =>
      (await (select(localProfiles)..where(
                (t) => t.userId.equals(user) & t.profileId.equals(profile),
              ))
              .getSingleOrNull())
          ?.snapshot;
  Future<String?> firstCachedProfile(String user) async =>
      (await (select(localProfiles)
                ..where((t) => t.userId.equals(user))
                ..limit(1))
              .getSingleOrNull())
          ?.snapshot;
  Future<void> cacheProfile(String user, String profile, String snapshot) =>
      into(localProfiles).insertOnConflictUpdate(
        LocalProfilesCompanion.insert(
          userId: user,
          profileId: profile,
          snapshot: snapshot,
        ),
      );
  Future<String?> draftFor(String user, String profile) async =>
      (await (select(localDrafts)..where(
                (t) => t.userId.equals(user) & t.profileId.equals(profile),
              ))
              .getSingleOrNull())
          ?.draft;
  Future<void> saveDraft(String user, String profile, String draft) =>
      into(localDrafts).insertOnConflictUpdate(
        LocalDraftsCompanion.insert(
          userId: user,
          profileId: profile,
          draft: draft,
        ),
      );
  Future<void> discardDraft(String user, String profile) async {
    await (delete(
      localDrafts,
    )..where((t) => t.userId.equals(user) & t.profileId.equals(profile))).go();
  }

  Future<void> clearAccount(String user) => transaction(() async {
    await customStatement('DELETE FROM local_section_drafts WHERE user_id=?', [
      user,
    ]);
    await (delete(localDrafts)..where((t) => t.userId.equals(user))).go();
    await (delete(localProfiles)..where((t) => t.userId.equals(user))).go();
    if (await setting('research_owner') == user) {
      await delete(localOnboarding).go();
      await removeSetting('research_owner');
    }
    await removeSetting('cities_$user');
    if (await setting('registration_user') == user) {
      await removeSetting('registration_user');
    }
  });
}
