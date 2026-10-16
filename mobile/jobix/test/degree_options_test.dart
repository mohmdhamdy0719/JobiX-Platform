import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/builder/entity_labels.dart';

void main() {
  test('degree choices use stable values and localized labels', () {
    expect(degreeOption(''), isEmpty);
    expect(degreeOption('degree:bachelor'), 'degree:bachelor');
    expect(degreeOption("Bachelor's degree"), 'degree:bachelor');
    expect(degreeLabel('degree:bachelor', 'en'), "Bachelor's Degree");
    expect(degreeLabel('degree:bachelor', 'ar'), 'درجة البكالوريوس');
  });

  test('legacy free text remains available through Other', () {
    expect(degreeOption('BSc in Applied Chemistry'), 'degree:other');
    expect(
      degreeLabel('other:BSc in Applied Chemistry', 'ar'),
      'BSc in Applied Chemistry',
    );
  });
}
