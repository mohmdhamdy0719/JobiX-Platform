import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'resume_experience_shared.dart';

/// A fictional visual sample for the supported ATS professional template.
class ResumeTemplateCard extends StatelessWidget {
  const ResumeTemplateCard({
    required this.language,
    required this.onInspect,
    this.enlarged = false,
    super.key,
  });

  final String language;
  final VoidCallback onInspect;
  final bool enlarged;

  @override
  Widget build(BuildContext context) {
    final isArabic = language.toLowerCase().startsWith('ar');
    final copy = ResumeCopy.of(context);
    return Semantics(
      button: true,
      label: copy.inspectTemplate,
      child: Material(
        color: TokensV0.surfaceCard,
        borderRadius: BorderRadius.circular(TokensV0.cardRadius),
        child: InkWell(
          onTap: onInspect,
          borderRadius: BorderRadius.circular(TokensV0.cardRadius),
          child: Container(
            width: enlarged ? 336 : 238,
            padding: const EdgeInsets.all(TokensV0.space12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TokensV0.cardRadius),
              border: Border.all(color: TokensV0.primary, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: TokensV0.primary,
                          borderRadius: BorderRadius.circular(
                            TokensV0.chipRadius,
                          ),
                        ),
                        child: Text(
                          copy.atsProfessional,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: TokensV0.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: TokensV0.space8),
                    Icon(
                      isArabic
                          ? Icons.format_textdirection_r_to_l
                          : Icons.format_textdirection_l_to_r,
                      color: TokensV0.primary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: TokensV0.space12),
                SizedBox(
                  height: enlarged ? 300 : 204,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 214,
                      height: 184,
                      child: _FictionalResumePreview(isArabic: isArabic),
                    ),
                  ),
                ),
                const SizedBox(height: TokensV0.space12),
                Text(
                  copy.sampleFictional,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: TokensV0.textSecondary,
                  ),
                ),
                const SizedBox(height: TokensV0.space4),
                Text(
                  copy.atsSingleTemplate,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: TokensV0.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: TokensV0.space4),
                Text(
                  copy.templateSpecifications,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: TokensV0.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FictionalResumePreview extends StatelessWidget {
  const _FictionalResumePreview({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
    height: 204,
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: TokensV0.background,
      border: Border.all(color: TokensV0.border),
      borderRadius: BorderRadius.circular(TokensV0.controlRadius),
    ),
    child: Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 21,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: TokensV0.primary,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                isArabic ? 'سارة خالد · مثال خيالي' : 'Maya Rahman · Fictional',
                style: const TextStyle(
                  color: TokensV0.onPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isArabic ? 'مسؤولة تسويق رقمي' : 'Digital Marketing Specialist',
            style: const TextStyle(
              color: TokensV0.primary,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            isArabic
                ? 'sara@example.test · +1 555 010 0140 · LinkedIn'
                : 'maya@example.test · +1 555 010 0140 · LinkedIn',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 6, color: TokensV0.textSecondary),
          ),
          const SizedBox(height: 5),
          _miniSection(
            isArabic ? 'الملخص المهني' : 'PROFESSIONAL SUMMARY',
            isArabic
                ? 'متخصصة في الحملات الرقمية وتحليل الأداء.'
                : 'Digital campaigns and performance analytics.',
          ),
          _miniSection(
            isArabic ? 'الخبرة' : 'EXPERIENCE',
            isArabic
                ? 'شركة النور · مسؤولة تسويق · 2022–الآن'
                : 'Bright Co. · Marketing Associate · 2022–Present',
          ),
          _miniSection(
            isArabic ? 'التعليم' : 'EDUCATION',
            isArabic
                ? 'بكالوريوس إدارة الأعمال'
                : 'B.A. Business Administration',
          ),
          _miniSection(
            isArabic
                ? 'العمل التطوعي والإنجازات'
                : 'VOLUNTEERING & ACHIEVEMENTS',
            isArabic
                ? 'تنسيق فعاليات مجتمعية · نمو الزيارات 25٪'
                : 'Community events · Increased traffic 25%',
          ),
          Text(
            isArabic
                ? 'المهارات: SEO · التحليل · التخطيط · التواصل'
                : 'Skills: SEO · Analytics · Planning · Communication',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 6, color: TokensV0.textSecondary),
          ),
        ],
      ),
    ),
  );

  Widget _miniSection(String title, String content) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 6,
                  color: TokensV0.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Expanded(child: Divider(height: 1, color: TokensV0.border)),
          ],
        ),
        Text(
          content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 6, color: TokensV0.textPrimary),
        ),
      ],
    ),
  );
}
