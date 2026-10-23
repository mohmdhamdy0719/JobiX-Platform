import 'package:flutter/material.dart';
import '../../core/navigation/back_policy.dart';

import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'profile_overview.dart';
import 'resume_journey.dart';

const builderSteps = 6;

String stepTitle(AppLocalizations copy, int step) => switch (step) {
  1 => copy.personalInformation,
  2 => copy.stepSummary,
  3 => copy.stepExperience,
  4 => copy.stepEducation,
  5 => copy.stepSkills,
  _ => copy.stepReview,
};

/// Where a nested editor returns after Back or Save.
enum EditorOrigin {
  builder,
  review,
  career;

  static EditorOrigin parse(String? value) => switch (value) {
    'review' => review,
    'career' => career,
    _ => builder,
  };
}

/// Shared guided-builder frame: step label, progress, and a sticky
/// Back/Continue bar that respects safe areas and the keyboard.
class BuilderScaffold extends StatelessWidget {
  const BuilderScaffold({
    required this.step,
    required this.child,
    required this.onContinue,
    this.onBack,
    this.meta,
    this.busy = false,
    this.continueLabel,
    this.continueKey,
    this.reviewEditor = false,
    this.standaloneTitle,
    super.key,
  });
  final int step;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  final String? meta, continueLabel;
  final bool busy;
  final bool reviewEditor;
  final String? standaloneTitle;
  final Key? continueKey;

  @override
  Widget build(BuildContext context) {
    return JobixBackHandler(
      onBack: busy ? () {} : onBack,
      child: ResumeJourneyRecorder(
        step: step,
        enabled: !reviewEditor && standaloneTitle == null,
        child: frame(context),
      ),
    );
  }

  Widget frame(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final title = stepTitle(copy, step);
    if (standaloneTitle != null) {
      return SliceScaffold(
        title: standaloneTitle!,
        singleLineTitle: true,
        actions: const [CreditsPill(compact: true)],
        leading: IconButton(
          key: const Key('career-section-back'),
          tooltip: copy.backAction,
          icon: const BackButtonIcon(),
          onPressed: busy ? null : onBack,
        ),
        bottom: step == 5 && MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : PrimaryAction(
                key: const Key('career-section-back-bottom'),
                label: copy.backAction,
                busy: busy,
                onPressed: onBack,
              ),
        child: child,
      );
    }
    if (reviewEditor) {
      return SliceScaffold(
        title: title,
        singleLineTitle: true,
        actions: const [CreditsPill(compact: true)],
        leading: IconButton(
          key: const Key('builder-back'),
          tooltip: copy.backToReview,
          icon: const BackButtonIcon(),
          onPressed: busy ? null : () => requestJobixBack(context),
        ),
        bottom: step == 5 && MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => requestJobixBack(context),
                      child: Text(copy.backToReview),
                    ),
                  ),
                  const SizedBox(width: TokensV0.space12),
                  Expanded(
                    child: PrimaryAction(
                      key: continueKey ?? const Key('builder-continue'),
                      label: copy.saveAction,
                      busy: busy,
                      onPressed: onContinue,
                    ),
                  ),
                ],
              ),
        child: child,
      );
    }
    return SliceScaffold(
      title: title,
      singleLineTitle: true,
      actions: const [CreditsPill(compact: true)],
      leading: onBack == null || step == 1 || step == 6
          ? null
          : IconButton(
              tooltip: copy.backAction,
              icon: const BackButtonIcon(),
              onPressed: busy ? null : () => requestJobixBack(context),
            ),
      subheader: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TokensV0.pageGutter,
          TokensV0.space8,
          TokensV0.pageGutter,
          TokensV0.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${copy.stepOf(step, builderSteps)}: $title'.toUpperCase(),
                    key: const Key('builder-step-label'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: TokensV0.textSecondary,
                      letterSpacing: copy.localeName.startsWith('ar') ? 0 : 0.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (meta != null)
                  Text(
                    meta!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: TokensV0.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: TokensV0.space8),
            ClipRRect(
              borderRadius: BorderRadius.circular(TokensV0.pillRadius),
              child: LinearProgressIndicator(
                key: const Key('builder-progress'),
                value: step / builderSteps,
                minHeight: 6,
                color: TokensV0.primary,
                backgroundColor: TokensV0.surfaceContainer,
              ),
            ),
          ],
        ),
      ),
      bottom: step == 5 && MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : Row(
              children: [
                if (onBack != null && step != 1 && step != 6) ...[
                  OutlinedButton.icon(
                    key: const Key('builder-back'),
                    onPressed: busy ? null : () => requestJobixBack(context),
                    // The theme default is full-width; Back stays compact here.
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                    icon: const BackButtonIcon(),
                    label: Text(copy.backAction),
                  ),
                  const SizedBox(width: TokensV0.space12),
                ],
                Expanded(
                  child: PrimaryAction(
                    key: continueKey ?? const Key('builder-continue'),
                    label: continueLabel ?? copy.continueAction,
                    busy: busy,
                    onPressed: onContinue,
                  ),
                ),
              ],
            ),
      child: child,
    );
  }
}

/// A visibly inactive slot for a deferred feature. Never shows values.
class InactiveSlot extends StatelessWidget {
  const InactiveSlot({required this.label, this.icon, super.key});
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
    enabled: false,
    child: Container(
      padding: const EdgeInsets.all(TokensV0.space12),
      decoration: BoxDecoration(
        color: TokensV0.secondarySurface,
        borderRadius: BorderRadius.circular(TokensV0.cardRadius),
        border: Border.all(color: TokensV0.border),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.auto_awesome_outlined,
            size: 18,
            color: TokensV0.disabled,
          ),
          const SizedBox(width: TokensV0.space8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: TokensV0.disabled),
            ),
          ),
        ],
      ),
    ),
  );
}
