import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/features/builder/ai_allowance.dart';
import 'package:jobix/features/builder/jobix_improvement.dart';
import 'package:jobix/l10n/app_localizations.dart';

import 'support/production_fonts.dart';

Map<String, dynamic> serverResponse({
  int used = 2,
  int limit = 6,
  String from = '2100-02-03',
}) => {
  'used': used,
  'limit': limit,
  'reserved': 1,
  'bucket': 'FIRST_PROFILE',
  'available_from': from,
  'generation_enabled': false,
};

Widget app(Future<AiAllowance> Function() allowance, String locale) =>
    ProviderScope(
      overrides: [
        // These UI tests cannot initialize Supabase or touch the network.
        supabaseClientProvider.overrideWith(
          (_) async => throw StateError('Supabase must not be read'),
        ),
        aiAllowanceProvider.overrideWith((_) => allowance()),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        theme: foundationTheme(languageCode: locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Column(
            children: [
              JobixAllowance(),
              JobixImprovement(original: 'My own factual text'),
            ],
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadProductionFonts);

  test(
    'only authoritative allocation is parsed, including reservations and bucket',
    () {
      final allowance = AiAllowance.fromJson(serverResponse());
      expect(allowance.used, 2);
      expect(allowance.limit, 6);
      expect(allowance.reserved, 1);
      expect(allowance.bucket, 'FIRST_PROFILE');
      expect(allowance.availableFrom, DateTime(2100, 2, 3));
      expect(allowance.generationEnabled, false);
      expect(
        () => AiAllowance.fromJson({...serverResponse(), 'used': null}),
        throwsFormatException,
      );
      expect(
        () => AiAllowance.fromJson({...serverResponse(), 'used': -1}),
        throwsFormatException,
      );
      expect(
        () =>
            AiAllowance.fromJson({...serverResponse(), 'available_from': null}),
        throwsFormatException,
      );
      expect(
        () => AiAllowance.fromJson({...serverResponse(), 'limit': '6'}),
        throwsFormatException,
      );
    },
  );

  for (final locale in ['en', 'ar']) {
    testWidgets(
      '$locale real counts and future Cairo date appear while generation stays disabled',
      (tester) async {
        await tester.pumpWidget(
          app(() async => AiAllowance.fromJson(serverResponse()), locale),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('2 / 6'), findsOneWidget);
        expect(
          find.byKey(const Key('jobix-allowance-deferred')),
          findsOneWidget,
        );
        expect(
          find.textContaining(locale == 'ar' ? 'تاريخ القاهرة' : 'Cairo date'),
          findsOneWidget,
        );
        expect(
          find.text(
            locale == 'ar'
                ? 'مزود الذكاء الاصطناعي غير متاح'
                : 'AI provider unavailable',
          ),
          findsOneWidget,
        );
        final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('jobix-generate')),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      '$locale errors are unavailable, sanitized, and never fabricated zero counts',
      (tester) async {
        await tester.pumpWidget(
          app(
            () async => throw StateError('private-server-error-details'),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            locale == 'ar' ? 'الحصة غير متاحة' : 'allowance unavailable',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('private-server-error-details'),
          findsNothing,
        );
        expect(find.textContaining('0 / 6'), findsNothing);
        expect(find.byKey(const Key('jobix-allowance-deferred')), findsNothing);
      },
    );
  }

  testWidgets(
    'loading never displays guessed counts, and an already available date is not deferred',
    (tester) async {
      final pending = Completer<AiAllowance>();
      await tester.pumpWidget(app(() => pending.future, 'en'));
      await tester.pump();
      expect(find.textContaining('0 / 6'), findsNothing);
      expect(find.textContaining('2 / 6'), findsNothing);
      pending.complete(
        AiAllowance.fromJson(serverResponse(from: '2020-01-01')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('2 / 6'), findsOneWidget);
      expect(find.byKey(const Key('jobix-allowance-deferred')), findsNothing);
    },
  );
}
