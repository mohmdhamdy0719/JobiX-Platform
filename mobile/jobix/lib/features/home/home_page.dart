import 'dart:convert';

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
import '../builder/resume_journey.dart';

final unfinishedDraftProvider = FutureProvider.family<bool, String>((
  ref,
  profile,
) async {
  final repository = await ref.watch(draftRepositoryProvider.future);
  final database = repository.database;
  final personal = await database.draftFor(repository.user, profile);
  if (personal != null) {
    try {
      if ((jsonDecode(personal) as Map)['frozen'] != null) return true;
    } catch (_) {
      return true;
    }
  }
  if (await database.pendingMutation(repository.user, profile) != null) {
    return true;
  }
  for (final section in const ['summary', 'target_role']) {
    final raw = await database.sectionDraft(repository.user, profile, section);
    if (raw == null) continue;
    try {
      if ((jsonDecode(raw) as Map)['request'] != null) return true;
    } catch (_) {
      return true;
    }
  }
  final extras = await database.setting('extras:${repository.user}:$profile');
  if (extras != null) {
    try {
      if ((jsonDecode(extras) as Map)['pending'] != null) return true;
    } catch (_) {
      return true;
    }
  }
  return await database.setting('resume:${repository.user}:layout:$profile') !=
      null;
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
      actions: const [CreditsPill()],
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
              final journey = ref.watch(resumeJourneyProvider(value.id));
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
                    const SizedBox(height: TokensV0.space16),
                    InactiveSlot(
                      label: copy.aiAuditSoon,
                      icon: Icons.fact_check_outlined,
                    ),
                    const SizedBox(height: TokensV0.space16),
                    PrimaryAction(
                      key: const Key('continue-career'),
                      label: copy.continueCareer,
                      icon: Icons.arrow_forward,
                      onPressed: () => context.go('/career'),
                    ),
                    if (journey.hasError)
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(resumeJourneyProvider(value.id)),
                        child: Text(copy.retry),
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
