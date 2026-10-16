import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';

class SummaryWritingHints extends StatelessWidget {
  const SummaryWritingHints({super.key});
  @override
  Widget build(BuildContext context) {
    final ar = AppLocalizations.of(context)!.localeName.startsWith('ar');
    const examples = [
      [
        'What is your professional background?',
        'ما خلفيتك المهنية؟',
        'Marketing specialist with 3 years of experience in digital campaigns and content creation.',
        'متخصص تسويق بخبرة ٣ سنوات في الحملات الرقمية وإنشاء المحتوى.',
      ],
      [
        'What are your strongest skills or areas of expertise?',
        'ما أبرز مهاراتك أو مجالات خبرتك؟',
        'SEO, campaign analytics, content planning, and stakeholder communication.',
        'تحسين محركات البحث، وتحليل الحملات، وتخطيط المحتوى، والتواصل مع أصحاب المصلحة.',
      ],
      [
        'What kind of work or problems do you solve best?',
        'ما نوع العمل أو المشكلات التي تجيد حلها؟',
        'Turning performance data into actionable campaign improvements.',
        'تحويل بيانات الأداء إلى تحسينات عملية للحملات.',
      ],
      [
        'What achievements or results are you most proud of?',
        'ما الإنجازات أو النتائج التي تفخر بها أكثر؟',
        'Increased organic traffic by 25% over 6 months.',
        'زيادة الزيارات الطبيعية بنسبة ٢٥٪ خلال ٦ أشهر.',
      ],
      [
        'What role are you targeting next?',
        'ما الدور الذي تستهدفه في خطوتك المقبلة؟',
        'A digital marketing role focused on growth and experimentation.',
        'دور في التسويق الرقمي يركز على النمو والتجربة.',
      ],
      [
        'What value would you bring to an employer or team?',
        'ما القيمة التي ستضيفها إلى جهة العمل أو الفريق؟',
        'Combining analytical thinking with clear communication to improve team outcomes.',
        'الجمع بين التفكير التحليلي والتواصل الواضح لتحسين نتائج الفريق.',
      ],
    ];
    return Wrap(
      runSpacing: TokensV0.space8,
      children: [
        for (var i = 0; i < examples.length; i++)
          SizedBox(
            width: double.infinity,
            child: ExpansionTile(
              key: Key('summary-hint-$i'),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: TokensV0.space12,
              ),
              collapsedBackgroundColor: TokensV0.surfaceCard,
              backgroundColor: TokensV0.surfaceContainerLow,
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TokensV0.cardRadius),
                side: const BorderSide(color: TokensV0.border),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TokensV0.cardRadius),
                side: const BorderSide(color: TokensV0.border),
              ),
              title: Text(examples[i][ar ? 1 : 0]),
              children: [
                Padding(
                  padding: const EdgeInsets.all(TokensV0.space12),
                  child: Text(
                    '${ar ? 'مثال:' : 'For example:'} ${examples[i][ar ? 3 : 2]}',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
