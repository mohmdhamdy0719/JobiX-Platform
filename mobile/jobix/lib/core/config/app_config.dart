import 'dart:convert';

enum AppEnvironment { dev, staging, prod }

/// No implicit environment or demo credentials: an invalid build fails closed.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.clientKey,
    required this.appVersion,
  });

  final AppEnvironment environment;
  final Uri supabaseUrl;
  final String clientKey;
  final String appVersion;

  factory AppConfig.fromDefines() => AppConfig.parse({
    'APP_ENV': const String.fromEnvironment('APP_ENV'),
    'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_CLIENT_KEY': const String.fromEnvironment('SUPABASE_CLIENT_KEY'),
    'APP_VERSION': const String.fromEnvironment('APP_VERSION'),
  });

  static AppConfig parse(Map<String, String> values) {
    final env = AppEnvironment.values.where((e) => e.name == values['APP_ENV']);
    final url = Uri.tryParse(values['SUPABASE_URL'] ?? '');
    final key = values['SUPABASE_CLIENT_KEY'] ?? '';
    final version = values['APP_VERSION'] ?? '';
    if (env.length != 1 ||
        url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.query.isNotEmpty ||
        url.fragment.isNotEmpty ||
        key.isEmpty ||
        key.startsWith('sb_secret_') ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const FormatException('Invalid public client configuration');
    }
    if (!key.startsWith('sb_publishable_')) {
      try {
        final payload =
            jsonDecode(
                  utf8.decode(
                    base64Url.decode(base64Url.normalize(key.split('.')[1])),
                  ),
                )
                as Map<String, dynamic>;
        if (payload['role'] != 'anon') {
          throw const FormatException('Client key must be public');
        }
      } catch (_) {
        throw const FormatException('Client key must be public');
      }
    }
    return AppConfig(
      environment: env.single,
      supabaseUrl: url,
      clientKey: key,
      appVersion: version,
    );
  }
}
