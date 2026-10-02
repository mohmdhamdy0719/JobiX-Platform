import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/config/app_config.dart';
import 'package:jobix/core/config/version.dart';

void main() {
  Map<String, String> config({String env = 'dev'}) => {
    'APP_ENV': env,
    'APP_VERSION': '1.0.0',
    'SUPABASE_URL': 'https://$env.example.test',
    'SUPABASE_CLIENT_KEY': 'sb_publishable_test_only',
  };

  test('each environment is explicit', () {
    for (final env in AppEnvironment.values) {
      expect(AppConfig.parse(config(env: env.name)).environment, env);
    }
  });
  test('missing config fails, without credentials in its error', () {
    expect(() => AppConfig.parse({}), throwsFormatException);
    expect(
      () => AppConfig.parse(config()..['APP_ENV'] = 'demo'),
      throwsFormatException,
    );
  });
  test('only HTTPS public configuration accepted', () {
    for (final url in [
      'http://dev.example.test',
      'https://user:password@dev.example.test',
      'https://dev.example.test?key=value',
      'https://dev.example.test#fragment',
    ]) {
      expect(
        () => AppConfig.parse(config()..['SUPABASE_URL'] = url),
        throwsFormatException,
      );
    }
  });
  test('secret and service JWT keys rejected at runtime', () {
    final payload = base64Url.encode(utf8.encode('{"role":"service_role"}'));
    for (final key in ['sb_secret_test_only', 'test.$payload.test']) {
      expect(
        () => AppConfig.parse(config()..['SUPABASE_CLIENT_KEY'] = key),
        throwsFormatException,
      );
    }
  });
  test('anon JWT supported', () {
    final payload = base64Url.encode(utf8.encode('{"role":"anon"}'));
    expect(
      AppConfig.parse(
        config()..['SUPABASE_CLIENT_KEY'] = 'test.$payload.test',
      ).environment,
      AppEnvironment.dev,
    );
  });
  test('version comparison is numeric', () {
    expect(isBelowMinimum('1.2.0', '1.10.0'), isTrue);
    expect(isBelowMinimum('2.0.0', '1.10.0'), isFalse);
    expect(isBelowMinimum('1.0.0', '1.0.0'), isFalse);
    expect(() => isBelowMinimum('1.0.0', 'invalid'), throwsFormatException);
  });
}
