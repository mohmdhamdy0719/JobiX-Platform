// Standalone structural contract checks run without Flutter/package resolution.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';
import '../lib/features/career_profile/career_profile.dart';
import '../lib/features/resume/resume_document.dart';

void main() {
  Map<String, dynamic> source({
    String description = '',
    bool invalid = false,
  }) => {
    'profile_id': 'fixture',
    'profile_version': 1,
    'completeness_percent': 15,
    'personal': {
      'full_name': 'Fixture',
      'email': 'fixture@example.invalid',
      'phone': '+20 100 000 0000',
    },
    'volunteer_experiences': [
      {
        'id': 'unpaid',
        'organization': 'Community',
        'role': invalid ? '' : 'Helper',
        'start_month': '2025-01',
        'is_current': true,
        'description': description,
        'complete': false,
      },
    ],
  };
  void expect(bool condition) {
    if (!condition) throw StateError('FAILED structural export contract');
  }

  for (final language in ['en', 'ar']) {
    final config = ResumePresentation(language: language);
    for (final text in ['', 'Short']) {
      final p = CareerProfile.fromJson(source(description: text));
      expect(ResumeDocument.issues(p, config).isEmpty);
      expect(
        p.completeness == 15 &&
            p.items.values.expand((items) => items).single.complete == false,
      );
    }
    final invalid = CareerProfile.fromJson(source(invalid: true));
    expect(ResumeDocument.issues(invalid, config).contains('volunteer:unpaid'));
    final hidden = ResumePresentation(
      language: language,
      hidden: {'volunteer'},
    );
    expect(
      !ResumeDocument.issues(invalid, hidden).contains('volunteer:unpaid'),
    );
    expect(ResumeDocument.issues(invalid, hidden).contains('career_content'));
    final noContact = CareerProfile.fromJson({...source(), 'personal': {}});
    expect(ResumeDocument.issues(noContact, config).length == 3);
  }
  stdout.writeln(
    'PASS: EN/AR structural validity, unscored Volunteer, optional prose, explicit hiding and contact rules',
  );
}
