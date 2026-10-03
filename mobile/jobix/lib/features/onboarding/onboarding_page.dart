import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_language_button.dart';
import '../../core/design/async_states.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_controller.dart';
import 'research_context.dart';

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
        return SliceScaffold(
          fillViewport: true,
          header: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: TokensV0.touchTarget,
                  height: 56,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: page == 0
                            ? const Center(child: BrandMark(size: 32))
                            : IconButton(
                                key: const Key('onboarding-back'),
                                tooltip: copy.backAction,
                                icon: const Icon(Icons.arrow_back),
                                onPressed: busy
                                    ? null
                                    : () => advance(progress, back: true),
                              ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: TextButton(
                    key: const Key('skip-onboarding'),
                    onPressed: busy
                        ? null
                        : () => advance(progress, skip: true),
                    child: Tooltip(
                      message: copy.skipOnboarding,
                      child: Text(copy.skipShort),
                    ),
                  ),
                ),
                const SizedBox(width: TokensV0.space4),
                const AppLanguageButton(),
              ],
            ),
          ),
          bottom: PrimaryAction(
            key: const Key('onboarding-continue'),
            label: copy.continueAction,
            busy: busy,
            onPressed: () => advance(progress),
            icon: Icons.arrow_forward,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: '${page + 1}/3',
                child: Text(
                  '0${page + 1}  /  03',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: TokensV0.primary,
                    letterSpacing:
                        Directionality.of(context) == TextDirection.rtl
                        ? 0
                        : .8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: TokensV0.space16),
              ClipRRect(
                borderRadius: BorderRadius.circular(TokensV0.pillRadius),
                child: LinearProgressIndicator(
                  value: (page + 1) / 3,
                  minHeight: 3,
                  backgroundColor: TokensV0.surfaceContainer,
                ),
              ),
              const SizedBox(height: TokensV0.space40),
              AnimatedSwitcher(
                duration: motionDuration(context, TokensV0.motionContent),
                child: Column(
                  key: ValueKey<int>(page),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titles[page],
                      key: Key('onboarding-title-$page'),
                      textAlign: TextAlign.start,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: TokensV0.space16),
                    Text(
                      bodies[page],
                      textAlign: TextAlign.start,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: TokensV0.space32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
