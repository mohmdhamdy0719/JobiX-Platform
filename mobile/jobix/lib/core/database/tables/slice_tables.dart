import 'package:drift/drift.dart';

/// Anonymous onboarding is local only, not a server identity.
class LocalOnboarding extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get progress => text()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

/// Encrypted account-scoped acknowledged snapshots, never server authority.
class LocalProfiles extends Table {
  TextColumn get userId => text()();
  TextColumn get profileId => text()();
  TextColumn get snapshot => text()();
  @override
  Set<Column> get primaryKey => {userId, profileId};
}

class LocalDrafts extends Table {
  TextColumn get userId => text()();
  TextColumn get profileId => text()();
  TextColumn get draft => text()();
  @override
  Set<Column> get primaryKey => {userId, profileId};
}
