import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'resume_experience_components.dart';
import 'resume_experience_shared.dart';
import 'resume_receipt_panel.dart';

class ResumeDetailsBody extends StatelessWidget {
  const ResumeDetailsBody({
    required this.job,
    this.onDownload,
    this.onAgain,
    required this.onRefresh,
    this.busy = false,
    this.downloading = false,
    super.key,
  });

  final Map<String, dynamic> job;
  final VoidCallback? onDownload;
  final VoidCallback? onAgain;
  final VoidCallback onRefresh;
  final bool busy;
  final bool downloading;

  @override
  Widget build(BuildContext context) {
    final copy = ResumeCopy.of(context);
    final state = resumeJobState(job);
    final eligible = resumeIsDownloadAvailable(job, state);
    final createdAt = resumeDateLabel(job['created_at']);
    final completedAt = resumeDateLabel(job['completed_at']);
    final expiresAt = resumeDateLabel(job['expires_at']);
    final pages = resumePositiveInt(job['page_count']);
    final bytes = resumePositiveInt(job['object_size']);
    final profile = resumeFirstString(job, const [
      'profile_name',
      'profile_title',
      'role_title',
    ]);
    final template = resumeTemplateDisplayName(
      copy,
      resumeFirstString(job, const ['template_name', 'template']),
    );
    final language = resumeFirstString(job, const [
      'language',
      'resume_language',
      'cv_language',
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResumeReceiptPanel(
          copy: copy,
          state: state,
          createdAt: createdAt,
          completedAt: completedAt,
        ),
        const SizedBox(height: TokensV0.space16),
        ResumeDetailsPanel(
          title: copy.exportDetails,
          children: [
            if (profile != null)
              ResumeDetailLine(label: copy.profile, value: profile),
            if (template != null)
              ResumeDetailLine(label: copy.template, value: template),
            if (language != null)
              ResumeDetailLine(
                label: copy.cvLanguage,
                value: resumeLocalizedLanguage(copy, language),
              ),
            if (pages != null)
              ResumeDetailLine(label: copy.pages, value: copy.pageCount(pages)),
            if (bytes != null)
              ResumeDetailLine(
                label: copy.fileSize,
                value: resumeFormatBytes(bytes),
              ),
            ResumeDetailLine(
              label: copy.status,
              value: resumeStatusLabel(copy, state),
            ),
          ],
        ),
        const SizedBox(height: TokensV0.space16),
        ResumeDetailsPanel(
          title: copy.credits,
          children: [
            Text(
              resumeCreditExplanation(copy, state),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (state == 'completed')
              Padding(
                padding: const EdgeInsetsDirectional.only(top: TokensV0.space8),
                child: Text(
                  copy.noSecondCharge,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: TokensV0.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        if (state == 'completed') ...[
          const SizedBox(height: TokensV0.space16),
          ResumeDetailsPanel(
            title: copy.downloadAvailability,
            leadingIcon: Icons.hourglass_bottom,
            tinted: true,
            children: [
              Text(
                eligible
                    ? copy.privateDownloadUntil(expiresAt!)
                    : copy.downloadUnavailable,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (expiresAt != null) ...[
                const SizedBox(height: TokensV0.space8),
                ResumeDetailLine(label: copy.expires, value: expiresAt),
              ],
              if (eligible) ...[
                const SizedBox(height: TokensV0.space12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: downloading ? null : onDownload,
                    icon: downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text(
                      downloading
                          ? copy.downloading
                          : bytes == null
                          ? copy.downloadPdf
                          : copy.downloadPdfWithSize(resumeFormatBytes(bytes)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (state == 'failed' && onAgain != null) ...[
          const SizedBox(height: TokensV0.space16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAgain,
              icon: const Icon(Icons.refresh),
              label: Text(copy.tryAgain),
            ),
          ),
        ],
        const SizedBox(height: TokensV0.space12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: busy ? null : onRefresh,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(copy.refreshDetails),
          ),
        ),
      ],
    );
  }
}
