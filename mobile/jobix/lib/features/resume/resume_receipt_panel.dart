import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'resume_experience_components.dart';
import 'resume_experience_shared.dart';

class ResumeReceiptPanel extends StatelessWidget {
  const ResumeReceiptPanel({
    required this.copy,
    required this.state,
    required this.createdAt,
    required this.completedAt,
    super.key,
  });

  final ResumeCopy copy;
  final String state;
  final String? createdAt;
  final String? completedAt;

  @override
  Widget build(BuildContext context) {
    final completed = state == 'completed' || completedAt != null;
    final timestamp = completedAt ?? createdAt;
    return Container(
      key: const ValueKey('resume-receipt-panel'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: TokensV0.surfaceCard,
        borderRadius: BorderRadius.circular(TokensV0.panelRadius),
        border: Border.all(color: TokensV0.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TokensV0.space16,
              TokensV0.space16,
              TokensV0.space16,
              TokensV0.space12,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                        copy.resumeReceipt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: TokensV0.textSecondary),
                      ),
                      const SizedBox(height: TokensV0.space4),
                      Text(
                        copy.resumeCompilation,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: TokensV0.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TokensV0.space16),
            decoration: const BoxDecoration(
              color: TokensV0.background,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(TokensV0.panelRadius),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cost = Text(
                      copy.chargedTwoCredits,
                      key: const ValueKey('receipt-credit-impact'),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: TokensV0.error,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    final pill = ResumeStatePill(state: state, copy: copy);
                    if (!completed) return pill;
                    if (constraints.maxWidth < 340) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: pill,
                          ),
                          const SizedBox(height: TokensV0.space8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: cost,
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [pill, cost],
                    );
                  },
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: TokensV0.space8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 17,
                        color: TokensV0.textSecondary,
                      ),
                      const SizedBox(width: TokensV0.space4),
                      Expanded(
                        child: Text(
                          timestamp,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
