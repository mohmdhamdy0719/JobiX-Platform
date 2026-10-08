// Offline fixtures only: no app services, credentials or live user data.
import 'dart:convert';
import 'dart:io';

import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/resume/resume_render.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    throw ArgumentError('Supply an output directory for canonical fixtures');
  }
  final output = Directory(arguments.single)..createSync(recursive: true);
  final latin = base64Encode(File('assets/fonts/Inter.ttf').readAsBytesSync());
  final arabic = base64Encode(
    File('assets/fonts/IBMPlexSansArabic-Regular.ttf').readAsBytesSync(),
  );
  for (final language in ['en', 'ar']) {
    final ar = language == 'ar';
    for (final long in [false, true]) {
      final source = <String, dynamic>{
        'profile_id': 'fixture-only',
        'profile_version': 7,
        'completeness_percent': 45,
        'completeness_algorithm_version': 'core-profile-v2',
        'personal': {
          'full_name': long
              ? ar
                    ? 'أحمد مثال — اسم متعدد المقاطع لاختبار التفاف النص ووضوح العنوان في السيرة الذاتية'
                    : 'Alex Sample With A Long Multi Part Professional Name For Layout Verification'
              : ar
              ? 'أحمد مثال — بيانات اختبار'
              : 'Alex Sample — Test Fixture',
          'email': long
              ? 'sample.contact.with.a.long.local.part.for.layout@example.invalid'
              : 'sample.long.contact@example.invalid',
          'phone': '+20 100 000 0000',
          'city': ar ? 'مدينة تجريبية' : 'Sample City',
          'country': ar ? 'بلد تجريبي' : 'Sample Country',
          'portfolio_url': long
              ? 'https://example.invalid/portfolio/${'section/' * 14}'
              : 'https://example.invalid/long/sample/portfolio',
        },
        'summary': ar
            ? 'هذا محتوى اختبار لعرض السيرة الذاتية وليس بيانات مستخدم حقيقي.\n- تنظيم الأنشطة مع الفريق\n• متابعة النتائج وتوثيقها'
            : 'This is test content, not a real user profile.\n- Coordinated activities with the team\n• Documented outcomes',
        'target_role': ar ? 'منسق مشروعات' : 'Project Coordinator',
        'experiences': [
          for (var i = 0; i < (long ? 8 : 1); i++)
            {
              'id': 'paid-$i',
              'job_title': ar ? 'منسق فريق $i' : 'Team Coordinator $i',
              'company': ar ? 'مؤسسة تجريبية $i' : 'Sample Company $i',
              'start_month': '2023-01',
              'end_month': '2024-06',
              'description': List.generate(
                long ? 12 : 2,
                (j) => ar
                    ? '- سطر اختبار ${i}_$j: تنظيم العمل مع الفريق وتوثيق الأنشطة والنتائج بشكل واضح ومراجعة التفاصيل.'
                    : '- Fixture line ${i}_$j: Coordinated team activities and documented outcomes with clear detail for review.',
              ).join('\n'),
            },
        ],
        'volunteer_experiences': [
          {
            'id': 'unpaid-1',
            'role': ar ? 'منسق متطوع' : 'Volunteer Coordinator',
            'organization': ar
                ? 'مجموعة مجتمعية تجريبية'
                : 'Sample Community Group',
            'location': ar ? 'مدينة تجريبية' : 'Sample City',
            'start_month': '2024-07',
            'is_current': true,
            'description': ar
                ? 'مقدمة كتبها صاحب السيرة.\n- تنسيق أنشطة المجتمع\n• توثيق المشاركة\n\nفقرة ختامية محفوظة.'
                : 'An authored introduction.\n- Coordinated community activities\n• Documented participation\n\nPreserved closing paragraph.',
          },
        ],
        'skills': [
          for (var i = 0; i < (long ? 30 : 8); i++)
            {
              'id': 'skill-$i',
              'name': ar ? 'مهارة اختبار $i / SQL' : 'Sample Skill $i / SQL',
            },
        ],
      };
      final html = ResumeRender.html(
        profile: CareerProfile.fromJson(source),
        language: language,
        latinFontBase64: latin,
        arabicFontBase64: arabic,
      );
      final name = '$language-${long ? 'long' : 'short'}';
      File('${output.path}/$name.html').writeAsStringSync(html);
      // Comparison only, never loaded by the app or a separate renderer.
      File('${output.path}/$name-centered-comparison.html').writeAsStringSync(
        html.replaceFirst(
          '</style>',
          'body > h1, body > .contact, body > .contact + p, '
              '.personal-header {text-align:center}</style>',
        ),
      );
      File(
        '${output.path}/$name-start-aligned-comparison.html',
      ).writeAsStringSync(
        html.replaceFirst(
          '</style>',
          '.personal-header {text-align:start}</style>',
        ),
      );
    }
  }
  stdout.writeln('Wrote canonical EN/AR fixtures and header comparisons.');
}
