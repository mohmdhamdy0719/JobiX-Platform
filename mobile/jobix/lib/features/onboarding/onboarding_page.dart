import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_language_button.dart';
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
          header: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
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
                      const AppLanguageButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: '${page + 1}/3',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Container(
                            margin: const EdgeInsetsDirectional.all(
                              TokensV0.space4,
                            ),
                            width: i == page
                                ? (page == 0 ? 32 : 24)
                                : (page == 0 ? 6 : 8),
                            height: page == 0 ? 6 : 8,
                            decoration: BoxDecoration(
                              color: i == page
                                  ? TokensV0.primary
                                  : TokensV0.surfaceContainer,
                              borderRadius: BorderRadius.circular(
                                TokensV0.chipRadius,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
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
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: page == 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: IgnorePointer(child: OnboardingArt(page: page)),
              ),
              const SizedBox(height: TokensV0.space24),
              Text(
                page == 0
                    ? titles[page].replaceFirst(', ', ',\n')
                    : page == 2
                    ? titles[page].replaceFirst('. ', '.\n')
                    : titles[page],
                key: Key('onboarding-title-$page'),
                textAlign: page == 1 ? TextAlign.start : TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: TokensV0.headlineMobileSize,
                  height: 34 / 26,
                  letterSpacing: -0.39,
                ),
              ),
              const SizedBox(height: TokensV0.space8),
              Text(
                bodies[page],
                textAlign: page == 1 ? TextAlign.start : TextAlign.center,
                style: page == 1
                    ? Theme.of(context).textTheme.bodyLarge
                    : Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: TokensV0.textSecondary,
                      ),
              ),
              const SizedBox(height: TokensV0.space32),
              PrimaryAction(
                key: const Key('onboarding-continue'),
                label: copy.continueAction,
                busy: busy,
                onPressed: () => advance(progress),
                icon: Icons.arrow_forward,
              ),
            ],
          ),
        );
      },
    );
  }
}
