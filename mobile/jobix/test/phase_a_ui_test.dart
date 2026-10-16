import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/features/builder/builder_scaffold.dart';
import 'package:jobix/features/builder/ai_allowance.dart';
import 'package:jobix/features/builder/jobix_improvement.dart';
import 'package:jobix/features/builder/month_input_formatter.dart';
import 'package:jobix/features/builder/section_writing_guidance.dart';
import 'package:jobix/features/career_profile/summary_writing_hints.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:jobix/features/personal_information/country_autocomplete.dart';
import 'package:jobix/features/personal_information/personal_information_fields.dart';
import 'package:jobix/l10n/app_localizations.dart';
import 'support/production_fonts.dart';

Widget app(Widget child, {String locale = 'en'}) => ProviderScope(
  overrides: [
    aiAllowanceProvider.overrideWith(
      (_) async => throw StateError('Allowance unavailable'),
    ),
  ],
  child: MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: foundationTheme(languageCode: locale),
    home: child,
  ),
);

void main() {
  setUpAll(loadProductionFonts);
  test(
    'numeric month mask supports typing, pasted dates, Arabic digits and deletion',
    () {
      const formatter = MonthInputFormatter();
      TextEditingValue format(String text) => formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
      expect(format('202403').text, '2024-03');
      expect(format('2024-03').text, '2024-03');
      expect(format('٢٠٢٤٠٣').text, '2024-03');
      expect(format('202').text, '202');
      expect(format('').text, '');
      expect(format('202403998').text, '2024-03');
      final old = format('202403');
      final deleted = formatter.formatEditUpdate(
        old,
        const TextEditingValue(
          text: '2024-0',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(deleted.text, '2024-0');
      expect(deleted.selection.extentOffset, 6);
    },
  );

  for (final locale in ['en', 'ar']) {
    testWidgets('$locale first and final steps omit all Back controls', (
      tester,
    ) async {
      for (final step in [1, 6]) {
        await tester.pumpWidget(
          app(
            BuilderScaffold(
              step: step,
              onBack: () {},
              onContinue: () {},
              child: const Text('Content'),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('builder-back')), findsNothing);
        expect(find.byType(BackButtonIcon), findsNothing);
        expect(find.byKey(const Key('builder-progress')), findsOneWidget);
      }
    });

    testWidgets(
      '$locale Review-origin uses Save and Back to Review, not builder progress',
      (tester) async {
        var returned = false;
        await tester.pumpWidget(
          app(
            BuilderScaffold(
              step: 3,
              reviewEditor: true,
              onBack: () {},
              onContinue: () => returned = true,
              child: const Text('Content'),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final copy = AppLocalizations.of(
          tester.element(find.byType(Scaffold)),
        )!;
        expect(find.text(copy.saveAction), findsOneWidget);
        expect(find.text(copy.backToReview), findsOneWidget);
        expect(find.byKey(const Key('builder-progress')), findsNothing);
        await tester.tap(find.byKey(const Key('builder-continue')));
        expect(returned, true);
      },
    );

    testWidgets('$locale six expandable hints do not insert sample content', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: SingleChildScrollView(child: SummaryWritingHints()),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsNWidgets(6));
      expect(find.byType(TextField), findsNothing);
      final last = find.byKey(const Key('summary-hint-5'));
      await tester.ensureVisible(last);
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(locale == 'ar' ? 'مثال:' : 'For example:'),
        findsOneWidget,
      );
    });

    testWidgets('$locale section prompts are display-only', (tester) async {
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: SingleChildScrollView(
              child: SectionWritingGuidance(section: EntitySection.experience),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('section-writing-guidance')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        find.textContaining(
          locale == 'ar' ? 'ما دورك وما مسؤولياتك؟' : 'What was your role',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(locale == 'ar' ? 'مثال:' : 'For example:'),
        findsWidgets,
      );
      expect(
        find.textContaining(
          locale == 'ar' ? 'لا يُضاف إلى ملفك' : 'not added to your profile',
        ),
        findsNothing,
      );
    });

    testWidgets(
      '$locale AI unavailable never shows fabricated counts or results',
      (tester) async {
        await tester.pumpWidget(
          app(
            const Scaffold(
              body: Column(
                children: [
                  JobixAllowance(),
                  JobixImprovement(original: 'My own text'),
                ],
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('jobix-generate')),
        );
        expect(button.onPressed, isNull);
        expect(find.textContaining('0 / 6'), findsNothing);
        expect(find.textContaining('94%'), findsNothing);
        expect(find.byType(SegmentedButton<bool>), findsNothing);
      },
    );

    testWidgets('$locale country suggestions use selected CV language', (
      tester,
    ) async {
      final controller = TextEditingController();
      String? selected;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: CountryAutocomplete(
              controller: controller,
              language: locale,
              hint: 'Country',
              clearLabel: 'Clear',
              onChanged: (value) => selected = value,
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      final query = locale == 'ar' ? 'مصر' : 'Egypt';
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('personal-country')))
            .decoration!
            .prefixIcon,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('personal-country')), query);
      await tester.pumpAndSettle();
      expect(find.text(query), findsWidgets);
      await tester.tap(find.widgetWithText(ListTile, query));
      await tester.pumpAndSettle();
      expect(selected, query);
      expect(controller.text, query);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets('proposal stays separate; acceptance is explicit', (
    tester,
  ) async {
    String? accepted;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: JobixImprovement(
            original: 'Original factual text',
            proposal: 'Server proposal',
            onAccept: (value) => accepted = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(accepted, isNull);
    expect(find.text('Server proposal'), findsOneWidget);
    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    expect(find.text('Original factual text'), findsOneWidget);
    expect(accepted, isNull);
    await tester.tap(find.text('Use This'));
    expect(accepted, 'Server proposal');
  });

  testWidgets(
    'email is editable; validation callback waits for blur or submit',
    (tester) async {
      final controllers = {
        for (final name in [
          'full_name',
          'email',
          'phone',
          'country',
          'city',
          'linkedin_url',
          'github_url',
          'portfolio_url',
        ])
          name: TextEditingController(),
      };
      controllers['email']!.text = 'account@example.com';
      final blurred = <String>[];
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: Builder(
                builder: (context) => PersonalInformationFields(
                  copy: AppLocalizations.of(context)!,
                  clearLabel: 'Clear field',
                  language: 'en',
                  controllers: controllers,
                  errors: const {},
                  regionEgypt: false,
                  cityHistory: const [],
                  onChanged: (_, _) {},
                  onBlur: blurred.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('personal-city')))
            .decoration!
            .prefixIcon,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('personal-email')),
        'invalid-email',
      );
      expect(controllers['email']!.text, 'invalid-email');
      expect(blurred.contains('email'), false);
      await tester.tap(find.byKey(const Key('personal-full_name')));
      await tester.pumpAndSettle();
      expect(blurred.contains('email'), true);
      await tester.pumpWidget(const SizedBox());
      for (final controller in controllers.values) {
        controller.dispose();
      }
    },
  );
}
