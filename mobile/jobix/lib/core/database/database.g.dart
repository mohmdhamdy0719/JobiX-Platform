// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $InfrastructureMetadataTable extends InfrastructureMetadata
    with TableInfo<$InfrastructureMetadataTable, InfrastructureMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InfrastructureMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'infrastructure_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<InfrastructureMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  InfrastructureMetadataData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InfrastructureMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $InfrastructureMetadataTable createAlias(String alias) {
    return $InfrastructureMetadataTable(attachedDatabase, alias);
  }
}

class InfrastructureMetadataData extends DataClass
    implements Insertable<InfrastructureMetadataData> {
  final String key;
  final String value;
  const InfrastructureMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  InfrastructureMetadataCompanion toCompanion(bool nullToAbsent) {
    return InfrastructureMetadataCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory InfrastructureMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InfrastructureMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  InfrastructureMetadataData copyWith({String? key, String? value}) =>
      InfrastructureMetadataData(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  InfrastructureMetadataData copyWithCompanion(
    InfrastructureMetadataCompanion data,
  ) {
    return InfrastructureMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InfrastructureMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfrastructureMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class InfrastructureMetadataCompanion
    extends UpdateCompanion<InfrastructureMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const InfrastructureMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InfrastructureMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<InfrastructureMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InfrastructureMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return InfrastructureMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InfrastructureMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSettingsTable extends LocalSettings
    with TableInfo<$LocalSettingsTable, LocalSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $LocalSettingsTable createAlias(String alias) {
    return $LocalSettingsTable(attachedDatabase, alias);
  }
}

class LocalSetting extends DataClass implements Insertable<LocalSetting> {
  final String key;
  final String value;
  const LocalSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory LocalSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalSetting copyWith({String? key, String? value}) =>
      LocalSetting(key: key ?? this.key, value: value ?? this.value);
  LocalSetting copyWithCompanion(LocalSettingsCompanion data) {
    return LocalSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class LocalSettingsCompanion extends UpdateCompanion<LocalSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return LocalSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalOnboardingTable extends LocalOnboarding
    with TableInfo<$LocalOnboardingTable, LocalOnboardingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOnboardingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<String> progress = GeneratedColumn<String>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, progress];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_onboarding';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalOnboardingData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    } else if (isInserting) {
      context.missing(_progressMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalOnboardingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOnboardingData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}progress'],
      )!,
    );
  }

  @override
  $LocalOnboardingTable createAlias(String alias) {
    return $LocalOnboardingTable(attachedDatabase, alias);
  }
}

class LocalOnboardingData extends DataClass
    implements Insertable<LocalOnboardingData> {
  final int id;
  final String progress;
  const LocalOnboardingData({required this.id, required this.progress});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['progress'] = Variable<String>(progress);
    return map;
  }

  LocalOnboardingCompanion toCompanion(bool nullToAbsent) {
    return LocalOnboardingCompanion(id: Value(id), progress: Value(progress));
  }

  factory LocalOnboardingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOnboardingData(
      id: serializer.fromJson<int>(json['id']),
      progress: serializer.fromJson<String>(json['progress']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'progress': serializer.toJson<String>(progress),
    };
  }

  LocalOnboardingData copyWith({int? id, String? progress}) =>
      LocalOnboardingData(
        id: id ?? this.id,
        progress: progress ?? this.progress,
      );
  LocalOnboardingData copyWithCompanion(LocalOnboardingCompanion data) {
    return LocalOnboardingData(
      id: data.id.present ? data.id.value : this.id,
      progress: data.progress.present ? data.progress.value : this.progress,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOnboardingData(')
          ..write('id: $id, ')
          ..write('progress: $progress')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, progress);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOnboardingData &&
          other.id == this.id &&
          other.progress == this.progress);
}

class LocalOnboardingCompanion extends UpdateCompanion<LocalOnboardingData> {
  final Value<int> id;
  final Value<String> progress;
  const LocalOnboardingCompanion({
    this.id = const Value.absent(),
    this.progress = const Value.absent(),
  });
  LocalOnboardingCompanion.insert({
    this.id = const Value.absent(),
    required String progress,
  }) : progress = Value(progress);
  static Insertable<LocalOnboardingData> custom({
    Expression<int>? id,
    Expression<String>? progress,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (progress != null) 'progress': progress,
    });
  }

  LocalOnboardingCompanion copyWith({Value<int>? id, Value<String>? progress}) {
    return LocalOnboardingCompanion(
      id: id ?? this.id,
      progress: progress ?? this.progress,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (progress.present) {
      map['progress'] = Variable<String>(progress.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalOnboardingCompanion(')
          ..write('id: $id, ')
          ..write('progress: $progress')
          ..write(')'))
        .toString();
  }
}

class $LocalProfilesTable extends LocalProfiles
    with TableInfo<$LocalProfilesTable, LocalProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotMeta = const VerificationMeta(
    'snapshot',
  );
  @override
  late final GeneratedColumn<String> snapshot = GeneratedColumn<String>(
    'snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, profileId, snapshot];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, profileId};
  @override
  LocalProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfile(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot'],
      )!,
    );
  }

  @override
  $LocalProfilesTable createAlias(String alias) {
    return $LocalProfilesTable(attachedDatabase, alias);
  }
}

class LocalProfile extends DataClass implements Insertable<LocalProfile> {
  final String userId;
  final String profileId;
  final String snapshot;
  const LocalProfile({
    required this.userId,
    required this.profileId,
    required this.snapshot,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['profile_id'] = Variable<String>(profileId);
    map['snapshot'] = Variable<String>(snapshot);
    return map;
  }

  LocalProfilesCompanion toCompanion(bool nullToAbsent) {
    return LocalProfilesCompanion(
      userId: Value(userId),
      profileId: Value(profileId),
      snapshot: Value(snapshot),
    );
  }

  factory LocalProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfile(
      userId: serializer.fromJson<String>(json['userId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      snapshot: serializer.fromJson<String>(json['snapshot']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'profileId': serializer.toJson<String>(profileId),
      'snapshot': serializer.toJson<String>(snapshot),
    };
  }

  LocalProfile copyWith({
    String? userId,
    String? profileId,
    String? snapshot,
  }) => LocalProfile(
    userId: userId ?? this.userId,
    profileId: profileId ?? this.profileId,
    snapshot: snapshot ?? this.snapshot,
  );
  LocalProfile copyWithCompanion(LocalProfilesCompanion data) {
    return LocalProfile(
      userId: data.userId.present ? data.userId.value : this.userId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfile(')
          ..write('userId: $userId, ')
          ..write('profileId: $profileId, ')
          ..write('snapshot: $snapshot')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, profileId, snapshot);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfile &&
          other.userId == this.userId &&
          other.profileId == this.profileId &&
          other.snapshot == this.snapshot);
}

class LocalProfilesCompanion extends UpdateCompanion<LocalProfile> {
  final Value<String> userId;
  final Value<String> profileId;
  final Value<String> snapshot;
  final Value<int> rowid;
  const LocalProfilesCompanion({
    this.userId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfilesCompanion.insert({
    required String userId,
    required String profileId,
    required String snapshot,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       profileId = Value(profileId),
       snapshot = Value(snapshot);
  static Insertable<LocalProfile> custom({
    Expression<String>? userId,
    Expression<String>? profileId,
    Expression<String>? snapshot,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (profileId != null) 'profile_id': profileId,
      if (snapshot != null) 'snapshot': snapshot,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfilesCompanion copyWith({
    Value<String>? userId,
    Value<String>? profileId,
    Value<String>? snapshot,
    Value<int>? rowid,
  }) {
    return LocalProfilesCompanion(
      userId: userId ?? this.userId,
      profileId: profileId ?? this.profileId,
      snapshot: snapshot ?? this.snapshot,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<String>(snapshot.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfilesCompanion(')
          ..write('userId: $userId, ')
          ..write('profileId: $profileId, ')
          ..write('snapshot: $snapshot, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDraftsTable extends LocalDrafts
    with TableInfo<$LocalDraftsTable, LocalDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _draftMeta = const VerificationMeta('draft');
  @override
  late final GeneratedColumn<String> draft = GeneratedColumn<String>(
    'draft',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, profileId, draft];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('draft')) {
      context.handle(
        _draftMeta,
        draft.isAcceptableOrUnknown(data['draft']!, _draftMeta),
      );
    } else if (isInserting) {
      context.missing(_draftMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, profileId};
  @override
  LocalDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDraft(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      draft: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft'],
      )!,
    );
  }

  @override
  $LocalDraftsTable createAlias(String alias) {
    return $LocalDraftsTable(attachedDatabase, alias);
  }
}

class LocalDraft extends DataClass implements Insertable<LocalDraft> {
  final String userId;
  final String profileId;
  final String draft;
  const LocalDraft({
    required this.userId,
    required this.profileId,
    required this.draft,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['profile_id'] = Variable<String>(profileId);
    map['draft'] = Variable<String>(draft);
    return map;
  }

  LocalDraftsCompanion toCompanion(bool nullToAbsent) {
    return LocalDraftsCompanion(
      userId: Value(userId),
      profileId: Value(profileId),
      draft: Value(draft),
    );
  }

  factory LocalDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDraft(
      userId: serializer.fromJson<String>(json['userId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      draft: serializer.fromJson<String>(json['draft']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'profileId': serializer.toJson<String>(profileId),
      'draft': serializer.toJson<String>(draft),
    };
  }

  LocalDraft copyWith({String? userId, String? profileId, String? draft}) =>
      LocalDraft(
        userId: userId ?? this.userId,
        profileId: profileId ?? this.profileId,
        draft: draft ?? this.draft,
      );
  LocalDraft copyWithCompanion(LocalDraftsCompanion data) {
    return LocalDraft(
      userId: data.userId.present ? data.userId.value : this.userId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      draft: data.draft.present ? data.draft.value : this.draft,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDraft(')
          ..write('userId: $userId, ')
          ..write('profileId: $profileId, ')
          ..write('draft: $draft')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, profileId, draft);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDraft &&
          other.userId == this.userId &&
          other.profileId == this.profileId &&
          other.draft == this.draft);
}

class LocalDraftsCompanion extends UpdateCompanion<LocalDraft> {
  final Value<String> userId;
  final Value<String> profileId;
  final Value<String> draft;
  final Value<int> rowid;
  const LocalDraftsCompanion({
    this.userId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.draft = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDraftsCompanion.insert({
    required String userId,
    required String profileId,
    required String draft,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       profileId = Value(profileId),
       draft = Value(draft);
  static Insertable<LocalDraft> custom({
    Expression<String>? userId,
    Expression<String>? profileId,
    Expression<String>? draft,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (profileId != null) 'profile_id': profileId,
      if (draft != null) 'draft': draft,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDraftsCompanion copyWith({
    Value<String>? userId,
    Value<String>? profileId,
    Value<String>? draft,
    Value<int>? rowid,
  }) {
    return LocalDraftsCompanion(
      userId: userId ?? this.userId,
      profileId: profileId ?? this.profileId,
      draft: draft ?? this.draft,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (draft.present) {
      map['draft'] = Variable<String>(draft.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDraftsCompanion(')
          ..write('userId: $userId, ')
          ..write('profileId: $profileId, ')
          ..write('draft: $draft, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $InfrastructureMetadataTable infrastructureMetadata =
      $InfrastructureMetadataTable(this);
  late final $LocalSettingsTable localSettings = $LocalSettingsTable(this);
  late final $LocalOnboardingTable localOnboarding = $LocalOnboardingTable(
    this,
  );
  late final $LocalProfilesTable localProfiles = $LocalProfilesTable(this);
  late final $LocalDraftsTable localDrafts = $LocalDraftsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    infrastructureMetadata,
    localSettings,
    localOnboarding,
    localProfiles,
    localDrafts,
  ];
}

typedef $$InfrastructureMetadataTableCreateCompanionBuilder =
    InfrastructureMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$InfrastructureMetadataTableUpdateCompanionBuilder =
    InfrastructureMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$InfrastructureMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $InfrastructureMetadataTable> {
  $$InfrastructureMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InfrastructureMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $InfrastructureMetadataTable> {
  $$InfrastructureMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InfrastructureMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $InfrastructureMetadataTable> {
  $$InfrastructureMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$InfrastructureMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InfrastructureMetadataTable,
          InfrastructureMetadataData,
          $$InfrastructureMetadataTableFilterComposer,
          $$InfrastructureMetadataTableOrderingComposer,
          $$InfrastructureMetadataTableAnnotationComposer,
          $$InfrastructureMetadataTableCreateCompanionBuilder,
          $$InfrastructureMetadataTableUpdateCompanionBuilder,
          (
            InfrastructureMetadataData,
            BaseReferences<
              _$AppDatabase,
              $InfrastructureMetadataTable,
              InfrastructureMetadataData
            >,
          ),
          InfrastructureMetadataData,
          PrefetchHooks Function()
        > {
  $$InfrastructureMetadataTableTableManager(
    _$AppDatabase db,
    $InfrastructureMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InfrastructureMetadataTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InfrastructureMetadataTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InfrastructureMetadataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InfrastructureMetadataCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => InfrastructureMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InfrastructureMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InfrastructureMetadataTable,
      InfrastructureMetadataData,
      $$InfrastructureMetadataTableFilterComposer,
      $$InfrastructureMetadataTableOrderingComposer,
      $$InfrastructureMetadataTableAnnotationComposer,
      $$InfrastructureMetadataTableCreateCompanionBuilder,
      $$InfrastructureMetadataTableUpdateCompanionBuilder,
      (
        InfrastructureMetadataData,
        BaseReferences<
          _$AppDatabase,
          $InfrastructureMetadataTable,
          InfrastructureMetadataData
        >,
      ),
      InfrastructureMetadataData,
      PrefetchHooks Function()
    >;
typedef $$LocalSettingsTableCreateCompanionBuilder =
    LocalSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$LocalSettingsTableUpdateCompanionBuilder =
    LocalSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$LocalSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSettingsTable,
          LocalSetting,
          $$LocalSettingsTableFilterComposer,
          $$LocalSettingsTableOrderingComposer,
          $$LocalSettingsTableAnnotationComposer,
          $$LocalSettingsTableCreateCompanionBuilder,
          $$LocalSettingsTableUpdateCompanionBuilder,
          (
            LocalSetting,
            BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>,
          ),
          LocalSetting,
          PrefetchHooks Function()
        > {
  $$LocalSettingsTableTableManager(_$AppDatabase db, $LocalSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  LocalSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => LocalSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSettingsTable,
      LocalSetting,
      $$LocalSettingsTableFilterComposer,
      $$LocalSettingsTableOrderingComposer,
      $$LocalSettingsTableAnnotationComposer,
      $$LocalSettingsTableCreateCompanionBuilder,
      $$LocalSettingsTableUpdateCompanionBuilder,
      (
        LocalSetting,
        BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>,
      ),
      LocalSetting,
      PrefetchHooks Function()
    >;
typedef $$LocalOnboardingTableCreateCompanionBuilder =
    LocalOnboardingCompanion Function({
      Value<int> id,
      required String progress,
    });
typedef $$LocalOnboardingTableUpdateCompanionBuilder =
    LocalOnboardingCompanion Function({Value<int> id, Value<String> progress});

class $$LocalOnboardingTableFilterComposer
    extends Composer<_$AppDatabase, $LocalOnboardingTable> {
  $$LocalOnboardingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalOnboardingTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalOnboardingTable> {
  $$LocalOnboardingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalOnboardingTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalOnboardingTable> {
  $$LocalOnboardingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);
}

class $$LocalOnboardingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalOnboardingTable,
          LocalOnboardingData,
          $$LocalOnboardingTableFilterComposer,
          $$LocalOnboardingTableOrderingComposer,
          $$LocalOnboardingTableAnnotationComposer,
          $$LocalOnboardingTableCreateCompanionBuilder,
          $$LocalOnboardingTableUpdateCompanionBuilder,
          (
            LocalOnboardingData,
            BaseReferences<
              _$AppDatabase,
              $LocalOnboardingTable,
              LocalOnboardingData
            >,
          ),
          LocalOnboardingData,
          PrefetchHooks Function()
        > {
  $$LocalOnboardingTableTableManager(
    _$AppDatabase db,
    $LocalOnboardingTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOnboardingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOnboardingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOnboardingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> progress = const Value.absent(),
              }) => LocalOnboardingCompanion(id: id, progress: progress),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String progress,
              }) => LocalOnboardingCompanion.insert(id: id, progress: progress),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalOnboardingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalOnboardingTable,
      LocalOnboardingData,
      $$LocalOnboardingTableFilterComposer,
      $$LocalOnboardingTableOrderingComposer,
      $$LocalOnboardingTableAnnotationComposer,
      $$LocalOnboardingTableCreateCompanionBuilder,
      $$LocalOnboardingTableUpdateCompanionBuilder,
      (
        LocalOnboardingData,
        BaseReferences<
          _$AppDatabase,
          $LocalOnboardingTable,
          LocalOnboardingData
        >,
      ),
      LocalOnboardingData,
      PrefetchHooks Function()
    >;
typedef $$LocalProfilesTableCreateCompanionBuilder =
    LocalProfilesCompanion Function({
      required String userId,
      required String profileId,
      required String snapshot,
      Value<int> rowid,
    });
typedef $$LocalProfilesTableUpdateCompanionBuilder =
    LocalProfilesCompanion Function({
      Value<String> userId,
      Value<String> profileId,
      Value<String> snapshot,
      Value<int> rowid,
    });

class $$LocalProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => column);
}

class $$LocalProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalProfilesTable,
          LocalProfile,
          $$LocalProfilesTableFilterComposer,
          $$LocalProfilesTableOrderingComposer,
          $$LocalProfilesTableAnnotationComposer,
          $$LocalProfilesTableCreateCompanionBuilder,
          $$LocalProfilesTableUpdateCompanionBuilder,
          (
            LocalProfile,
            BaseReferences<_$AppDatabase, $LocalProfilesTable, LocalProfile>,
          ),
          LocalProfile,
          PrefetchHooks Function()
        > {
  $$LocalProfilesTableTableManager(_$AppDatabase db, $LocalProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> snapshot = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion(
                userId: userId,
                profileId: profileId,
                snapshot: snapshot,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String profileId,
                required String snapshot,
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion.insert(
                userId: userId,
                profileId: profileId,
                snapshot: snapshot,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalProfilesTable,
      LocalProfile,
      $$LocalProfilesTableFilterComposer,
      $$LocalProfilesTableOrderingComposer,
      $$LocalProfilesTableAnnotationComposer,
      $$LocalProfilesTableCreateCompanionBuilder,
      $$LocalProfilesTableUpdateCompanionBuilder,
      (
        LocalProfile,
        BaseReferences<_$AppDatabase, $LocalProfilesTable, LocalProfile>,
      ),
      LocalProfile,
      PrefetchHooks Function()
    >;
typedef $$LocalDraftsTableCreateCompanionBuilder =
    LocalDraftsCompanion Function({
      required String userId,
      required String profileId,
      required String draft,
      Value<int> rowid,
    });
typedef $$LocalDraftsTableUpdateCompanionBuilder =
    LocalDraftsCompanion Function({
      Value<String> userId,
      Value<String> profileId,
      Value<String> draft,
      Value<int> rowid,
    });

class $$LocalDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalDraftsTable> {
  $$LocalDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draft => $composableBuilder(
    column: $table.draft,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalDraftsTable> {
  $$LocalDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draft => $composableBuilder(
    column: $table.draft,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalDraftsTable> {
  $$LocalDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get draft =>
      $composableBuilder(column: $table.draft, builder: (column) => column);
}

class $$LocalDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalDraftsTable,
          LocalDraft,
          $$LocalDraftsTableFilterComposer,
          $$LocalDraftsTableOrderingComposer,
          $$LocalDraftsTableAnnotationComposer,
          $$LocalDraftsTableCreateCompanionBuilder,
          $$LocalDraftsTableUpdateCompanionBuilder,
          (
            LocalDraft,
            BaseReferences<_$AppDatabase, $LocalDraftsTable, LocalDraft>,
          ),
          LocalDraft,
          PrefetchHooks Function()
        > {
  $$LocalDraftsTableTableManager(_$AppDatabase db, $LocalDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> draft = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDraftsCompanion(
                userId: userId,
                profileId: profileId,
                draft: draft,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String profileId,
                required String draft,
                Value<int> rowid = const Value.absent(),
              }) => LocalDraftsCompanion.insert(
                userId: userId,
                profileId: profileId,
                draft: draft,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalDraftsTable,
      LocalDraft,
      $$LocalDraftsTableFilterComposer,
      $$LocalDraftsTableOrderingComposer,
      $$LocalDraftsTableAnnotationComposer,
      $$LocalDraftsTableCreateCompanionBuilder,
      $$LocalDraftsTableUpdateCompanionBuilder,
      (
        LocalDraft,
        BaseReferences<_$AppDatabase, $LocalDraftsTable, LocalDraft>,
      ),
      LocalDraft,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$InfrastructureMetadataTableTableManager get infrastructureMetadata =>
      $$InfrastructureMetadataTableTableManager(
        _db,
        _db.infrastructureMetadata,
      );
  $$LocalSettingsTableTableManager get localSettings =>
      $$LocalSettingsTableTableManager(_db, _db.localSettings);
  $$LocalOnboardingTableTableManager get localOnboarding =>
      $$LocalOnboardingTableTableManager(_db, _db.localOnboarding);
  $$LocalProfilesTableTableManager get localProfiles =>
      $$LocalProfilesTableTableManager(_db, _db.localProfiles);
  $$LocalDraftsTableTableManager get localDrafts =>
      $$LocalDraftsTableTableManager(_db, _db.localDrafts);
}
