import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';

class SummaryWritingHints extends StatelessWidget {
  const SummaryWritingHints({this.resumeLanguage, super.key});
  final String? resumeLanguage;
  @override
  Widget build(BuildContext context) {
    final ar = AppLocalizations.of(context)!.localeName.startsWith('ar');
    final contentArabic = (resumeLanguage ?? (ar ? 'ar' : 'en')) == 'ar';
    const examples = [
      [
        'What kind of work do you do, or what role are you targeting?',
        'ما طبيعة عملك، أو ما الدور الذي تستهدفه؟',
        'Customer service professional with experience supporting customers, resolving issues, and maintaining positive customer relationships.',
        'متخصص في خدمة العملاء لديه خبرة في دعم العملاء وحل المشكلات وبناء علاقات إيجابية معهم.',
      ],
      [
        'What are your strongest relevant skills?',
        'ما أبرز مهاراتك المرتبطة بالدور؟',
        'Skilled in communication, problem-solving, CRM systems, and handling customer inquiries efficiently.',
        'أجيد التواصل وحل المشكلات واستخدام أنظمة إدارة علاقات العملاء والتعامل بكفاءة مع استفساراتهم.',
      ],
      [
        'What relevant experience or achievement demonstrates your value?',
        'ما الخبرة أو الإنجاز الذي يوضح القيمة التي تقدمها؟',
        'Experienced in managing high volumes of customer requests while maintaining service quality and accurate records.',
        'لدي خبرة في التعامل مع أعداد كبيرة من طلبات العملاء مع الحفاظ على جودة الخدمة ودقة السجلات.',
      ],
      [
        'What value can you bring to your next role?',
        'ما القيمة التي يمكنك إضافتها في دورك المقبل؟',
        'Focused on delivering reliable customer support, improving customer satisfaction, and helping teams resolve issues efficiently.',
        'أركز على تقديم دعم موثوق للعملاء وتحسين رضاهم ومساعدة الفرق على حل المشكلات بكفاءة.',
      ],
    ];
    return ExpansionTile(
      key: const Key('summary-writing-guidance'),
      tilePadding: EdgeInsets.zero,
      title: Text(
        ar
            ? 'نصائح لكتابة ملخص مهني'
            : 'Tips to help you write a professional summary',
      ),
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
              title: Text(
                examples[i][contentArabic ? 1 : 0],
                textDirection: contentArabic
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(TokensV0.space12),
                  child: Text(
                    '${contentArabic ? 'مثال:' : 'For example:'} ${examples[i][contentArabic ? 3 : 2]}',
                    textDirection: contentArabic
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
