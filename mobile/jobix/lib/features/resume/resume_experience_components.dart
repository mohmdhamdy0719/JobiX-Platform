import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'resume_experience_shared.dart';

class ResumeStatePill extends StatelessWidget {
  const ResumeStatePill({required this.state, required this.copy, super.key});

  final String state;
  final ResumeCopy copy;

  @override
  Widget build(BuildContext context) {
    final color = state == 'completed'
        ? TokensV0.success
        : state == 'failed'
        ? TokensV0.error
        : TokensV0.info;
    final fill = state == 'completed'
        ? TokensV0.success.withValues(alpha: 0.1)
        : state == 'failed'
        ? TokensV0.errorContainer
        : TokensV0.surfaceContainerLow;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(TokensV0.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state == 'completed'
                ? Icons.check_circle
                : state == 'failed'
                ? Icons.error
                : Icons.schedule,
            size: 13,
            color: color,
          ),
          const SizedBox(width: TokensV0.space4),
          Flexible(
            child: Text(
              resumeStatusLabel(copy, state),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResumeMetadataChip extends StatelessWidget {
  const ResumeMetadataChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: TokensV0.space8,
      vertical: TokensV0.space4,
    ),
    decoration: BoxDecoration(
      color: TokensV0.surfaceContainerLow,
      borderRadius: BorderRadius.circular(TokensV0.chipRadius),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: TokensV0.textSecondary),
    ),
  );
}

class ResumeCompactAction extends StatelessWidget {
  const ResumeCompactAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = primary
        ? ElevatedButton.styleFrom(
            minimumSize: const Size(0, TokensV0.touchTarget),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
          )
        : OutlinedButton.styleFrom(
            minimumSize: const Size(0, TokensV0.touchTarget),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
          );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: TokensV0.space8),
        Text(label),
      ],
    );
    return primary
        ? ElevatedButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class ResumeDetailsPanel extends StatelessWidget {
  const ResumeDetailsPanel({
    required this.title,
    required this.children,
    this.leadingIcon,
    this.tinted = false,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final IconData? leadingIcon;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(TokensV0.space16),
    decoration: BoxDecoration(
      color: tinted ? TokensV0.surfaceContainerLow : TokensV0.surfaceCard,
      borderRadius: BorderRadius.circular(TokensV0.panelRadius),
      border: Border.all(color: TokensV0.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, color: TokensV0.primary, size: 20),
              const SizedBox(width: TokensV0.space8),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: TokensV0.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: TokensV0.space12),
        ...resumeWithDividers(children),
      ],
    ),
  );
}

List<Widget> resumeWithDividers(List<Widget> children) {
  final result = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) result.add(const Divider(height: TokensV0.space12));
    result.add(children[i]);
  }
  return result;
}

class ResumeDetailLine extends StatelessWidget {
  const ResumeDetailLine({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
      const SizedBox(width: TokensV0.space12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: TokensV0.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
