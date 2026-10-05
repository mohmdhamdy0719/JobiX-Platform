import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/design/form_loading_state.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/profile_sections.dart';
import 'builder_scaffold.dart';
import 'entity_labels.dart';

/// Step 6: every saved section, each with an Edit entry that returns here.
class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    final async = ref.watch(firstProfileProvider);
    final profile = async.valueOrNull;
    return BuilderScaffold(
      step: 6,
      continueLabel: copy.doneAction,
      continueKey: const Key('review-done'),
      onContinue: () => context.go('/career'),
      child: profile == null
          ? Center(
              child: async.hasError
                  ? TextButton(
                      onPressed: () => ref.invalidate(firstProfileProvider),
                      child: Text(copy.retry),
                    )
                  : const FormLoadingState(),
            )
          : _ReviewBody(profile: profile),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.profile});
  final CareerProfile profile;

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final personal = profile.personal;
    String value(String field) => personal[field]?.trim() ?? '';
    void edit(String route) => context.go(route);
    void editItem(EntitySection s, String id) =>
        context.go('/career/edit/${s.key}/$id?origin=review');
    final contact = [
      value('email'),
      value('phone'),
      [value('city'), value('country')].where((v) => v.isNotEmpty).join(', '),
    ].where((v) => v.isNotEmpty).toList();
    final links = [
      value('linkedin_url'),
      value('github_url'),
      value('portfolio_url'),
    ].where((v) => v.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(copy.reviewIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: TokensV0.space16),
        if (profile.completeness != null)
          SliceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${copy.completenessLabel} — ${profile.completeness!.toStringAsFixed(0)}%',
                  key: const Key('review-completeness'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: TokensV0.space8),
                LinearProgressIndicator(value: profile.completeness! / 100),
              ],
            ),
          ),
        const SizedBox(height: TokensV0.space12),
        InactiveSlot(label: copy.aiAuditSoon, icon: Icons.fact_check_outlined),
        const SizedBox(height: TokensV0.space16),
        _Section(
          title: copy.stepPersonal,
          editKey: 'personal',
          onEdit: () => edit('/career/personal?origin=review'),
          children: [
            Text(
              value('full_name').isEmpty
                  ? copy.notProvided
                  : value('full_name'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final line in [...contact, ...links])
              Text(
                line,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodyMedium,
              ),
            if (!profile.hasContact ||
                ['full_name', 'email', 'phone'].any((f) => value(f).isEmpty))
              Padding(
                padding: const EdgeInsetsDirectional.only(top: TokensV0.space4),
                child: Text(
                  copy.reviewPersonalMissing,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: TokensV0.warning,
                  ),
                ),
              ),
          ],
        ),
        _Section(
          title: copy.stepSummary,
          editKey: 'summary',
          onEdit: () => edit('/career/summary?origin=review'),
          children: [
            Text(
              profile.summary.trim().isEmpty
                  ? copy.notProvided
                  : profile.summary.trim(),
            ),
          ],
        ),
        _Section(
          title: copy.targetRoleOptional,
          editKey: 'target_role',
          onEdit: () => edit('/career/target-role?origin=review'),
          children: [
            Text(
              profile.targetRole.trim().isEmpty
                  ? copy.notProvided
                  : profile.targetRole.trim(),
            ),
          ],
        ),
        for (final section in EntitySection.values)
          _Section(
            title: sectionTitle(copy, section),
            editKey: section.key,
            meta:
                section == EntitySection.skill ||
                    section == EntitySection.language ||
                    profile.count(section) == 0
                ? null
                : copy.sectionStatusCount(
                    profile.completeCount(section),
                    profile.count(section),
                  ),
            onEdit: () => edit('/builder/${stepFor(section)}?origin=review'),
            children: [
              if (profile.of(section).isEmpty)
                Text(
                  copy.notProvided,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: TokensV0.textSecondary,
                  ),
                )
              else if (section == EntitySection.skill)
                Wrap(
                  spacing: TokensV0.space8,
                  runSpacing: TokensV0.space8,
                  children: [
                    for (final s in profile.of(section))
                      Chip(label: Text(s.text('name'))),
                  ],
                )
              else
                for (final item in profile.of(section))
                  InkWell(
                    key: Key('review-${section.key}-${item.id}'),
                    onTap: section == EntitySection.language
                        ? null
                        : () => editItem(section, item.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: TokensV0.space4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemTitle(item).isEmpty
                                      ? copy.notProvided
                                      : itemTitle(item),
                                  style: theme.textTheme.titleSmall,
                                ),
                                if (itemSubtitle(copy, item, locale).isNotEmpty)
                                  Text(
                                    itemSubtitle(copy, item, locale),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: TokensV0.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!item.complete)
                            Text(
                              copy.itemIncomplete,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: TokensV0.warning,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.editKey,
    required this.onEdit,
    required this.children,
    this.meta,
  });
  final String title, editKey;
  final String? meta;
  final VoidCallback onEdit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: TokensV0.space12),
      child: SliceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: TokensV0.deepBlue,
                    ),
                  ),
                ),
                if (meta != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: TokensV0.space8,
                    ),
                    child: Text(
                      meta!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: TokensV0.textSecondary,
                      ),
                    ),
                  ),
                TextButton.icon(
                  key: Key('review-edit-$editKey'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(copy.editAction),
                ),
              ],
            ),
            const SizedBox(height: TokensV0.space4),
            ...children,
          ],
        ),
      ),
    );
  }
}
