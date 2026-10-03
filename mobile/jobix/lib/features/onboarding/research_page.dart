import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_language_button.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_controller.dart';
import 'research_context.dart';

class ResearchPage extends ConsumerStatefulWidget {
  const ResearchPage({super.key});
  @override
  ConsumerState<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends ConsumerState<ResearchPage> {
  int? current;
  bool busy = false;
  Future<void> select(
    ResearchProgress progress,
    int question,
    String value,
  ) async {
    setState(() => busy = true);
    try {
      await ref
          .read(researchProvider.notifier)
          .persist(progress.select(question, value));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.localWriteError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    return ref
        .watch(researchProvider)
        .when(
          loading: () => const SliceScaffold(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SliceScaffold(
            child: TextButton(
              onPressed: () => ref.invalidate(researchProvider),
              child: Text(copy.retry),
            ),
          ),
          data: (progress) {
            final question = current ??= progress.question;
            final questions = [
              copy.questionStage,
              copy.questionGoal,
              copy.questionLocation,
              copy.questionHelp,
            ];
            final labels = [
              [
                copy.stageStudent,
                copy.stageGraduate,
                copy.stageEarly,
                copy.stageMid,
                copy.stageExperienced,
                copy.stageReturning,
                copy.stageChanger,
              ],
              [
                copy.goalFirst,
                copy.goalBetter,
                copy.goalChange,
                copy.goalAdvance,
                copy.goalPrepare,
                copy.notSure,
              ],
              [
                copy.locationCity,
                copy.locationCountry,
                copy.locationRemote,
                copy.locationAbroad,
                copy.locationMultiple,
                copy.notSure,
              ],
              [
                copy.helpCv,
                copy.helpOpportunities,
                copy.helpPaths,
                copy.helpOnline,
                copy.helpSkills,
                copy.helpInterviews,
              ],
            ];
            final selected = [progress.stage, progress.goal, progress.location];
            final answered = question == 3
                ? progress.help.isNotEmpty
                : selected[question] != null;
            return SliceScaffold(
              title: copy.researchHeading,
              actions: const [AppLanguageButton()],
              leading: question == 0
                  ? const BrandMark(size: 36)
                  : IconButton(
                      tooltip: copy.backAction,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: busy
                          ? null
                          : () => setState(() => current = question - 1),
                    ),
              bottom: PrimaryAction(
                key: const Key('research-continue'),
                label: copy.continueAction,
                busy: busy,
                onPressed: !answered
                    ? null
                    : () {
                        if (question == 3) {
                          context.go('/auth');
                        } else {
                          setState(() => current = question + 1);
                        }
                      },
                icon: Icons.arrow_forward,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${question + 1}/4',
                    key: const Key('research-step'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: TokensV0.space12),
                  LinearProgressIndicator(value: (question + 1) / 4),
                  const SizedBox(height: TokensV0.space24),
                  SectionHeading(
                    title: questions[question],
                    subtitle: question == 3 ? copy.helpLimit : null,
                  ),
                  const SizedBox(height: TokensV0.space24),
                  for (var i = 0; i < researchOptions[question].length; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: TokensV0.space12,
                      ),
                      child: ChoiceTile(
                        key: Key(
                          'research-option-${researchOptions[question][i]}',
                        ),
                        label: labels[question][i],
                        selected: question == 3
                            ? progress.help.contains(
                                researchOptions[question][i],
                              )
                            : selected[question] ==
                                  researchOptions[question][i],
                        onTap: () {
                          if (!busy) {
                            select(
                              progress,
                              question,
                              researchOptions[question][i],
                            );
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: TokensV0.space12),
                  Text(
                    copy.contextOnly,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        );
  }
}
