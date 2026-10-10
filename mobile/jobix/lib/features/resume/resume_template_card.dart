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
                  height: enlarged ? 280 : 184,
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
    height: 184,
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
                isArabic
                    ? 'ليلى منصور • مثال خيالي'
                    : 'Alex Morgan • Fictional',
                style: const TextStyle(
                  color: TokensV0.onPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          const _PreviewLine(width: 0.73, color: TokensV0.navy, height: 5),
          const SizedBox(height: 5),
          const _PreviewLine(width: 0.58, color: TokensV0.primary, height: 4),
          const SizedBox(height: 8),
          const _PreviewLine(width: 0.94, color: TokensV0.surfaceVariant),
          const SizedBox(height: 4),
          const _PreviewLine(width: 0.83, color: TokensV0.surfaceVariant),
          const SizedBox(height: 9),
          _PreviewSectionLine(isArabic: isArabic),
          const SizedBox(height: 7),
          const _PreviewLine(width: 0.88, color: TokensV0.surfaceVariant),
          const SizedBox(height: 4),
          const _PreviewLine(width: 0.76, color: TokensV0.surfaceVariant),
          const Spacer(),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Container(
                  width: 34,
                  height: 7,
                  decoration: BoxDecoration(
                    color: TokensV0.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (i < 2) const SizedBox(width: 5),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.width,
    required this.color,
    this.height = 3,
  });

  final double width;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: width,
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _PreviewSectionLine extends StatelessWidget {
  const _PreviewSectionLine({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: TokensV0.primary,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Container(
          height: 4,
          color: isArabic ? TokensV0.deepBlue : TokensV0.navy,
        ),
      ),
    ],
  );
}
