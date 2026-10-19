import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/builder/education_catalog.dart';

void main() {
  group('education catalog search', () {
    test('matches institution by English alias and Arabic name', () {
      final byAlias = filterEducationSuggestions(
        commonInstitutionSuggestions,
        'Alex University',
      );
      expect(byAlias.single.nameEn, 'Alexandria University');

      final byArabic = filterEducationSuggestions(
        commonInstitutionSuggestions,
        'جامعة عين شمس',
      );
      expect(byArabic.single.nameEn, 'Ain Shams University');
    });

    test('normalizes Arabic alef/diacritics and bounds the result count', () {
      final source = [
        const EducationSuggestion(
          nameEn: 'Example University',
          nameAr: 'إِجَامعة',
        ),
        ...commonInstitutionSuggestions,
      ];
      expect(
        filterEducationSuggestions(source, 'اجامعة').first.nameEn,
        'Example University',
      );
      expect(
        filterEducationSuggestions(commonStudyFieldSuggestions, 'a', limit: 3),
        hasLength(3),
      );
    });

    test(
      'bilingual study aliases find the same field without requiring a pick',
      () {
        final byEnglish = filterEducationSuggestions(
          commonStudyFieldSuggestions,
          'accountancy',
        );
        final byArabic = filterEducationSuggestions(
          commonStudyFieldSuggestions,
          'المحاسبة',
        );
        expect(byEnglish.single.nameEn, 'Accounting');
        expect(byArabic.single.nameEn, 'Accounting');
      },
    );
  });

  testWidgets('selection and custom free text both remain editable', (
    tester,
  ) async {
    final controller = TextEditingController();
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: EducationAutocompleteField(
              fieldKey: const Key('institution-autocomplete'),
              controller: controller,
              label: 'Institution',
              hint: 'Type or enter your own',
              language: 'en',
              suggestions: commonInstitutionSuggestions,
              clearLabel: 'Clear',
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('institution-autocomplete')),
      'cairo',
    );
    await tester.pumpAndSettle();
    expect(find.text('Cairo University'), findsOneWidget);
    await tester.tap(find.text('Cairo University'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Cairo University');
    expect(changes.last, 'Cairo University');

    await tester.enterText(
      find.byKey(const Key('institution-autocomplete')),
      'My unlisted college',
    );
    await tester.pump();
    expect(controller.text, 'My unlisted college');
    expect(changes.last, 'My unlisted college');
  });

  testWidgets('Arabic field presents right-to-left text direction', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EducationAutocompleteField(
            controller: controller,
            label: 'المؤسسة التعليمية',
            hint: 'اكتب اسم المؤسسة',
            language: 'ar',
            suggestions: commonInstitutionSuggestions,
            clearLabel: 'مسح',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).textDirection,
      TextDirection.rtl,
    );
  });
}
