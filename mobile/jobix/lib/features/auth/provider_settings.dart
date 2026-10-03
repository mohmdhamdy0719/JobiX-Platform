import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class AuthProviderSettings {
  const AuthProviderSettings({required this.googleEnabled});
  final bool googleEnabled;

  factory AuthProviderSettings.parse(Object? data) {
    if (data is! Map ||
        data['external'] is! Map ||
        (data['external'] as Map)['google'] is! bool) {
      throw const FormatException('Invalid public Auth provider settings');
    }
    return AuthProviderSettings(
      googleEnabled: (data['external'] as Map)['google'] as bool,
    );
  }
}

/// Public provider flags, not a fabricated build-time provider default.
/// Failure is exposed to the UI and must never enable an unverified provider.
final authProviderSettingsProvider = FutureProvider<AuthProviderSettings>((
  ref,
) async {
  final config = ref.watch(appConfigProvider);
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  ref.onDispose(() => http.close(force: true));
  try {
    final request = await http.getUrl(
      config.supabaseUrl.resolve('/auth/v1/settings'),
    );
    request.headers.set('apikey', config.clientKey);
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const HttpException('Public Auth settings unavailable');
    }
    return AuthProviderSettings.parse(
      jsonDecode(
        await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 10)),
      ),
    );
  } finally {
    http.close(force: true);
  }
});
