import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/auth/provider_settings.dart';

void main() {
  test(
    'Google availability uses the public server boolean, not a UI default',
    () {
      for (final enabled in [false, true]) {
        expect(
          AuthProviderSettings.parse({
            'external': {'google': enabled},
          }).googleEnabled,
          enabled,
        );
      }
    },
  );
  test('malformed settings fail explicitly', () {
    for (final value in [
      null,
      {},
      {'external': {}},
      {
        'external': {'google': 'true'},
      },
    ]) {
      expect(() => AuthProviderSettings.parse(value), throwsFormatException);
    }
  });
}
