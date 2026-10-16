import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/features/resume/resume_preview_layout.dart';
import 'package:jobix/l10n/app_localizations.dart';
import 'support/production_fonts.dart';

void main() {
  setUpAll(loadProductionFonts);
  for (final locale in ['en', 'ar']) {
    for (final narrow in [false, true]) {
      testWidgets('$locale preview keeps document above persistent controls '
          '${narrow ? '320 scaled' : '390'}', (tester) async {
        tester.view.physicalSize = narrow
            ? const Size(320, 640)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var edits = 0, exports = 0, next = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: foundationTheme(languageCode: locale),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(narrow ? 1.3 : 1)),
              child: child!,
            ),
            home: ResumePreviewLayout(
              paper: SingleChildScrollView(
                controller: scroll,
                child: const SizedBox(
                  height: 1500,
                  child: Text('Document content supplied by the viewer'),
                ),
              ),
              language: 'en',
              page: 0,
              pages: 3,
              busy: false,
              exportEnabled: false,
              valid: true,
              availableCredits: 2,
              onExport: null,
              onEditProfile: () => edits++,
              onPrevious: null,
              onNext: () => next++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final paper = tester.getRect(
          find.byKey(const ValueKey('resume-document')),
        );
        final navigation = tester.getRect(
          find.byKey(const ValueKey('resume-page-navigation')),
        );
        final info = tester.getRect(
          find.byKey(const ValueKey('resume-preview-info')),
        );
        expect(paper.height, greaterThan(narrow ? 290 : 500));
        expect(paper.bottom, lessThanOrEqualTo(navigation.top));
        expect(navigation.bottom, lessThanOrEqualTo(info.top));
        await tester.drag(
          find.byKey(const ValueKey('resume-document')),
          const Offset(0, -240),
        );
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        expect(
          tester.getRect(find.byKey(const ValueKey('resume-page-navigation'))),
          navigation,
        );
        expect(find.textContaining('English (LTR)'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(
          find.byTooltip(locale == 'ar' ? 'الصفحة التالية' : 'Next page'),
        );
        await tester.tap(
          find.text(locale == 'ar' ? 'تعديل الملف' : 'Edit Profile'),
        );
        expect(next, 1);
        expect(edits, 1);
        expect(exports, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('enabled export delegates once; rendering the preview is free', (
    tester,
  ) async {
    var exports = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: foundationTheme(languageCode: 'en'),
        home: ResumePreviewLayout(
          paper: const Text('Viewer'),
          language: 'en',
          page: 1,
          pages: 2,
          busy: false,
          exportEnabled: true,
          valid: true,
          availableCredits: 2,
          onExport: () => exports++,
          onEditProfile: () {},
          onPrevious: () {},
          onNext: null,
        ),
      ),
    );
    expect(exports, 0);
    await tester.tap(find.text('Export PDF'));
    expect(exports, 1);
    expect(find.text('Page 2 of 2'), findsOneWidget);
  });

  Future<void> pumpBalanceState(
    WidgetTester tester, {
    required String locale,
    int? balance,
    bool loading = false,
    bool unavailable = false,
    VoidCallback? onExport,
    VoidCallback? onRetry,
    VoidCallback? onReview,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: foundationTheme(languageCode: locale),
        home: ResumePreviewLayout(
          paper: const Text('Synthetic resume document'),
          language: locale,
          page: 0,
          pages: 1,
          busy: false,
          exportEnabled: true,
          valid: true,
          availableCredits: balance,
          creditBalanceLoading: loading,
          creditBalanceUnavailable: unavailable,
          onExport: onExport,
          onRetryCredits: onRetry,
          onReviewCredits: onReview,
          onEditProfile: () {},
          onPrevious: null,
          onNext: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in ['en', 'ar']) {
    for (final balance in [0, 1, 2]) {
      testWidgets(
        '$locale new-export balance $balance gates only new PDF creation',
        (tester) async {
          var exports = 0, history = 0;
          await pumpBalanceState(
            tester,
            locale: locale,
            balance: balance,
            onExport: () => exports++,
            onReview: () => history++,
          );
          final exportButton = tester.widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          );
          expect(exportButton.onPressed == null, balance < 2);
          if (balance < 2) {
            expect(
              find.textContaining(
                locale == 'en' ? 'New PDF: 2 Credits' : 'ملف PDF جديد: رصيدان',
              ),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                locale == 'en'
                    ? 'currently have $balance'
                    : 'رصيدك الحالي $balance',
              ),
              findsOneWidget,
            );
            expect(
              find.textContaining(locale == 'en' ? 'purchases' : 'شراء'),
              findsOneWidget,
            );
            await tester.tap(
              find.text(
                locale == 'en' ? 'Review Credit history' : 'مراجعة سجل الرصيد',
              ),
            );
            expect(history, 1);
            expect(exports, 0);
          } else {
            expect(exportButton.onPressed, isNotNull);
            await tester.tap(
              find.text(locale == 'en' ? 'Export PDF' : 'تصدير PDF'),
            );
            expect(exports, 1);
          }
        },
      );
    }

    testWidgets(
      '$locale unknown and refreshing balances never claim low balance',
      (tester) async {
        var retries = 0;
        await pumpBalanceState(
          tester,
          locale: locale,
          loading: true,
          onRetry: () => retries++,
        );
        expect(
          find.text(
            locale == 'en'
                ? 'Checking Credit balance'
                : 'جارٍ التحقق من الرصيد',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton),
              )
              .onPressed,
          isNull,
        );

        await pumpBalanceState(
          tester,
          locale: locale,
          balance: 0,
          loading: true,
          onRetry: () => retries++,
        );
        expect(
          find.text(
            locale == 'en'
                ? 'Checking Credit balance'
                : 'جارٍ التحقق من الرصيد',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            locale == 'en' ? 'Not enough Credits' : 'الرصيد غير كافٍ',
          ),
          findsNothing,
        );

        await pumpBalanceState(
          tester,
          locale: locale,
          unavailable: true,
          onRetry: () => retries++,
        );
        expect(
          find.text(
            locale == 'en' ? 'Credit balance unavailable' : 'الرصيد غير متاح',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            locale == 'en' ? 'Not enough Credits' : 'الرصيد غير كافٍ',
          ),
          findsNothing,
        );
        await tester.tap(
          find.text(
            locale == 'en' ? 'Retry balance check' : 'إعادة التحقق من الرصيد',
          ),
        );
        expect(retries, 1);
      },
    );
  }

  testWidgets(
    'refreshed authoritative balance enables the same preview action',
    (tester) async {
      var exports = 0;
      await pumpBalanceState(
        tester,
        locale: 'en',
        balance: 1,
        onExport: () => exports++,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton),
            )
            .onPressed,
        isNull,
      );
      await pumpBalanceState(
        tester,
        locale: 'en',
        balance: 2,
        onExport: () => exports++,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Export PDF'));
      expect(exports, 1);
    },
  );
}
