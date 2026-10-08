import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:jobix/features/builder/builder_scaffold.dart';
import 'package:jobix/features/builder/builder_steps_page.dart';
import 'package:jobix/features/builder/entity_labels.dart';
import 'package:jobix/features/builder/entity_editor_page.dart';
import 'package:jobix/features/builder/profile_overview.dart';
import 'package:jobix/features/resume/resume_render.dart';

ProfileItem volunteer({String description = '', bool current = true}) =>
    ProfileItem(
      id: 'volunteer-one',
      section: EntitySection.volunteer,
      values: {
        'organization': ' Community Group ',
        'role': ' Coordinator ',
        'location': 'Sample City',
        'start_month': '2024-01',
        'end_month': current ? 'stale' : '2024-12',
        'is_current': current,
        'description': description,
      },
    );

void main() {
  test('Volunteer is a distinct typed section within the six-step builder', () {
    expect(builderSteps, 6);
    expect(stepFor(EntitySection.volunteer), 3);
    expect(stepSections[3], [
      EntitySection.experience,
      EntitySection.volunteer,
    ]);
    expect(itemTitle(volunteer()), ' Coordinator ');
    for (final origin in EditorOrigin.values) {
      expect(editorReturn(EntitySection.volunteer, origin), switch (origin) {
        EditorOrigin.builder => '/builder/3',
        EditorOrigin.career => '/career',
        EditorOrigin.review => '/builder/6',
      });
    }
  });
  test(
    'structure is required, descriptions optional, current clears stale end',
    () {
      final item = volunteer();
      expect(item.problems(), isEmpty);
      expect(item.payload()['organization'], 'Community Group');
      expect(item.payload()['end_month'], isNull);
      expect(item.needsAttention, false);
      expect(item.copyWith('description', 'Short').problems(), isEmpty);
      expect(item.copyWith('description', 'Short').needsAttention, true);
      expect(item.copyWith('description', '   ').needsAttention, false);
      expect(
        item.copyWith('organization', '').problems()['organization'],
        FieldProblem.required,
      );
      expect(
        item.copyWith('role', '').problems()['role'],
        FieldProblem.required,
      );
      expect(
        item.copyWith('start_month', '0000-01').problems()['start_month'],
        FieldProblem.invalidMonth,
      );
      expect(
        item
            .copyWith('is_current', false)
            .copyWith('end_month', '')
            .problems()['end_month'],
        FieldProblem.required,
      );
      expect(
        item
            .copyWith('is_current', false)
            .copyWith('end_month', '2023-01')
            .problems()['end_month'],
        FieldProblem.endBeforeStart,
      );
      expect(
        item.copyWith('description', 'x' * 1501).problems()['description'],
        FieldProblem.tooLong,
      );
      expect(item.copyWith('organization', '🙂' * 200).problems(), isEmpty);
      expect(
        item.copyWith('organization', '🙂' * 201).problems()['organization'],
        FieldProblem.tooLong,
      );
    },
  );
  test('typed evidence survives snapshots without changing scored status', () {
    final old = CareerProfile(
      id: 'p',
      version: 3,
      completeness: 45,
      algorithm: 'core-profile-v2',
    );
    final withVolunteer = CareerProfile.fromJson({
      ...old.toJson(),
      'volunteer_experiences': [
        {
          ...volunteer(
            description: 'Enough meaningful descriptive detail.',
          ).toJson(),
          'complete': true,
        },
        volunteer(description: 'Short').toJson(),
      ],
    });
    expect(withVolunteer.count(EntitySection.volunteer), 2);
    expect(withVolunteer.completeCount(EntitySection.volunteer), 0);
    expect(
      volunteer(
        description: 'Enough meaningful descriptive detail.',
      ).locallyComplete,
      false,
    );
    expect(withVolunteer.completeness, old.completeness);
    expect(withVolunteer.algorithm, old.algorithm);
    expect(sectionsRemaining(withVolunteer), sectionsRemaining(old));
    expect(nextBuilderStep(withVolunteer), nextBuilderStep(old));
    expect(
      CareerProfile.fromJson(
        jsonDecode(withVolunteer.encode()),
      ).count(EntitySection.volunteer),
      2,
    );
    expect(
      CareerProfile.fromJson(old.toJson()).count(EntitySection.volunteer),
      0,
    );
  });
  for (final language in ['en', 'ar']) {
    test('canonical $language document separates Volunteer and compact skills', () {
      final profile = CareerProfile(
        id: 'p',
        version: 4,
        personal: const {'full_name': 'Sample <unsafe>'},
        items: {
          EntitySection.volunteer: [
            volunteer(
              description:
                  'An introduction.\n- First responsibility\n• Second responsibility\n\nClosing prose.\n-2024 is not a bullet\n1. Preserve authored numbering.',
            ),
          ],
          EntitySection.skill: [
            for (var i = 0; i < 30; i++)
              ProfileItem(
                id: '$i',
                section: EntitySection.skill,
                values: {'name': 'Full skill $i / SQL'},
              ),
          ],
        },
      );
      final html = ResumeRender.html(
        profile: profile,
        language: language,
        latinFontBase64: '',
        arabicFontBase64: '',
      );
      expect(
        html,
        contains(
          language == 'ar' ? 'الخبرات التطوعية' : 'Volunteer Experience',
        ),
      );
      expect(html, contains('<h3><bdi> Coordinator </bdi></h3>'));
      expect(html, contains('Community Group'));
      expect(
        html,
        contains(
          '<ul><li><bdi>First responsibility</bdi></li><li><bdi>Second responsibility</bdi></li></ul>',
        ),
      );
      expect(html, contains('<p class="blank"><br></p>'));
      expect(html, contains('<p><bdi>-2024 is not a bullet</bdi></p>'));
      expect(html, contains('1. Preserve authored numbering.'));
      expect(html, contains('<p class="skills">'));
      for (var i = 0; i < 30; i++) {
        expect(html, contains(const HtmlEscape().convert('Full skill $i / SQL')));
      }
      expect(RegExp('<article>').allMatches(html), hasLength(1));
      expect(html, contains('jobix-template-revision" content="2"'));
      expect(html, contains('resume_ats_${language}_v1'));
      expect(html, contains('&lt;unsafe&gt;'));
      expect(html, isNot(contains('<p><bdi></bdi></p>')));
      expect(html, isNot(contains('overflow:hidden')));
    });
  }
}
