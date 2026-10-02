import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// No plain SQLite fallback: every database connection must prove SQLCipher.
void configureSqlCipher({String? testLibrary}) {
  if (testLibrary != null) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open(testLibrary),
    );
  } else if (Platform.isAndroid) {
    open.overrideFor(
      OperatingSystem.android,
      () => DynamicLibrary.open('libsqlcipher.so'),
    );
  } else if (Platform.isIOS) {
    open.overrideFor(OperatingSystem.iOS, DynamicLibrary.process);
  } else {
    throw UnsupportedError('SQLCipher runtime is configured for Android/iOS');
  }
}

String generateDatabaseKey() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

void unlockDatabase(Database database, String key) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
    throw const FormatException('Invalid local database key');
  }
  database.execute('PRAGMA key = "x\'$key\'"');
  final cipher = database.select('PRAGMA cipher_version');
  if (cipher.isEmpty) throw StateError('SQLCipher is required');
  // Forces a page read so a wrong key fails before startup can succeed.
  database.select('SELECT count(*) FROM sqlite_master');
  database.execute('PRAGMA foreign_keys = ON');
}

NativeDatabase encryptedDatabase(File file, String key) =>
    NativeDatabase(file, setup: (db) => unlockDatabase(db, key));
