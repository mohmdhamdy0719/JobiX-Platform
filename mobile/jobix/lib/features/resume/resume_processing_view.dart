import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'resume_experience_shared.dart';

class ResumeProcessingView extends StatelessWidget {
  const ResumeProcessingView({
    required this.job,
    required this.onHistory,
    required this.onDashboard,
    this.onDownload,
    super.key,
  });

  final Map<String, dynamic> job;
  final VoidCallback onHistory;
  final VoidCallback onDashboard;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final copy = ResumeCopy.of(context);
    final state = resumeJobState(job);
    final eligible = resumeIsDownloadAvailable(job, state);
    final isFinished = [
      'completed',
      'failed',
      'expired',
      'missing',
    ].contains(state);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth < TokensV0.contentMaxWidth
            ? constraints.maxWidth
            : TokensV0.contentMaxWidth;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TokensV0.pageGutter,
                TokensV0.space24,
                TokensV0.pageGutter,
                TokensV0.space20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: TokensV0.space8),
                  Column(
                    children: [
                      if (!isFinished)
                        const SizedBox(
                          width: 92,
                          height: 92,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: TokensV0.primary,
                            backgroundColor: TokensV0.surfaceContainerLow,
                          ),
                        )
                      else
                        _StatusEmblem(state: state),
                      const SizedBox(height: TokensV0.space32),
                      Text(
                        resumeStatusTitle(copy, state),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: TokensV0.space8),
                      Text(
                        resumeStatusDescription(copy, state),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: TokensV0.space24),
                      _JobSummary(job: job, copy: copy),
                    ],
                  ),
                  Column(
                    children: [
                      if (eligible && onDownload != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onDownload,
                            icon: const Icon(Icons.download_outlined),
                            label: Text(copy.downloadPdf),
                          ),
                        ),
                        const SizedBox(height: TokensV0.space8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onHistory,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: Text(copy.exportHistory),
                        ),
                      ),
                      const SizedBox(height: TokensV0.space8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onDashboard,
                          icon: const Icon(Icons.dashboard_outlined),
                          label: Text(copy.dashboard),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusEmblem extends StatelessWidget {
  const _StatusEmblem({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final success = state == 'completed';
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: success
            ? TokensV0.success.withValues(alpha: 0.1)
            : TokensV0.errorContainer,
      ),
      child: Icon(
        success ? Icons.check_circle_outline : Icons.error_outline,
        color: success ? TokensV0.success : TokensV0.error,
        size: 46,
      ),
    );
  }
}

class _JobSummary extends StatelessWidget {
  const _JobSummary({required this.job, required this.copy});

  final Map<String, dynamic> job;
  final ResumeCopy copy;

  @override
  Widget build(BuildContext context) {
    final details = <String>[];
    final profile = resumeFirstString(job, const [
      'profile_name',
      'profile_title',
      'role_title',
      'profile_id',
    ]);
    final template = resumeFirstString(job, const [
      'template_name',
      'template',
    ]);
    final pages = resumePositiveInt(job['page_count']);
    final language = resumeFirstString(job, const [
      'language',
      'resume_language',
      'cv_language',
    ]);
    if (profile != null) details.add(profile);
    if (template != null) details.add(template);
    if (pages != null) details.add(copy.pageCount(pages));
    if (language != null) details.add(resumeLocalizedLanguage(copy, language));
    if (details.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TokensV0.space16,
        vertical: TokensV0.space12,
      ),
      decoration: BoxDecoration(
        color: TokensV0.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TokensV0.pillRadius),
        border: Border.all(color: TokensV0.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: TokensV0.space8,
        runSpacing: TokensV0.space4,
        children: [
          for (var i = 0; i < details.length; i++) ...[
            Text(
              details[i],
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: TokensV0.textPrimary,
                fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (i < details.length - 1)
              const Icon(Icons.circle, size: 4, color: TokensV0.disabled),
          ],
        ],
      ),
    );
  }
}
