import 'package:flutter/material.dart';

import '../../core/design/jobix_dialog.dart';
import '../../core/design/tokens.dart';

const summaryExamplesEnglish = <String>[
  'Results-oriented professional with experience supporting business operations, solving problems, and collaborating across teams. Skilled at organizing priorities, adapting to changing needs, and delivering reliable work. Committed to continuous learning and contributing to team and organizational goals.',
  'Motivated professional with a strong foundation in communication, organization, and problem-solving. Eager to apply existing skills, learn new processes, and contribute to meaningful projects. Known for a proactive attitude, attention to detail, and willingness to take on new challenges.',
  'Adaptable professional bringing transferable skills in communication, planning, analysis, and collaboration. Experienced in learning new processes, managing competing priorities, and approaching challenges with a practical mindset. Seeking to apply this background in a new professional environment while continuing to grow.',
  'Organized professional experienced in coordinating tasks, maintaining accurate information, and supporting efficient day-to-day operations. Strong at prioritization, follow-through, and communicating with different stakeholders. Focused on improving workflows, resolving issues, and helping teams achieve their objectives.',
  'Analytical and detail-oriented professional with strengths in evaluating information, identifying problems, and developing practical solutions. Comfortable learning new tools, working with structured information, and translating findings into clear next steps. Values accuracy, continuous improvement, and collaborative problem-solving.',
  'Collaborative professional with strong communication, relationship-building, and organizational skills. Experienced in coordinating with others, managing responsibilities, and adapting communication to different needs. Committed to dependable execution, constructive teamwork, and continuous professional development.',
];

const summaryExamplesArabic = <String>[
  'مهني يركز على تحقيق النتائج، ولديه خبرة في دعم العمليات وحل المشكلات والتعاون بين الفرق. يجيد ترتيب الأولويات والتكيف مع المتغيرات وإنجاز العمل بموثوقية. يحرص على التعلم المستمر والإسهام في تحقيق أهداف الفريق والمؤسسة.',
  'مهني طموح يمتلك أساسًا قويًا في التواصل والتنظيم وحل المشكلات. يتطلع إلى توظيف مهاراته الحالية وتعلم إجراءات جديدة والمساهمة في مشاريع مفيدة. يتميز بالمبادرة والانتباه للتفاصيل والاستعداد لخوض تحديات جديدة.',
  'مهني مرن يمتلك مهارات قابلة للنقل في التواصل والتخطيط والتحليل والتعاون. لديه خبرة في تعلم إجراءات جديدة وإدارة الأولويات المتنافسة والتعامل مع التحديات بأسلوب عملي. يتطلع إلى توظيف خبراته في بيئة مهنية جديدة ومواصلة التطور.',
  'مهني منظم لديه خبرة في تنسيق المهام والحفاظ على دقة المعلومات ودعم كفاءة العمليات اليومية. يجيد ترتيب الأولويات والمتابعة والتواصل مع مختلف الأطراف. يركز على تحسين سير العمل ومعالجة المشكلات ومساعدة الفرق على تحقيق أهدافها.',
  'مهني تحليلي ودقيق يمتلك قدرة على تقييم المعلومات وتحديد المشكلات واقتراح حلول عملية. يرتاح لتعلم أدوات جديدة والعمل مع المعلومات المنظمة وتحويل النتائج إلى خطوات واضحة. يقدّر الدقة والتحسين المستمر وحل المشكلات بالتعاون مع الآخرين.',
  'مهني متعاون يمتلك مهارات قوية في التواصل وبناء العلاقات والتنظيم. لديه خبرة في التنسيق مع الآخرين وإدارة المسؤوليات وتكييف التواصل مع الاحتياجات المختلفة. يحرص على الإنجاز الموثوق والعمل الجماعي البنّاء والتطور المهني المستمر.',
];

class SummaryExamplesButton extends StatelessWidget {
  const SummaryExamplesButton({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  Future<void> _open(BuildContext context) async {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final samples = ar ? summaryExamplesArabic : summaryExamplesEnglish;
    final readOnlyController = TextEditingController(text: samples.first);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var index = 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void showSample(int next) {
              setDialogState(() {
                index = next;
                readOnlyController.text = samples[index];
                readOnlyController.selection = const TextSelection.collapsed(
                  offset: 0,
                );
              });
            }

            return JobixAlertDialog(
              title: Text(
                ar ? 'أمثلة على الملخص المهني' : 'Professional Summary Examples',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const Key('summary-example-text'),
                      controller: readOnlyController,
                      readOnly: true,
                      minLines: 6,
                      maxLines: 12,
                      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(TokensV0.space12),
                      ),
                    ),
                    const SizedBox(height: TokensV0.space8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: ar ? 'السابق' : 'Previous example',
                          onPressed: index == 0
                              ? null
                              : () => showSample(index - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${index + 1} of ${samples.length}'),
                        IconButton(
                          tooltip: ar ? 'التالي' : 'Next example',
                          onPressed: index == samples.length - 1
                              ? null
                              : () => showSample(index + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                JobixDialogAction.secondary(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(ar ? 'إغلاق' : 'Close'),
                ),
                JobixDialogAction.primary(
                  key: const Key('use-summary-example'),
                  onPressed: () =>
                      Navigator.pop(dialogContext, samples[index]),
                  child: Text(ar ? 'استخدام هذا الملخص' : 'Use this summary'),
                ),
              ],
            );
          },
        );
      },
    );
    readOnlyController.dispose();
    if (selected == null || !context.mounted) return;
    if (controller.text.trim().isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => JobixAlertDialog(
          title: Text(ar ? 'استبدال الملخص الحالي؟' : 'Replace the current summary?'),
          content: Text(
            ar
                ? 'سيتم استبدال النص الحالي بالمثال. يمكنك تعديله قبل الحفظ.'
                : 'Replace your current text with this example? You can edit it before saving.',
          ),
          actions: [
            JobixDialogAction.secondary(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(ar ? 'الإبقاء على النص' : 'Keep current text'),
            ),
            JobixDialogAction.destructive(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(ar ? 'استبدال الملخص' : 'Replace summary'),
            ),
          ],
        ),
      );
      if (replace != true || !context.mounted) return;
    }
    controller.value = TextEditingValue(
      text: selected,
      selection: TextSelection.collapsed(offset: selected.length),
    );
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: OutlinedButton.icon(
      key: const Key('explore-summary-examples'),
      onPressed: enabled ? () => _open(context) : null,
      icon: const Icon(Icons.menu_book_outlined),
      label: Text(
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'استكشف أمثلة الملخص'
            : 'Explore summary examples',
      ),
    ),
  );
}
