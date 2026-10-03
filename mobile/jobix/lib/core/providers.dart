import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/secure_session_storage.dart';
import '../features/auth/auth_repository.dart';
import '../features/boot/startup.dart';
import 'config/app_config.dart';
import 'database/database.dart';
import 'database/local_store.dart';
import 'localization/direction.dart';
import 'storage/secure_store.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromDefines());
final secretStoreProvider = Provider<SecretStore>(
  (ref) => PlatformSecretStore(ref.watch(appConfigProvider).environment.name),
);
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await openLocalDatabase(
    ref.watch(appConfigProvider).environment.name,
    ref.watch(secretStoreProvider),
  );
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

final supabaseClientProvider = FutureProvider<SupabaseClient>((ref) async {
  // Open the protected store before restoring any session.
  await ref.watch(databaseProvider.future);
  final config = ref.watch(appConfigProvider);
  final sessionStorage = SecureSessionStorage(
    ref.watch(secretStoreProvider),
    config.environment.name,
    deferRestoration: true,
  );
  await Supabase.initialize(
    url: config.supabaseUrl.toString(),
    publishableKey: config.clientKey,
    debug: false,
    authOptions: FlutterAuthClientOptions(
      detectSessionInUri: false, // Explicit validated native callback handler.
      localStorage: sessionStorage,
      pkceAsyncStorage: SecurePkceStorage(
        ref.watch(secretStoreProvider),
        config.environment.name,
      ),
    ),
  );
  final client = Supabase.instance.client;
  try {
    await sessionStorage
        .restoreSession(client)
        .timeout(const Duration(seconds: 15));
  } catch (_) {
    await Supabase.instance.dispose();
    rethrow;
  }
  ref.onDispose(() => unawaited(Supabase.instance.dispose()));
  return client;
});

final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final client = await ref.watch(supabaseClientProvider.future);
  yield client.auth.currentSession;
  yield* client.auth.onAuthStateChange.map((event) => event.session);
});

final startupProvider = FutureProvider<StartupState>((ref) async {
  final config = ref.watch(appConfigProvider);
  final services = _RuntimeStartupServices(ref);
  final result = await startFoundation(services, config.appVersion);
  // Subsequent login/logout/refresh invalidates the guarded startup result.
  ref.watch(authSessionProvider);
  return result;
});

class _RuntimeStartupServices implements StartupServices {
  _RuntimeStartupServices(this.ref);
  final Ref ref;
  SupabaseClient? _client;
  @override
  Future<void> openDatabase() => ref.read(databaseProvider.future);
  @override
  Future<void> restoreSession() async {
    _client = await ref.read(supabaseClientProvider.future);
  }

  @override
  bool get hasSession => sessionIsConfirmed(_client?.auth.currentSession);
  @override
  Future<String?> readMinimumVersion() async {
    final row = await _client!
        .rpc('read_app_policy', params: {'requested_key': 'mobile'})
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    return row?['minimum_supported_version'] as String?;
  }
}

final localeProvider = AsyncNotifierProvider<LocaleController, String?>(
  LocaleController.new,
);

class LocaleController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async =>
      (await ref.watch(databaseProvider.future)).setting('locale');

  Future<void> setOverride(String? languageCode) async {
    if (languageCode != null && languageCode != 'ar' && languageCode != 'en') {
      throw ArgumentError('Unsupported locale');
    }
    final db = await ref.read(databaseProvider.future);
    if (languageCode == null) {
      await db.removeSetting('locale');
    } else {
      await db.setSetting('locale', languageCode);
    }
    state = AsyncData(languageCode);
  }
}

final resolvedLocaleProvider = Provider.family<Locale, Locale>(
  (ref, device) => resolveLocale(device, ref.watch(localeProvider).valueOrNull),
);
