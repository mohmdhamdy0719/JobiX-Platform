import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_language_button.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';

final unfinishedDraftProvider = FutureProvider.family<bool, String>((
  ref,
  profile,
) async {
  final repository = await ref.watch(draftRepositoryProvider.future);
  return await repository.database.draftFor(repository.user, profile) != null;
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    final profile = ref.watch(firstProfileProvider);
    final merge = ref.watch(contextMergeProvider);
    return SliceScaffold(
      title: copy.appTitle,
      leading: const BrandMark(size: 40),
      actions: [
        const AppLanguageButton(),
        IconButton(
          tooltip: copy.signOut,
          key: const Key('sign-out'),
          icon: const Icon(Icons.logout),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: Text(copy.signOut),
                content: Text(copy.signOutLocalWarning),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(copy.stayAction),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(copy.signOut),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            try {
              await signOutAndWipe(ref);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(copy.signOutFailed)));
              }
            }
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: TokensV0.space16),
          SectionHeading(title: copy.homeTitle, subtitle: copy.homeSubtitle),
          const SizedBox(height: TokensV0.space24),
          if (merge.hasError) ...[
            SliceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(copy.contextPending),
                  TextButton(
                    onPressed: () => ref.invalidate(contextMergeProvider),
                    child: Text(copy.retry),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TokensV0.space16),
          ],
          profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => SliceCard(
              child: Column(
                children: [
                  Text(copy.profileUnavailable),
                  TextButton(
                    onPressed: () => ref.invalidate(firstProfileProvider),
                    child: Text(copy.retry),
                  ),
                ],
              ),
            ),
            data: (CareerProfile value) => SliceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.careerTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: TokensV0.space16),
                  Text(
                    copy.nextAction,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: TokensV0.space8),
                  Text(
                    copy.personalInformation,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (ref
                          .watch(unfinishedDraftProvider(value.id))
                          .valueOrNull ==
                      true) ...[
                    const SizedBox(height: TokensV0.space12),
                    Text(copy.draftAvailable),
                  ],
                  const SizedBox(height: TokensV0.space24),
                  PrimaryAction(
                    key: const Key('continue-career'),
                    label: copy.continueCareer,
                    icon: Icons.arrow_forward,
                    onPressed: () => context.go('/career/personal'),
                  ),
                  const SizedBox(height: TokensV0.space16),
                  Text(
                    copy.moreStepsLater,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
