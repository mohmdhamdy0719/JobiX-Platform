import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../core_mvp/authenticated_navigation.dart';
import '../builder/builder_scaffold.dart';
import '../builder/profile_overview.dart';
import '../core_mvp/core_api.dart';

final unfinishedDraftProvider = FutureProvider.family<bool, String>((
  ref,
  profile,
) async {
  final repository = await ref.watch(draftRepositoryProvider.future);
  return await repository.database.draftFor(repository.user, profile) != null ||
      await repository.database.hasSectionDrafts(repository.user, profile);
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    final profile = ref.watch(firstProfileProvider);
    final merge = ref.watch(contextMergeProvider);
    final balance = ref.watch(coreSummaryProvider);
    final theme = Theme.of(context);
    final name = (profile.valueOrNull?.personal['full_name'] ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    return SliceScaffold(
      title: copy.appTitle,
      leading: const BrandMark(size: 40),
      actions: [
        const CreditsPill(),
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
      bottom: const AuthenticatedNavigation(selected: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? copy.homeTitle : copy.welcomeBack(name),
            key: const Key('home-welcome'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: TokensV0.space4),
          Text(copy.homeOverview, style: theme.textTheme.bodyMedium),
          const SizedBox(height: TokensV0.space20),
          if (balance.hasError) ...[
            SliceCard(
              child: Row(
                children: [
                  Expanded(child: Text(copy.balanceUnavailable)),
                  IconButton(
                    tooltip: copy.retry,
                    onPressed: () => ref.invalidate(coreSummaryProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TokensV0.space16),
          ],
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
            data: (CareerProfile value) {
              final remaining = sectionsRemaining(value);
              return SliceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: TokensV0.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              TokensV0.controlRadius,
                            ),
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            color: TokensV0.deepBlue,
                          ),
                        ),
                        const SizedBox(width: TokensV0.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value.targetRole.trim().isEmpty
                                    ? copy.careerTitle
                                    : value.targetRole.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                copy.profileSlot(value.slot),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TokensV0.space16),
                    Row(
                      children: [
                        CompletenessRing(percent: value.completeness ?? 0),
                        const SizedBox(width: TokensV0.space16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                copy.completenessLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (remaining > 0)
                                Text(
                                  copy.sectionsRemaining(remaining),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: TokensV0.warning,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (ref
                            .watch(unfinishedDraftProvider(value.id))
                            .valueOrNull ==
                        true) ...[
                      const SizedBox(height: TokensV0.space12),
                      Text(copy.draftAvailable),
                    ],
                    const SizedBox(height: TokensV0.space16),
                    InactiveSlot(
                      label: copy.aiAuditSoon,
                      icon: Icons.fact_check_outlined,
                    ),
                    const SizedBox(height: TokensV0.space16),
                    PrimaryAction(
                      key: const Key('continue-career'),
                      label: copy.continueProfile,
                      icon: Icons.arrow_forward,
                      onPressed: () =>
                          context.go('/builder/${nextBuilderStep(value)}'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
