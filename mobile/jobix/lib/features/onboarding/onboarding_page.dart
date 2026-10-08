import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_language_button.dart';
import '../../core/design/async_states.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_controller.dart';
import 'onboarding_illustrations.dart';
import 'research_context.dart';
import '../../core/navigation/back_policy.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool busy = false;

  Future<void> advance(
    ResearchProgress progress, {
    bool skip = false,
    bool back = false,
  }) async {
    setState(() => busy = true);
    try {
      final finish = !back && (skip || progress.onboardingPage == 2);
      await ref
          .read(researchProvider.notifier)
          .persist(
            progress.copy(
              page: back
                  ? progress.onboardingPage - 1
                  : finish
                  ? progress.onboardingPage
                  : progress.onboardingPage + 1,
              done: finish,
            ),
          );
      if (mounted && finish) context.go('/research');
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
    final value = ref.watch(researchProvider);
    return value.when(
      loading: () => const SliceScaffold(child: BrandedLoadingState()),
      error: (_, __) => SliceScaffold(
        child: BrandedErrorState(
          message: copy.researchLoadError,
          retryLabel: copy.retry,
          onRetry: () => ref.invalidate(researchProvider),
        ),
      ),
      data: (progress) {
        final page = progress.onboardingPage.clamp(0, 2);
        final titles = [
          copy.onboardingTitleOne,
          copy.onboardingTitleTwo,
          copy.onboardingTitleThree,
        ];
        final bodies = [
          copy.onboardingBodyOne,
          copy.onboardingBodyTwo,
          copy.onboardingBodyThree,
        ];

        return JobixBackHandler(
          onBack: busy
              ? () {}
              : page == 0
              ? null
              : () => advance(progress, back: true),
          child: SliceScaffold(
            fillViewport: true,
            header: _OnboardingHeader(
              page: page,
              skipLabel: copy.skipOnboarding,
              skipShort: copy.skipShort,
              backLabel: copy.backAction,
              busy: busy,
              showBack: page > 0,
              onBack: () => requestJobixBack(context),
              onSkip: () => advance(progress, skip: true),
            ),
            bottom: PrimaryAction(
              key: const Key('onboarding-continue'),
              label: copy.continueAction,
              busy: busy,
              onPressed: () => advance(progress),
              icon: Icons.arrow_forward,
            ),
            child: LayoutBuilder(
              builder: (context, _) {
                final screenHeight = MediaQuery.sizeOf(context).height;
                final illustrationHeight = screenHeight < 700
                    ? 248.0
                    : switch (page) {
                        0 => 330.0,
                        1 => 350.0,
                        _ => 270.0,
                      };
                final isSecond = page == 1;
                final title = page == 0
                    ? titles[page].replaceFirst(', ', ',\n')
                    : page == 2
                    ? titles[page].replaceFirst('. ', '.\n')
                    : titles[page];
                return Column(
                  mainAxisAlignment: screenHeight >= 1000
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnboardingIllustration(
                      page: page,
                      height: illustrationHeight,
                    ),
                    SizedBox(height: screenHeight < 700 ? 24 : 32),
                    AnimatedSwitcher(
                      duration: motionDuration(context, TokensV0.motionContent),
                      child: Column(
                        key: ValueKey<int>(page),
                        crossAxisAlignment: isSecond
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            semanticsLabel: titles[page],
                            key: Key('onboarding-title-$page'),
                            textAlign: isSecond
                                ? TextAlign.start
                                : TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: TokensV0.space12),
                          Text(
                            bodies[page],
                            textAlign: isSecond
                                ? TextAlign.start
                                : TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: TokensV0.space16),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.page,
    required this.skipLabel,
    required this.skipShort,
    required this.backLabel,
    required this.busy,
    required this.showBack,
    required this.onBack,
    required this.onSkip,
  });

  final int page;
  final String skipLabel;
  final String skipShort;
  final String backLabel;
  final bool busy;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final progress = Semantics(
      label: '${page + 1}/3',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final active = index == page;
            return AnimatedContainer(
              duration: motionDuration(context, TokensV0.motionFeedback),
              curve: Curves.easeOutCubic,
              width: active ? 24 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active
                    ? TokensV0.primary
                    : TokensV0.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(TokensV0.pillRadius),
              ),
            );
          }),
        ),
      ),
    );
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Allocate space for progress on small screens and large text so
            // that it never overlaps the Skip and language controls.
            final compact =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final controls = Row(
              children: [
                SizedBox(
                  width: TokensV0.touchTarget,
                  height: TokensV0.touchTarget,
                  child: showBack
                      ? IconButton(
                          key: const Key('onboarding-back'),
                          tooltip: backLabel,
                          icon: const Icon(Icons.arrow_back),
                          onPressed: busy ? null : onBack,
                        )
                      : const Center(child: BrandMark(size: 32)),
                ),
                if (compact)
                  Expanded(child: Center(child: progress))
                else
                  const Spacer(),
                TextButton(
                  key: const Key('skip-onboarding'),
                  onPressed: busy ? null : onSkip,
                  child: Tooltip(message: skipLabel, child: Text(skipShort)),
                ),
                const AppLanguageButton(),
              ],
            );
            return compact
                ? controls
                : Stack(
                    alignment: Alignment.center,
                    children: [controls, progress],
                  );
          },
        ),
      ),
    );
  }
}
