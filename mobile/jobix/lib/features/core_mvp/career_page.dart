import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'authenticated_navigation.dart';
import 'core_api.dart';

class CareerPage extends ConsumerWidget {
  const CareerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    final profile = ref.watch(firstProfileProvider);
    return SliceScaffold(
      title: copy.careerNav,
      leading: const BrandMark(size: 32),
      bottom: const AuthenticatedNavigation(selected: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: copy.careerPageTitle,
            subtitle: copy.careerPageSubtitle,
          ),
          const SizedBox(height: TokensV0.space20),
          ref
              .watch(coreSummaryProvider)
              .when(
                loading: () => const _CareerLoading(),
                error: (_, __) => SliceCard(
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
                data: (summary) => SliceCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: TokensV0.deepBlue,
                      ),
                      const SizedBox(width: TokensV0.space12),
                      Expanded(child: Text(copy.availableCredits)),
                      Text(
                        '${summary.balance.available}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: TokensV0.space8),
                      IconButton(
                        tooltip: copy.viewHistory,
                        onPressed: () => context.go('/credits'),
                        icon: const Icon(Icons.history),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: TokensV0.space16),
          profile.when(
            loading: () => const _CareerLoading(),
            error: (_, __) => SliceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(copy.profileUnavailable),
                  const SizedBox(height: TokensV0.space8),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(firstProfileProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(copy.retry),
                  ),
                ],
              ),
            ),
            data: (value) => SliceCard(
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
                              copy.careerTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              copy.activeProfile,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TokensV0.space16),
                  Text(
                    copy.profileTruthNote,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: TokensV0.space16),
                  _CareerDetail(
                    label: copy.personalInformation,
                    value:
                        value.personal['full_name']?.trim().isNotEmpty == true
                        ? value.personal['full_name']!
                        : copy.notEntered,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: TokensV0.space12),
                  _CareerDetail(
                    label: copy.resumeLanguage,
                    value: switch (value.resumeLanguage) {
                      'ar' => copy.arabicLanguage,
                      'en' => copy.englishLanguage,
                      _ => copy.notEntered,
                    },
                    icon: Icons.translate,
                  ),
                  const SizedBox(height: TokensV0.space20),
                  PrimaryAction(
                    key: const Key('career-edit-personal'),
                    label: copy.editPersonalInformation,
                    icon: Icons.arrow_forward,
                    onPressed: () => context.go('/career/personal'),
                  ),
                  const SizedBox(height: TokensV0.space12),
                  Text(
                    copy.careerOtherSectionsUnavailable,
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

class _CareerLoading extends StatelessWidget {
  const _CareerLoading();
  @override
  Widget build(BuildContext context) => const SliceCard(
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: TokensV0.surfaceContainer,
            borderRadius: BorderRadius.all(
              Radius.circular(TokensV0.controlRadius),
            ),
          ),
          child: SizedBox(width: 44, height: 44),
        ),
        SizedBox(width: TokensV0.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: TokensV0.surfaceContainer,
                  borderRadius: BorderRadius.all(
                    Radius.circular(TokensV0.chipRadius),
                  ),
                ),
                child: SizedBox(width: 136, height: 14),
              ),
              SizedBox(height: TokensV0.space8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: TokensV0.surfaceContainer,
                  borderRadius: BorderRadius.all(
                    Radius.circular(TokensV0.chipRadius),
                  ),
                ),
                child: SizedBox(width: 196, height: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CareerDetail extends StatelessWidget {
  const _CareerDetail({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: TokensV0.iconSize, color: TokensV0.textSecondary),
      const SizedBox(width: TokensV0.space12),
      Expanded(child: Text(label)),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    ],
  );
}
