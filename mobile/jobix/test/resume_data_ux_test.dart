import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/builder/entity_cards.dart';
import 'package:jobix/features/builder/section_writing_guidance.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:jobix/features/career_profile/summary_examples.dart';
import 'package:jobix/l10n/app_localizations.dart';

void main() {
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
                const EntryResumeExample(section: EntitySection.experience),
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
    expect(find.text('Example on a Resume'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('entry-resume-example'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('editable-field'))).dy),
    );
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
