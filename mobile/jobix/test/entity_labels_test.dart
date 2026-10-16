import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/builder/entity_labels.dart';

void main() {
  test('month labels tolerate invalid and incomplete persisted drafts', () {
    for (final locale in ['en', 'ar']) {
      for (final value in [
        '',
        '2024-',
        '2024-0',
        '2024-00',
        '2024-13',
        '2024-99',
      ]) {
        expect(monthLabel(value, locale), value);
      }
    }
    expect(monthLabel('2024-01', 'en'), 'Jan 2024');
    expect(monthLabel('2024-12', 'en'), 'Dec 2024');
    expect(monthLabel('2024-01', 'ar'), 'يناير 2024');
    expect(monthLabel('2024-12', 'ar'), 'ديسمبر 2024');
  });

  test('degree options have stable distinct choices and legacy rendering', () {
    expect(degreeCodes, [
      'degree:secondary_school_certificate',
      'degree:high_school',
      'degree:vocational_certificate',
      'degree:vocational_diploma',
      'degree:professional_certificate',
      'degree:certificate',
      'degree:diploma',
      'degree:associate',
      'degree:foundation',
      'degree:bachelor',
      'degree:graduate_certificate',
      'degree:postgraduate_diploma',
      'degree:master',
      'degree:professional_doctorate',
      'degree:doctorate_phd',
      'degree:other',
    ]);
    expect(degreeOption('degree:doctorate'), 'degree:doctorate_phd');
    expect(degreeLabel('degree:doctorate', 'en'), 'Doctorate / PhD');
    expect(
      degreeChoiceLabel('degree:secondary_school_certificate', 'ar'),
      'شهادة المرحلة الثانوية',
    );
    expect(degreeOption('Other:Certified Specialist'), 'degree:other');
  });
}
