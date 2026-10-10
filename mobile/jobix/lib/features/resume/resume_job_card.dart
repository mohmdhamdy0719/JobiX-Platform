import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'resume_experience_components.dart';
import 'resume_experience_shared.dart';

class ResumeJobCard extends StatelessWidget {
  const ResumeJobCard({
    required this.job,
    required this.onDetails,
    this.onDownload,
    this.onAgain,
    super.key,
  });

  final Map<String, dynamic> job;
  final VoidCallback onDetails;
  final VoidCallback? onDownload;
  final VoidCallback? onAgain;

  @override
  Widget build(BuildContext context) {
    final copy = ResumeCopy.of(context);
    final state = resumeJobState(job);
    final eligible = resumeIsDownloadAvailable(job, state);
    final title =
        resumeFirstString(job, const [
          'title',
          'template_name',
          'profile_name',
          'profile_title',
        ]) ??
        copy.resumeExport;
    final id = job['id'];
    final createdAt = resumeDateLabel(job['created_at']);
    final pages = resumePositiveInt(job['page_count']);
    final language = resumeFirstString(job, const [
      'language',
      'resume_language',
      'cv_language',
    ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TokensV0.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: TokensV0.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(TokensV0.controlRadius),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: TokensV0.primary,
                  ),
                ),
                const SizedBox(width: TokensV0.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: TokensV0.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: TokensV0.space4),
                        Text(
                          createdAt,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: TokensV0.space8),
                ResumeStatePill(state: state, copy: copy),
              ],
            ),
            if (id != null || pages != null || language != null) ...[
              const SizedBox(height: TokensV0.space12),
              Wrap(
                spacing: TokensV0.space8,
                runSpacing: TokensV0.space4,
                children: [
                  if (id != null)
                    ResumeMetadataChip(
                      label: '${copy.jobId}: ${id.toString()}',
                    ),
                  if (pages != null)
                    ResumeMetadataChip(label: copy.pageCount(pages)),
                  if (language != null)
                    ResumeMetadataChip(
                      label: resumeLocalizedLanguage(copy, language),
                    ),
                ],
              ),
            ],
            if (resumeCreditNote(copy, state) case final note?) ...[
              const SizedBox(height: TokensV0.space12),
              Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: TokensV0.space12,
                  vertical: TokensV0.space8,
                ),
                decoration: BoxDecoration(
                  color: TokensV0.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(TokensV0.chipRadius),
                ),
                child: Text(
                  note,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: TokensV0.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: TokensV0.space12),
            Wrap(
              spacing: TokensV0.space8,
              runSpacing: TokensV0.space8,
              children: [
                ResumeCompactAction(
                  label: copy.details,
                  icon: Icons.receipt_long_outlined,
                  onPressed: onDetails,
                  primary: true,
                ),
                if (eligible && onDownload != null)
                  ResumeCompactAction(
                    label: copy.download,
                    icon: Icons.download_outlined,
                    onPressed: onDownload!,
                  ),
                if (state == 'failed' && onAgain != null)
                  ResumeCompactAction(
                    label: copy.tryAgain,
                    icon: Icons.refresh,
                    onPressed: onAgain!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
