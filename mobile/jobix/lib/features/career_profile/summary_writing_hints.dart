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
        'I work in [your field], with experience in [your actual responsibilities].',
        'أعمل في [مجالك]، ولدي خبرة في [مسؤولياتك الفعلية].',
      ],
      [
        'What are your strongest skills?',
        'ما أبرز مهاراتك؟',
        'My strengths include [your skills] and [a relevant example from your work].',
        'تشمل نقاط قوتي [مهاراتك] و[مثالًا مرتبطًا بعملك].',
      ],
      [
        'What type of work do you specialize in?',
        'في أي نوع من العمل تتخصص؟',
        'I focus on [your specialty] using [tools you actually use].',
        'أركز على [تخصصك] باستخدام [أدوات تستخدمها بالفعل].',
      ],
      [
        'What are you currently looking for?',
        'ما الذي تبحث عنه حاليًا؟',
        'I am looking for [your target opportunity] where I can contribute [your strengths].',
        'أبحث عن [فرصتك المستهدفة] حيث يمكنني تقديم [نقاط قوتك].',
      ],
      [
        'What makes you valuable in your field?',
        'ما الذي يميزك في مجالك؟',
        'I bring [your relevant experience] and [an achievement you can substantiate].',
        'أقدم [خبرتك ذات الصلة] و[إنجازًا يمكنك إثباته].',
      ],
    ];
    return Column(
      children: [
        for (var i = 0; i < examples.length; i++)
          ExpansionTile(
            key: Key('summary-hint-$i'),
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
