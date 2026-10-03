import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/core_mvp/core_api.dart';

void main() {
  test(
    'credit values preserve finalized, reserved and available separately',
    () {
      final value = CreditBalance.fromJson({
        'finalized': 9,
        'reserved': 2,
        'available': 7,
        'version': 3,
      });
      expect(value.finalized, 9);
      expect(value.reserved, 2);
      expect(value.available, 7);
      expect(value.version, 3);
    },
  );

  for (final invalid in [
    {'finalized': -1, 'reserved': 0, 'available': -1, 'version': 1},
    {'finalized': 2, 'reserved': 3, 'available': -1, 'version': 1},
    {'finalized': 5, 'reserved': 0, 'available': 100, 'version': 1},
    {'finalized': 5, 'reserved': 0, 'available': 5, 'version': 0},
    {'finalized': 5.5, 'reserved': 0, 'available': 5, 'version': 1},
  ]) {
    test('malformed server balance is an error, not a fallback counter', () {
      expect(() => CreditBalance.fromJson(invalid), throwsFormatException);
    });
  }
  test('bootstrap requires a successful authoritative envelope', () {
    expect(
      () => CoreSummary.fromJson({
        'state': 'FAILED',
        'data': null,
        'error': 'SERVICE_UNAVAILABLE',
      }),
      throwsFormatException,
    );
    final summary = CoreSummary.fromJson({
      'state': 'SUCCEEDED',
      'error': null,
      'data': {
        'balance': {
          'finalized': 0,
          'reserved': 0,
          'available': 0,
          'version': 1,
        },
        'profiles': [],
        'slots': [],
      },
    });
    expect(summary.balance.available, 0);
    expect(summary.profiles, isEmpty);
  });
  test('history preserves the opaque server cursor and real empty state', () {
    final history = CreditHistory.fromJson({'items': [], 'next_cursor': null});
    expect(history.items, isEmpty);
    expect(history.nextCursor, isNull);
    expect(
      () => CreditHistory.fromJson({'next_cursor': null}),
      throwsA(isA<TypeError>()),
    );
  });
}
