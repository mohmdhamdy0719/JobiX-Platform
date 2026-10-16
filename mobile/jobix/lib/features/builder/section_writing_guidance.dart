import 'package:flutter/material.dart';

import '../career_profile/profile_sections.dart';

/// Optional, fictional prompts. The examples are display-only and never enter
/// an editor value or a saved profile.
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
        'What measurable results did you achieve?',
        'ما النتائج القابلة للقياس التي حققتها؟',
        'Reduced report preparation time by 30%.',
        'تقليل وقت إعداد التقارير بنسبة ٣٠٪.',
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
        'Used SQL and Python to reduce manual data preparation.',
        'استخدام SQL وPython لتقليل تجهيز البيانات يدويًا.',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final prompts = _prompts[section];
    if (prompts == null) return const SizedBox.shrink();
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return ExpansionTile(
      key: const Key('section-writing-guidance'),
      tilePadding: EdgeInsets.zero,
      title: Text(arabic ? 'أفكار اختيارية للكتابة' : 'Writing prompts'),
      children: [
        for (var i = 0; i < prompts.length; i++)
          ListTile(
            key: Key('section-writing-prompt-$i'),
            dense: true,
            title: Text(arabic ? prompts[i].$2 : prompts[i].$1),
            subtitle: Text(
              '${arabic ? 'مثال:' : 'For example:'} ${arabic ? prompts[i].$4 : prompts[i].$3}',
            ),
          ),
      ],
    );
  }
}
