import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client layout and secret check passes', () async {
    final result = await Process.run('dart', ['tool/check_foundation.dart']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
  test(
    'static checker rejects server credentials and non-directional layout',
    () async {
      final script = File('tool/check_foundation.dart').absolute.path;
      final root = Directory.systemTemp.createTempSync('jobix-static-test-');
      try {
        for (final path in ['lib', 'config', 'android/app/src', 'ios/Runner']) {
          Directory('${root.path}/$path').createSync(recursive: true);
        }
        const fakeCredential = 'sb_secret_test_only_not_a_real_credential';
        File('${root.path}/lib/bad.dart').writeAsStringSync(
          "$fakeCredential\nEdgeInsets.only(left: 1)\nColor(0xFFFFFFFF)",
        );
        final result = await Process.run('dart', [
          script,
        ], workingDirectory: root.path);
        expect(result.exitCode, 1);
        expect(result.stderr, contains('Server credential'));
        expect(result.stderr, contains('Non-directional layout'));
        expect(result.stderr, contains('Scattered design value'));
        expect(result.stderr, isNot(contains(fakeCredential)));
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );
  test('Android backup, extraction, HTTPS and iOS backup flags configured', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    expect(rules, contains('<cloud-backup'));
    expect(rules, contains('<device-transfer>'));
    expect(rules, contains('domain="sharedpref"'));
    final native = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(native, contains('values.isExcludedFromBackup = true'));
    final store = File('lib/core/storage/secure_store.dart').readAsStringSync();
    expect(store, contains('first_unlock_this_device'));
    final providers = File('lib/core/providers.dart').readAsStringSync();
    expect(providers, contains('localStorage: sessionStorage'));
    expect(providers, contains('deferRestoration: true'));
    expect(providers, contains('pkceAsyncStorage: SecurePkceStorage'));
  });
}
