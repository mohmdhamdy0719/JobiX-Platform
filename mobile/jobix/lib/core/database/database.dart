import 'package:drift/drift.dart';

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

@DriftDatabase(tables: [InfrastructureMetadata, LocalSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(infrastructureMetadata).insert(
        InfrastructureMetadataCompanion.insert(key: 'schema', value: '1'),
      );
    },
    onUpgrade: (m, from, to) async {
      // There is no hypothetical future schema; unsupported upgrades fail.
      throw StateError('Unsupported database migration $from -> $to');
    },
  );

  Future<String?> setting(String key) async => (await (select(
    localSettings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) =>
      into(localSettings).insertOnConflictUpdate(
        LocalSettingsCompanion.insert(key: key, value: value),
      );

  Future<void> removeSetting(String key) =>
      (delete(localSettings)..where((t) => t.key.equals(key))).go();
}
