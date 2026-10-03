import '../../core/config/version.dart';

enum StartupState { boot, signedOut, signedIn, updateRequired, failed }

enum StartupFailureStage { protectedStorage, sessionRecovery, appPolicy }

/// Safe diagnostic category only: never retain or display raw SDK/PII errors.
class StartupFailure extends StateError {
  StartupFailure(this.stage)
    : super('Guarded startup unavailable: ${stage.name}');
  final StartupFailureStage stage;
}

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
  try {
    await services.openDatabase();
  } catch (_) {
    throw StartupFailure(StartupFailureStage.protectedStorage);
  }
  try {
    await services.restoreSession();
  } catch (_) {
    throw StartupFailure(StartupFailureStage.sessionRecovery);
  }
  // V2 policy access is authenticated-only. Signed-out clients cannot read it.
  // Re-check immediately after an auth session appears; do not weaken RLS.
  if (!services.hasSession) return StartupState.signedOut;
  try {
    final minimum = await services.readMinimumVersion();
    if (minimum == null) throw StateError('App policy is missing');
    if (isBelowMinimum(appVersion, minimum)) return StartupState.updateRequired;
  } catch (_) {
    throw StartupFailure(StartupFailureStage.appPolicy);
  }
  return StartupState.signedIn;
}
