import 'package:flutter/material.dart';

import '../career_profile/profile_sections.dart';

/// Read-only Resume-format example and optional, truthful writing guidance.
class SectionWritingGuidance extends StatelessWidget {
  const SectionWritingGuidance({required this.section, super.key});

  final EntitySection section;

  static const _prompts = <EntitySection, List<(String, String, String, String)>>{
    EntitySection.experience: [
      (
        'What was your role and what were you responsible for?',
        'ما دورك وما مسؤولياتك؟',
        'Managed customer accounts and coordinated daily client requests.',
        'إدارة حسابات العملاء وتنسيق طلباتهم اليومية.',
      ),
      (
        'What were your main contributions?',
        'ما أبرز إسهاماتك؟',
        "Improved the team's reporting process and reduced repetitive manual work.",
        'تحسين آلية إعداد التقارير وتقليل العمل اليدوي المتكرر.',
      ),
      (
        'What changed because of your work?',
        'ما الذي تحسن نتيجة لعملك؟',
        'Describe a verified outcome, or focus on the work you contributed.',
        'اذكر نتيجة موثقة، أو ركّز على العمل الذي أسهمت فيه.',
      ),
    ],
    EntitySection.education: [
      (
        'What qualification did you earn, and in which field?',
        'ما المؤهل الذي حصلت عليه وفي أي مجال؟',
        "Bachelor's degree in Business Administration.",
        'درجة البكالوريوس في إدارة الأعمال.',
      ),
      (
        'Was there a relevant project, specialization, or academic achievement?',
        'هل أنجزت مشروعًا أو تخصصًا أو إنجازًا أكاديميًا ذا صلة؟',
        'Completed a research project on customer behavior and market segmentation.',
        'إنجاز مشروع بحثي حول سلوك العملاء وتقسيم السوق.',
      ),
    ],
    EntitySection.achievement: [
      (
        'What did you accomplish?',
        'ما الذي أنجزته؟',
        'Received an award for outstanding project delivery.',
        'الحصول على جائزة للتميز في تسليم مشروع.',
      ),
      (
        'Why was it important, or what was the result?',
        'لماذا كان ذلك مهمًا، أو ما النتيجة؟',
        'Recognized for completing a cross-functional project ahead of schedule.',
        'التقدير لإكمال مشروع مشترك بين الفرق قبل الموعد المحدد.',
      ),
      (
        'Is there a public link or evidence worth including?',
        'هل يوجد رابط عام أو دليل يستحق الإضافة؟',
        'A certificate, publication, award page, or portfolio URL.',
        'شهادة أو منشور أو صفحة جائزة أو رابط معرض أعمال.',
      ),
    ],
    EntitySection.certification: [
      (
        'Which certification did you receive, and who issued it?',
        'ما الشهادة التي حصلت عليها ومن أصدرها؟',
        'Use the certification name and issuing organization shown on your certificate.',
        'استخدم اسم الشهادة والجهة المانحة كما يظهران في شهادتك.',
      ),
      (
        'Which date or verification details are useful?',
        'ما التاريخ أو تفاصيل التحقق المفيدة؟',
        'Include the issue date, and a credential ID or verification link if available.',
        'أضف تاريخ الإصدار ورقم الاعتماد أو رابط التحقق إن توفرا.',
      ),
    ],
    EntitySection.volunteer: [
      (
        'What organization or cause did you support, and what was your role?',
        'ما المنظمة أو القضية التي دعمتها، وما دورك؟',
        'Volunteered with a local community initiative to coordinate donation drives.',
        'التطوع في مبادرة مجتمعية محلية لتنسيق حملات التبرع.',
      ),
      (
        'What did you contribute or accomplish?',
        'ماذا قدمت أو حققت؟',
        'Helped organize events and coordinate volunteers.',
        'المساعدة في تنظيم الفعاليات وتنسيق المتطوعين.',
      ),
    ],
    EntitySection.project: [
      (
        'What did you build or contribute?',
        'ماذا أنشأت أو أضفت إلى المشروع؟',
        'Built a reporting dashboard that brought weekly metrics into one view.',
        'إنشاء لوحة تقارير تجمع المؤشرات الأسبوعية في عرض واحد.',
      ),
      (
        'What tools did you use and what changed as a result?',
        'ما الأدوات التي استخدمتها وما النتيجة؟',
        'Name tools you actually used and describe how they supported your contribution.',
        'اذكر الأدوات التي استخدمتها بالفعل وكيف ساعدتك في إنجاز مساهمتك.',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final prompts = _prompts[section];
    if (prompts == null) return const SizedBox.shrink();
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final heading = _headings[section]!;
    return ExpansionTile(
      key: const Key('section-writing-guidance'),
      tilePadding: EdgeInsets.zero,
      title: Text(arabic ? heading.$2 : heading.$1),
      subtitle: Text(
        arabic ? 'أسئلة وإجابات اختيارية' : 'Optional questions and examples',
      ),
      children: [
        for (var i = 0; i < prompts.length; i++)
          ExpansionTile(
            key: Key('section-writing-prompt-$i'),
            tilePadding: const EdgeInsetsDirectional.only(start: 12, end: 8),
            title: Text(arabic ? prompts[i].$2 : prompts[i].$1),
            childrenPadding: const EdgeInsetsDirectional.fromSTEB(
              12,
              0,
              12,
              12,
            ),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${arabic ? 'مثال:' : 'Example:'} ${arabic ? prompts[i].$4 : prompts[i].$3}',
                ),
              ),
            ],
          ),
      ],
    );
  }

  static const _headings = <EntitySection, (String, String)>{
    EntitySection.experience: (
      'Tips to help you write a professional work experience',
      'نصائح لكتابة خبرتك المهنية',
    ),
    EntitySection.volunteer: (
      'Tips to help you describe your volunteer experience',
      'نصائح لوصف خبرتك التطوعية',
    ),
    EntitySection.education: (
      'Tips to help you present your education',
      'نصائح لعرض تعليمك',
    ),
    EntitySection.project: (
      'Tips to help you describe your projects',
      'نصائح لوصف مشاريعك',
    ),
    EntitySection.certification: (
      'Tips to help you present your certifications',
      'نصائح لعرض شهاداتك',
    ),
    EntitySection.achievement: (
      'Tips to help you describe your achievements',
      'نصائح لوصف إنجازاتك',
    ),
  };
}

class EntryResumeExample extends StatelessWidget {
  const EntryResumeExample({required this.section, super.key});
  final EntitySection section;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final List<String> example = switch (section) {
      EntitySection.experience =>
        ar
            ? [
                'أخصائي تسويق',
                'Jobix Company — الإسكندرية، مصر',
                'يوليو ٢٠٢٦ – حتى الآن',
              ]
            : [
                'Marketing Specialist',
                'Jobix Company — Alexandria, Egypt',
                'July 2026 – Present',
              ],
      EntitySection.volunteer =>
        ar
            ? [
                'منسق متطوعين',
                'مؤسسة مجتمعية — موقعك',
                'تاريخ البدء – تاريخ الانتهاء',
              ]
            : [
                'Volunteer Coordinator',
                'Community Organization — Your location',
                'Start date – End date',
              ],
      EntitySection.education =>
        ar
            ? [
                'بكالوريوس التجارة',
                'جامعة الإسكندرية — إدارة الأعمال',
                'سنة التخرج',
              ]
            : [
                'Bachelor of Commerce',
                'Alexandria University — Business Administration',
                'Graduation year',
              ],
      EntitySection.certification =>
        ar
            ? ['اسم الشهادة', 'الجهة المانحة', 'تاريخ الإصدار']
            : ['Certification name', 'Issuing organization', 'Issue date'],
      EntitySection.project =>
        ar
            ? ['عنوان المشروع', 'دورك في المشروع', 'وصف موجز لمساهمتك']
            : [
                'Project title',
                'Your role in the project',
                'A brief description of your contribution',
              ],
      EntitySection.achievement =>
        ar
            ? ['عنوان الإنجاز', 'الجهة أو السياق', 'التاريخ']
            : ['Achievement title', 'Organization or context', 'Date'],
      EntitySection.skill => ar ? ['المهارة'] : ['Skill'],
      EntitySection.language =>
        ar ? ['اللغة — المستوى'] : ['Language — proficiency'],
    };
    return Card(
      key: const Key('entry-resume-example'),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ar ? 'مثال على السيرة الذاتية' : 'Example on a Resume',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final line in example)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(line, style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
