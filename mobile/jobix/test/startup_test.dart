import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/boot/startup.dart';

class FakeStartup implements StartupServices {
  FakeStartup({this.hasSession = false, this.minimum = '1.0.0'});
  @override
  bool hasSession;
  String? minimum;
  final calls = <String>[];
  bool databaseFails = false;
  bool policyFails = false;
  @override
  Future<void> openDatabase() async {
    calls.add('database');
    if (databaseFails) throw StateError('database unavailable');
  }

  @override
  Future<void> restoreSession() async => calls.add('session');
  @override
  Future<String?> readMinimumVersion() async {
    calls.add('policy');
    if (policyFails) throw StateError('network unavailable');
    return minimum;
  }
}

void main() {
  test(
    'no session reaches signed-out without unauthorized policy access',
    () async {
      final service = FakeStartup();
      expect(await startFoundation(service, '1.0.0'), StartupState.signedOut);
      expect(service.calls, ['database', 'session']);
    },
  );
  test('restored session reads policy before entering signed-in', () async {
    final service = FakeStartup(hasSession: true);
    expect(await startFoundation(service, '1.0.0'), StartupState.signedIn);
    expect(service.calls, ['database', 'session', 'policy']);
  });
  test('minimum version blocks signed-in destination', () async {
    final service = FakeStartup(hasSession: true, minimum: '2.0.0');
    expect(
      await startFoundation(service, '1.0.0'),
      StartupState.updateRequired,
    );
  });
  test('missing policy is explicit failure', () async {
    final service = FakeStartup(hasSession: true, minimum: null);
    await expectLater(startFoundation(service, '1.0.0'), throwsStateError);
  });
  test('database failure never restores a session', () async {
    final service = FakeStartup()..databaseFails = true;
    await expectLater(startFoundation(service, '1.0.0'), throwsStateError);
    expect(service.calls, ['database']);
  });
  test('network failure does not silently bypass app policy', () async {
    final service = FakeStartup(hasSession: true)..policyFails = true;
    await expectLater(startFoundation(service, '1.0.0'), throwsStateError);
  });
  test(
    'failure categories are safe, actionable, and never expose raw causes',
    () async {
      for (final entry in {
        FakeStartup()..databaseFails = true:
            StartupFailureStage.protectedStorage,
        FakeStartup(hasSession: true)..policyFails = true:
            StartupFailureStage.appPolicy,
      }.entries) {
        await expectLater(
          startFoundation(entry.key, '1.0.0'),
          throwsA(
            isA<StartupFailure>().having((e) => e.stage, 'stage', entry.value),
          ),
        );
      }
    },
  );
}
