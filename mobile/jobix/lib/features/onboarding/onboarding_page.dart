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
  Future<void> advance(ResearchProgress progress, {bool skip = false}) async {
    setState(() => busy = true);
    try {
      final finish = skip || progress.onboardingPage == 2;
      await ref
          .read(researchProvider.notifier)
          .persist(
            progress.copy(
              page: finish
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
          leading: const BrandMark(size: 40),
          actions: [
            const AppLanguageButton(),
            TextButton(
              key: const Key('skip-onboarding'),
              onPressed: busy ? null : () => advance(progress, skip: true),
              child: Text(copy.skipOnboarding),
            ),
          ],
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryAction(
                key: const Key('onboarding-continue'),
                label: copy.continueAction,
                busy: busy,
                onPressed: () => advance(progress),
                icon: Icons.arrow_forward,
              ),
              TextButton(
                onPressed: busy ? null : () => context.go('/auth?mode=login'),
                child: Text(copy.existingAccount),
              ),
            ],
          ),
          child: Column(
            children: [
              Semantics(
                label: '${page + 1}/3',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        margin: const EdgeInsetsDirectional.all(
                          TokensV0.space4,
                        ),
                        width: i == page ? 32 : 8,
                        height: 6,
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
              const SizedBox(height: TokensV0.space24),
              OnboardingArt(page: page),
              const SizedBox(height: TokensV0.space32),
              Text(
                titles[page],
                key: Key('onboarding-title-$page'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: TokensV0.space16),
              Text(bodies[page], textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}
