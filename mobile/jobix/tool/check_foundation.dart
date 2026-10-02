import 'dart:convert';
import 'dart:io';

import 'package:jobix/core/config/app_config.dart';

/// No matched values are printed, even if a credential is accidentally found.
void main(List<String> arguments) {
  final failures = <String>[];
  for (final root in ['lib', 'config', 'android/app/src', 'ios/Runner']) {
    for (final entry in Directory(root).listSync(recursive: true)) {
      if (entry is! File || entry.path.endsWith('.png')) continue;
      String source;
      try {
        source = entry.readAsStringSync();
      } catch (_) {
        continue;
      }
      final jwt = RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+');
      for (final match in jwt.allMatches(source)) {
        try {
          final role =
              (jsonDecode(
                    utf8.decode(
                      base64Url.decode(
                        base64Url.normalize(match[0]!.split('.')[1]),
                      ),
                    ),
                  )
                  as Map<String, dynamic>)['role'];
          if (role != 'anon') failures.add('Non-public JWT in ${entry.path}');
        } catch (_) {
          failures.add('Unrecognised JWT in ${entry.path}');
        }
      }
      if (RegExp(
        r'sb_secret_[A-Za-z0-9_-]{10,}|-----BEGIN .*PRIVATE KEY-----',
      ).hasMatch(source)) {
        failures.add('Server credential in ${entry.path}');
      }
      if (entry.path.endsWith('.dart') &&
          !entry.path.endsWith('.g.dart') &&
          !entry.path.contains('/l10n/')) {
        if (RegExp(
          r'EdgeInsets\.(only|fromLTRB)|Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)|TextAlign\.(left|right)|Positioned\s*\([^)]*\b(left|right)\s*:',
          dotAll: true,
        ).hasMatch(source)) {
          failures.add('Non-directional layout in ${entry.path}');
        }
        if (!entry.path.endsWith('/tokens.dart') &&
            RegExp(r'Color\(0x|Colors\.|fontFamily:').hasMatch(source)) {
          failures.add('Scattered design value in ${entry.path}');
        }
      }
    }
  }

  if (arguments.isNotEmpty) {
    final seenHosts = <String>{};
    final seenEnvs = <String>{};
    for (final file in arguments) {
      final values =
          jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
      try {
        final config = AppConfig.parse(
          values.map((key, value) => MapEntry(key, value as String)),
        );
        final packageVersion = RegExp(
          r'^version:\s*(\d+\.\d+\.\d+)',
          multiLine: true,
        ).firstMatch(File('pubspec.yaml').readAsStringSync())?.group(1);
        if (config.appVersion != packageVersion) {
          failures.add('App version differs from package version in $file');
        }
      } catch (_) {
        failures.add('Invalid public configuration in $file');
      }
      final env = values['APP_ENV'];
      final url = Uri.tryParse(values['SUPABASE_URL'] ?? '');
      if (!['dev', 'staging', 'prod'].contains(env) ||
          !seenEnvs.add(env as String) ||
          url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          !seenHosts.add(url.host)) {
        failures.add('Missing/duplicate environment or project in $file');
      }
      if (values.keys.any(
        (key) => ![
          'APP_ENV',
          'APP_VERSION',
          'SUPABASE_URL',
          'SUPABASE_CLIENT_KEY',
        ].contains(key),
      )) {
        failures.add('Unexpected client configuration in $file');
      }
    }
  }
  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln(failure);
    }
    exitCode = 1;
  } else {
    stdout.writeln('PASS: client secret, layout, and token checks');
  }
}
