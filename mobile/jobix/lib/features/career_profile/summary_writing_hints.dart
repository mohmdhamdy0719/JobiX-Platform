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
        'Software engineer with 4 years of experience building mobile and web applications.',
        'مهندس برمجيات بخبرة 4 سنوات في تطوير تطبيقات الهاتف والويب.',
      ],
      [
        'What are your strongest skills or areas of expertise?',
        'ما أبرز مهاراتك أو مجالات خبرتك؟',
        'I specialize in Flutter, backend APIs, and building reliable user-focused products.',
        'أتخصص في Flutter وواجهات برمجة التطبيقات الخلفية، وفي بناء منتجات موثوقة تركز على المستخدم.',
      ],
      [
        'What type of work or problems are you best at solving?',
        'ما نوع العمل الذي تتقنه أو المشكلات التي تجيد حلها؟',
        'I enjoy turning complex business requirements into simple, scalable software.',
        'أستمتع بتحويل متطلبات العمل المعقدة إلى برمجيات بسيطة وقابلة للتوسع.',
      ],
      [
        'What are some achievements or results you are proud of?',
        'ما بعض الإنجازات أو النتائج التي تفخر بها؟',
        'I helped reduce application processing time by 30%.',
        'ساهمت في تقليل وقت معالجة الطلبات بنسبة 30%.',
      ],
      [
        'What type of role or work are you looking for next?',
        'ما نوع الدور أو العمل الذي تبحث عنه في خطوتك المقبلة؟',
        'I am looking for a product-focused software engineering role.',
        'أبحث عن دور في هندسة البرمجيات يركز على المنتج.',
      ],
      [
        'What makes you valuable to an employer or team?',
        'ما الذي يجعلك إضافة قيّمة لصاحب العمل أو الفريق؟',
        'I combine technical execution with strong communication and cross-functional collaboration.',
        'أجمع بين التنفيذ التقني والتواصل الفعّال والتعاون بين فرق متعددة التخصصات.',
      ],
    ];
    return Column(
      children: [
        for (var i = 0; i < examples.length; i++)
          ExpansionTile(
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
                padding: const EdgeInsets.all(TokensV0.space16),
                child: Text(
                  '${ar ? 'مثال إرشادي فقط — لا يُضاف إلى ملفك:' : 'Illustrative example only — not added to your profile:'}\n${examples[i][ar ? 3 : 2]}',
                ),
              ),
            ],
          ),
      ],
    );
  }
}
