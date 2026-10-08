import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/async_states.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_controller.dart';
import 'research_context.dart';
import '../../core/navigation/back_policy.dart';

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
          loading: () => const SliceScaffold(child: BrandedLoadingState()),
          error: (_, __) => SliceScaffold(
            child: BrandedErrorState(
              message: copy.researchLoadError,
              retryLabel: copy.retry,
              onRetry: () => ref.invalidate(researchProvider),
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
            const icons = [
              [
                Icons.school_outlined,
                Icons.workspace_premium_outlined,
                Icons.trending_up,
                Icons.psychology_outlined,
                Icons.military_tech_outlined,
                Icons.history,
                Icons.alt_route,
              ],
              [
                Icons.school_outlined,
                Icons.trending_up,
                Icons.swap_horiz,
                Icons.military_tech_outlined,
                Icons.hourglass_top,
                Icons.explore_outlined,
              ],
              [
                Icons.location_city,
                Icons.map_outlined,
                Icons.laptop_mac,
                Icons.flight_takeoff,
                Icons.hub_outlined,
                Icons.explore_outlined,
              ],
              [
                Icons.description_outlined,
                Icons.explore_outlined,
                Icons.alt_route,
                Icons.laptop_chromebook,
                Icons.psychology_outlined,
                Icons.forum_outlined,
              ],
            ];
            final answered = question == 3
                ? progress.help.isNotEmpty
                : selected[question] != null;
            return JobixBackHandler(
              onBack: busy
                  ? () {}
                  : question == 0
                  ? null
                  : () => setState(() => current = question - 1),
              child: SliceScaffold(
                canvasColor: TokensV0.surfaceCard,
                title: copy.researchHeading,
                leading: question == 0
                    ? const BrandMark(size: 36)
                    : IconButton(
                        tooltip: copy.backAction,
                        icon: const Icon(Icons.arrow_back),
                        onPressed: busy
                            ? null
                            : () => requestJobixBack(context),
                      ),
                bottom: PrimaryAction(
                  key: const Key('research-continue'),
                  label: copy.continueAction,
                  busy: busy,
                  onPressed: !answered
                      ? null
                      : () async {
                          if (question == 3) {
                            await ref
                                .read(researchProvider.notifier)
                                .finishFirstLaunch();
                            if (context.mounted) context.go('/auth');
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
                      copy.researchStep(question + 1),
                      key: const Key('research-step'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: TokensV0.primary,
                        letterSpacing:
                            Directionality.of(context) == TextDirection.rtl
                            ? 0
                            : .8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: TokensV0.space8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(TokensV0.pillRadius),
                      child: LinearProgressIndicator(
                        value: (question + 1) / 4,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: TokensV0.space20),
                    Text(
                      questions[question],
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    if (question == 3) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              copy.helpLimit,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '${progress.help.length}/3',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: TokensV0.space24),
                    for (var i = 0; i < researchOptions[question].length; i++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          bottom: TokensV0.space8,
                        ),
                        child: ChoiceTile(
                          key: Key(
                            'research-option-${researchOptions[question][i]}',
                          ),
                          label: labels[question][i],
                          icon: icons[question][i],
                          multiple: question == 3,
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
              ),
            );
          },
        );
  }
}
