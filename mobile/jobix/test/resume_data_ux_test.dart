import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/builder/entity_cards.dart';
import 'package:jobix/features/builder/education_catalog.dart';
import 'package:jobix/features/personal_information/country_autocomplete.dart';
import 'package:jobix/features/builder/section_writing_guidance.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:jobix/features/career_profile/summary_examples.dart';
import 'package:jobix/features/career_profile/summary_writing_hints.dart';
import 'package:jobix/l10n/app_localizations.dart';

void main() {
  for (final appLanguage in ['en', 'ar']) {
    for (final resumeLanguage in ['en', 'ar']) {
      testWidgets(
        'writing samples use Resume $resumeLanguage; controls use app $appLanguage',
        (tester) async {
          final controller = TextEditingController(
            text: 'Existing user content',
          );
          addTearDown(controller.dispose);
          var changes = 0;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(appLanguage),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SummaryExamplesButton(
                  controller: controller,
                  enabled: true,
                  resumeLanguage: resumeLanguage,
                  onChanged: (_) => changes++,
                ),
              ),
            ),
          );
          final uiArabic = appLanguage == 'ar';
          final contentArabic = resumeLanguage == 'ar';
          expect(
            find.text(
              uiArabic ? 'استكشف أمثلة الملخص' : 'Explore summary examples',
            ),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('explore-summary-examples')));
          await tester.pumpAndSettle();
          expect(
            find.text(
              (uiArabic
                      ? summaryExampleCategoriesArabic
                      : summaryExampleCategoriesEnglish)
                  .first,
            ),
            findsOneWidget,
          );
          final field = tester.widget<TextFormField>(
            find.byKey(const ValueKey('summary-example-0')),
          );
          expect(
            field.initialValue,
            (contentArabic ? summaryExamplesArabic : summaryExamplesEnglish)
                .first,
          );
          expect(
            tester
                .widget<TextField>(
                  find.descendant(
                    of: find.byKey(const ValueKey('summary-example-0')),
                    matching: find.byType(TextField),
                  ),
                )
                .textDirection,
            contentArabic ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(
            find.text(uiArabic ? 'استخدام هذا الملخص' : 'Use this summary'),
            findsOneWidget,
          );
          await tester.tap(find.text(uiArabic ? 'إغلاق' : 'Close'));
          await tester.pumpAndSettle();
          expect(controller.text, 'Existing user content');
          expect(changes, 0);
        },
      );

      testWidgets(
        'writing guidance uses Resume $resumeLanguage with app $appLanguage chrome',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(appLanguage),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      SummaryWritingHints(resumeLanguage: resumeLanguage),
                      SectionWritingGuidance(
                        section: EntitySection.experience,
                        resumeLanguage: resumeLanguage,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(
            find.text(
              appLanguage == 'ar'
                  ? 'نصائح لكتابة ملخص مهني'
                  : 'Tips to help you write a professional summary',
            ),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('summary-writing-guidance')));
          await tester.pumpAndSettle();
          expect(
            find.text(
              resumeLanguage == 'ar'
                  ? 'ما طبيعة عملك، أو ما الدور الذي تستهدفه؟'
                  : 'What kind of work do you do, or what role are you targeting?',
            ),
            findsOneWidget,
          );
          final section = find.byKey(const Key('section-writing-guidance'));
          await tester.ensureVisible(section);
          await tester.tap(section);
          await tester.pumpAndSettle();
          expect(
            find.text(
              resumeLanguage == 'ar'
                  ? 'ما دورك وما مسؤولياتك؟'
                  : 'What was your role and what were you responsible for?',
            ),
            findsOneWidget,
          );
          expect(find.byType(TextField), findsNothing);
        },
      );
    }
  }
  for (final resumeLanguage in ['en', 'ar']) {
    final appLanguage = resumeLanguage == 'ar' ? 'en' : 'ar';
    testWidgets(
      'country autofill uses Resume $resumeLanguage, not app $appLanguage',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        Future<void> waitForCatalog() async {
          await tester.runAsync(() async {
            await tester
                .widget<RawAutocomplete<String>>(
                  find.byType(RawAutocomplete<String>),
                )
                .optionsBuilder(TextEditingValue.empty);
          });
          await tester.pumpAndSettle();
        }

        Widget country(String ui, String writing) => MaterialApp(
          locale: Locale(ui),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CountryAutocomplete(
              controller: controller,
              language: writing,
              uiLanguage: ui,
              onChanged: (_) {},
              hint: writing == 'ar' ? 'الدولة' : 'Country',
              clearLabel: ui == 'ar' ? 'مسح الحقل' : 'Clear field',
            ),
          ),
        );
        await tester.pumpWidget(country(appLanguage, resumeLanguage));
        await waitForCatalog();
        final expected = resumeLanguage == 'ar' ? 'مصر' : 'Egypt';
        final query = resumeLanguage == 'ar' ? 'مص' : 'Egy';
        expect(
          await tester
              .widget<RawAutocomplete<String>>(
                find.byType(RawAutocomplete<String>),
              )
              .optionsBuilder(TextEditingValue(text: query)),
          contains(expected),
          reason: 'Bundled country data must be loaded before suggesting.',
        );
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), query);
        await tester.pumpAndSettle();
        await tester.tap(find.text(expected));
        await tester.pumpAndSettle();
        expect(controller.text, expected);
        await tester.pumpWidget(country(resumeLanguage, resumeLanguage));
        await waitForCatalog();
        expect(
          controller.text,
          expected,
        ); // App-language switching never translates data.
        await tester.pumpWidget(country(resumeLanguage, appLanguage));
        await waitForCatalog();
        expect(
          controller.text,
          expected,
        ); // Resume-language switching changes suggestions only.
        await tester.enterText(
          find.byType(TextField),
          appLanguage == 'ar' ? 'مص' : 'Egy',
        );
        await tester.pumpAndSettle();
        expect(
          find.text(appLanguage == 'ar' ? 'مصر' : 'Egypt'),
          findsOneWidget,
        );
      },
    );
    testWidgets(
      'education autofill uses Resume $resumeLanguage, not app $appLanguage',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        Widget education(String ui, String writing) => MaterialApp(
          locale: Locale(ui),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EducationAutocompleteField(
              controller: controller,
              label: ui == 'ar' ? 'الجامعة' : 'University',
              hint: writing == 'ar' ? 'اكتب جامعتك' : 'Your university',
              language: writing,
              suggestions: const [
                EducationSuggestion(
                  nameEn: 'Cairo University',
                  nameAr: 'جامعة القاهرة',
                ),
              ],
              onChanged: (_) {},
              clearLabel: ui == 'ar' ? 'مسح الحقل' : 'Clear field',
            ),
          ),
        );
        await tester.pumpWidget(education(appLanguage, resumeLanguage));
        await tester.enterText(find.byType(TextField), 'cairo');
        await tester.pumpAndSettle();
        final expected = resumeLanguage == 'ar'
            ? 'جامعة القاهرة'
            : 'Cairo University';
        await tester.tap(find.text(expected));
        await tester.pumpAndSettle();
        expect(controller.text, expected);
        await tester.pumpWidget(education(resumeLanguage, resumeLanguage));
        await tester.pumpAndSettle();
        expect(controller.text, expected);
        await tester.pumpWidget(education(resumeLanguage, appLanguage));
        await tester.pumpAndSettle();
        expect(controller.text, expected);
      },
    );
  }
  for (final language in ['en', 'ar']) {
    testWidgets(
      'summary samples are read-only, bounded, and explicit $language',
      (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        var changes = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SummaryExamplesButton(
                controller: controller,
                enabled: true,
                onChanged: (_) => changes++,
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('explore-summary-examples')));
        await tester.pumpAndSettle();
        final ar = language == 'ar';
        final previous = find.byKey(const Key('summary-example-previous'));
        final next = find.byKey(const Key('summary-example-next'));
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: previous, matching: find.byType(Icon)),
              )
              .icon,
          ar ? Icons.chevron_right : Icons.chevron_left,
        );
        expect(tester.widget<IconButton>(previous).onPressed, isNull);
        for (var index = 0; index < 6; index++) {
          expect(
            find.text(
              (ar
                  ? summaryExampleCategoriesArabic
                  : summaryExampleCategoriesEnglish)[index],
            ),
            findsOneWidget,
          );
          final field = tester.widget<TextFormField>(
            find.byKey(ValueKey('summary-example-$index')),
          );
          expect(
            field.initialValue,
            (ar ? summaryExamplesArabic : summaryExamplesEnglish)[index],
          );
          expect(
            tester
                .widget<TextField>(
                  find.descendant(
                    of: find.byKey(ValueKey('summary-example-$index')),
                    matching: find.byType(TextField),
                  ),
                )
                .readOnly,
            isTrue,
          );
          if (index < 5) {
            await tester.tap(next);
            await tester.pumpAndSettle();
          }
        }
        expect(tester.widget<IconButton>(next).onPressed, isNull);
        expect(changes, 0);
        expect(controller.text, isEmpty);
        await tester.tap(find.byKey(const Key('use-summary-example')));
        await tester.pumpAndSettle();
        expect(
          controller.text,
          (ar ? summaryExamplesArabic : summaryExamplesEnglish).last,
        );
        expect(changes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('replacing a written summary requires explicit confirmation', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'My current writing');
    addTearDown(controller.dispose);
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryExamplesButton(
            controller: controller,
            enabled: true,
            onChanged: (_) => changes++,
          ),
        ),
      ),
    );
    Future<void> choose() async {
      await tester.tap(find.byKey(const Key('explore-summary-examples')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('use-summary-example')));
      await tester.pumpAndSettle();
    }

    await choose();
    await tester.tap(find.text('Keep current text'));
    await tester.pumpAndSettle();
    expect(controller.text, 'My current writing');
    expect(changes, 0);
    await choose();
    await tester.tap(find.text('Replace summary'));
    await tester.pumpAndSettle();
    expect(controller.text, summaryExamplesEnglish.first);
    expect(changes, 1);
  });

  testWidgets('career guidance stays compact and expands individual FAQs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const TextField(key: Key('editable-field')),
                const SectionWritingGuidance(
                  section: EntitySection.certification,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Example on a Resume'), findsNothing);
    expect(find.text('Optional questions and examples'), findsNothing);
    await tester.tap(find.text('Tips to help you present your certifications'));
    await tester.pumpAndSettle();
    expect(
      find.text('Which certification did you receive, and who issued it?'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('editable-field')))
          .controller,
      isNull,
    );
  });

  testWidgets('discard confirmation defaults to keeping a saved Draft', (
    tester,
  ) async {
    bool? decision;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  decision = await confirmDiscardDraft(context),
              child: const Text('Open discard'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open discard'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This draft will be permanently removed. This action cannot be undone.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Keep draft'));
    await tester.pumpAndSettle();
    expect(decision, isFalse);
    await tester.tap(find.text('Open discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-discard-draft')));
    await tester.pumpAndSettle();
    expect(decision, isTrue);
  });
}
