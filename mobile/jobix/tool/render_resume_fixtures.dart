// Offline fixtures only: no app services, credentials or live user data.
import 'dart:convert';
import 'dart:io';

import '../lib/features/career_profile/career_profile.dart';
import '../lib/features/resume/resume_render.dart';

void main(List<String> arguments) {
  final regression = arguments.length == 2 && arguments.last == '--regression';
  if (arguments.length != 1 && !regression) {
    throw ArgumentError('Supply an output directory for canonical fixtures');
  }
  final output = Directory(arguments.first)..createSync(recursive: true);
  final manifest = <Map<String, dynamic>>[];
  final latin = base64Encode(File('assets/fonts/Inter.ttf').readAsBytesSync());
  final arabic = base64Encode(
    File('assets/fonts/IBMPlexSansArabic-Regular.ttf').readAsBytesSync(),
  );
  for (final language in ['en', 'ar']) {
    final ar = language == 'ar';
    final cases = [
      (name: 'short', long: false, count: 1, lines: 2, boundary: false),
      (name: 'long', long: true, count: 8, lines: 12, boundary: false),
      if (regression)
        for (final lines in [6, 8, 10, 12])
          (
            name: 'boundary-$lines',
            long: true,
            count: 2,
            lines: lines,
            boundary: true,
          ),
    ];
    for (final fixture in cases) {
      final long = fixture.long;
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
          for (var i = 0; i < fixture.count; i++)
            {
              'id': 'paid-$i',
              'job_title': ar ? 'منسق فريق $i' : 'Team Coordinator $i',
              'company': ar ? 'مؤسسة تجريبية $i' : 'Sample Company $i',
              'start_month': '2023-01',
              'end_month': '2024-06',
              'description': List.generate(
                fixture.lines,
                (j) => ar
                    ? '- سطر اختبار ${i}_$j: تنظيم العمل مع الفريق وتوثيق الأنشطة والنتائج بشكل واضح ومراجعة التفاصيل.${regression ? ' JXR${String.fromCharCode(65 + i)}L${String.fromCharCode(65 + j)}' : ''}'
                    : '- Fixture line ${i}_$j: Coordinated team activities and documented outcomes with clear detail for review.${regression ? ' JXR${String.fromCharCode(65 + i)}L${String.fromCharCode(65 + j)}' : ''}',
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
      if (fixture.boundary) {
        // Legal synthetic inputs move section/entry starts through several
        // page offsets. No artificial spacers or modified print stylesheet.
        source['summary'] =
            '${source['summary']}\n\n'
            '${ar ? '1. فقرة مرقمة وليست قائمة' : '1. Numbered prose is not a list'}\n'
            '${ar ? 'نص مختلط' : 'Mixed text'}: SQL / العربية / R&D <example> "quotes".';
        source['education'] = [
          {
            'id': 'education-only',
            'degree': ar ? 'دبلوم تجريبي' : 'Sample Diploma',
            'institution': ar ? 'معهد تجريبي' : 'Sample Institute',
            'field_of_study': ar ? 'تنسيق المشروعات' : 'Project Coordination',
            'start_month': '2018-01',
            'end_month': '2022-06',
            'description': ar
                ? 'فقرة تعليمية محفوظة.\n- مشروع تعليمي موثق'
                : 'Preserved education paragraph.\n- Documented learning project',
          },
        ];
        source['projects'] = [
          {
            'id': 'project-only',
            'name': ar ? 'مشروع تجريبي' : 'Sample Project',
            'role': ar ? 'منسق المشروع' : 'Project Facilitator',
            'project_month': '2024-08',
            'description': ar
                ? 'فقرة مشروع محفوظة.\n• نتيجة موثقة\n\nفقرة أخيرة.'
                : 'Preserved project paragraph.\n• Documented result\n\nFinal paragraph.',
          },
        ];
      }
      if (regression && ar && (fixture.name == 'short' || fixture.boundary)) {
        // Joined forms, lam-alef, tashkeel, Arabic punctuation and LTR islands.
        // These are synthetic content only; the canonical renderer is unchanged.
        source['summary'] =
            '${source['summary']}\n'
            'لَا إِلٰهَ؛ مُنَسِّقٌ يَتَعَلَّمُ بِجِدٍّ، شُؤُون الفريق؟ '
            '(SQL / C++ / R&D) — 2024-06: «نصّ مُختلط».';
      }
      final profile = CareerProfile.fromJson(source);
      for (final item in profile.items.values.expand((items) => items)) {
        if (item.problems().isNotEmpty) {
          throw StateError('Invalid synthetic ${fixture.name} fixture');
        }
      }
      final html = ResumeRender.html(
        profile: profile,
        language: language,
        latinFontBase64: latin,
        arabicFontBase64: arabic,
      );
      final name = '$language-${fixture.name}';
      File('${output.path}/$name.html').writeAsStringSync(html);
      manifest.add({
        'file': '$name.html',
        'language': language,
        'case': fixture.name,
        'source': source,
        'model_version': ResumeRender.modelVersion,
        'template_version': ResumeRender.templateVersion,
      });
      if (regression) continue;
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
  File('${output.path}/manifest.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
  stdout.writeln(
    regression
        ? 'Wrote canonical EN/AR regression fixtures and source manifest.'
        : 'Wrote canonical EN/AR fixtures and header comparisons.',
  );
}
