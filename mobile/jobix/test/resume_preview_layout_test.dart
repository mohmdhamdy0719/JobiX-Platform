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
      testWidgets(
        '$locale preview keeps the document above persistent controls '
        '${narrow ? '320 scaled' : '390'}',
        (tester) async {
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
                exportEnabled: true,
                valid: true,
                availableCredits: 0,
                onExport: () => exports++,
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
            tester.getRect(
              find.byKey(const ValueKey('resume-page-navigation')),
            ),
            navigation,
          );
          expect(find.textContaining('English (LTR)'), findsOneWidget);
          expect(find.text('Not enough Credits'), findsNothing);
          expect(find.text('Credit balance unavailable'), findsNothing);
          await tester.tap(
            find.byTooltip(locale == 'ar' ? 'الصفحة التالية' : 'Next page'),
          );
          await tester.tap(
            find.text(locale == 'ar' ? 'تعديل الملف' : 'Edit Profile'),
          );
          await tester.tap(
            find.text(locale == 'ar' ? 'تصدير PDF' : 'Export PDF'),
          );
          expect(next, 1);
          expect(edits, 1);
          expect(exports, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final balance in [0, 1, 2, 8, null]) {
    testWidgets(
      'Preview keeps Export PDF available with balance $balance; no persistent warning',
      (tester) async {
        var exports = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: foundationTheme(languageCode: 'en'),
            home: ResumePreviewLayout(
              paper: const Text('Synthetic resume document'),
              language: 'en',
              page: 0,
              pages: 1,
              busy: false,
              exportEnabled: true,
              valid: true,
              availableCredits: balance,
              onExport: () => exports++,
              onEditProfile: () {},
              onPrevious: null,
              onNext: null,
            ),
          ),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.text('Not enough Credits'), findsNothing);
        expect(find.text('Checking Credit balance'), findsNothing);
        expect(find.text('Credit balance unavailable'), findsNothing);
        await tester.tap(find.text('Export PDF'));
        expect(exports, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('export gate still disables the primary Preview action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: foundationTheme(languageCode: 'en'),
        home: ResumePreviewLayout(
          paper: const Text('Viewer'),
          language: 'en',
          page: 0,
          pages: 1,
          busy: false,
          exportEnabled: false,
          valid: true,
          availableCredits: 8,
          onExport: () {},
          onEditProfile: () {},
          onPrevious: null,
          onNext: null,
        ),
      ),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Export disabled. Preview is free.'), findsOneWidget);
  });
}
