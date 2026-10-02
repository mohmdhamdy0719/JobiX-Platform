import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import '../storage/secure_store.dart';
import 'database.dart';
import 'encryption.dart';

Future<AppDatabase> openLocalDatabase(
  String environment,
  SecretStore secrets,
) async {
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
  }
  configureSqlCipher();
  final support = await getApplicationSupportDirectory();
  final directory = Directory(p.join(support.path, 'jobix', environment));
  await directory.create(recursive: true);
  if (Platform.isIOS) {
    // Native implementation excludes the whole directory, including WAL/SHM.
    await const MethodChannel(
      'jobix/storage',
    ).invokeMethod<void>('excludeFromBackup', directory.path);
  }
  final file = File(p.join(directory.path, 'foundation.sqlite'));
  final storageKey = 'database_key_$environment';
  var key = await secrets.read(storageKey);
  if (key == null) {
    // Missing key after reinstall/keystore loss: never try to open plaintext.
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final orphan = File('${file.path}$suffix');
      if (await orphan.exists()) await orphan.delete();
    }
    key = generateDatabaseKey();
    await secrets.write(storageKey, key);
  }
  final db = AppDatabase(encryptedDatabase(file, key));
  try {
    await db.customSelect('SELECT 1 FROM sqlite_master LIMIT 1').get();
    await db.setting('locale');
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}
