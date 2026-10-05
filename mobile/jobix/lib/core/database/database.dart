import 'package:drift/drift.dart';
import '../../features/onboarding/research_context.dart';
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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSectionDrafts();
      await _createPendingMutations();
      await into(infrastructureMetadata).insert(
        InfrastructureMetadataCompanion.insert(key: 'schema', value: '4'),
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 1 || from > 3 || to != 4) {
        throw StateError('Unsupported database migration $from -> $to');
      }
      if (from == 1) {
        await m.createTable(localOnboarding);
        await m.createTable(localProfiles);
        await m.createTable(localDrafts);
      }
      if (from < 3) await _createSectionDrafts();
      await _createPendingMutations();
      await into(infrastructureMetadata).insertOnConflictUpdate(
        InfrastructureMetadataCompanion.insert(key: 'schema', value: '4'),
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
  // At most one unacknowledged profile command per profile. It keeps its
  // idempotency key across restarts and shares the account wipe boundary.
  Future<void> _createPendingMutations() => customStatement('''
    CREATE TABLE local_pending_mutations (
      user_id TEXT NOT NULL, profile_id TEXT NOT NULL, request TEXT NOT NULL,
      PRIMARY KEY(user_id,profile_id)
    )
  ''');

  Future<String?> pendingMutation(
    String user,
    String profile,
  ) async => (await customSelect(
    'SELECT request FROM local_pending_mutations WHERE user_id=? AND profile_id=?',
    variables: [Variable(user), Variable(profile)],
  ).getSingleOrNull())?.read<String>('request');
  Future<void> retainPendingMutation(
    String user,
    String profile,
    String request,
  ) => customStatement(
    'INSERT INTO local_pending_mutations VALUES(?,?,?) ON CONFLICT(user_id,profile_id) DO UPDATE SET request=excluded.request',
    [user, profile, request],
  );
  Future<void> discardPendingMutation(String user, String profile) =>
      customStatement(
        'DELETE FROM local_pending_mutations WHERE user_id=? AND profile_id=?',
        [user, profile],
      );
  Future<List<String>> sectionDraftKeys(
    String user,
    String profile,
    String prefix,
  ) async => [
    for (final row in await customSelect(
      'SELECT section FROM local_section_drafts WHERE user_id=? AND profile_id=? AND substr(section,1,?)=?',
      variables: [
        Variable(user),
        Variable(profile),
        Variable(prefix.length),
        Variable(prefix),
      ],
    ).get())
      row.read<String>('section'),
  ];

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
    final firstLaunch = ResearchProgress.decode(await onboarding());
    if (firstLaunch.experienceComplete) {
      await setSetting('first_launch_completed', 'true');
    }
    await customStatement('DELETE FROM local_section_drafts WHERE user_id=?', [
      user,
    ]);
    await customStatement(
      'DELETE FROM local_pending_mutations WHERE user_id=?',
      [user],
    );
    await (delete(localDrafts)..where((t) => t.userId.equals(user))).go();
    await (delete(localProfiles)..where((t) => t.userId.equals(user))).go();
    if (await setting('research_owner') == user ||
        await setting('registration_user') == user) {
      await delete(localOnboarding).go();
      await removeSetting('research_owner');
    }
    await removeSetting('cities_$user');
    await customStatement(
      'DELETE FROM local_settings WHERE substr(key,1,?)=? OR substr(key,1,?)=?',
      [
        'extras:$user:'.length,
        'extras:$user:',
        'resume:$user:'.length,
        'resume:$user:',
      ],
    );
    if (await setting('registration_user') == user) {
      await removeSetting('registration_user');
    }
  });
}
