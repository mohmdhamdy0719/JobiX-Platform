import '../../core/config/version.dart';

enum StartupState { boot, signedOut, signedIn, updateRequired, failed }

/// Ports keep startup orchestration testable without mocking Supabase internals.
abstract interface class StartupServices {
  Future<void> openDatabase();
  Future<void> restoreSession();
  Future<String?> readMinimumVersion();
  bool get hasSession;
}

Future<StartupState> startFoundation(
  StartupServices services,
  String appVersion,
) async {
  await services.openDatabase();
  await services.restoreSession();
  // V2 policy access is authenticated-only. Signed-out clients cannot read it.
  // Re-check immediately after an auth session appears; do not weaken RLS.
  if (!services.hasSession) return StartupState.signedOut;
  final minimum = await services.readMinimumVersion();
  if (minimum == null) throw StateError('App policy is missing');
  if (isBelowMinimum(appVersion, minimum)) return StartupState.updateRequired;
  return StartupState.signedIn;
}
