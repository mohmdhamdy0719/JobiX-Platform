import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/design/form_loading_state.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../builder/builder_scaffold.dart';
import '../builder/entity_labels.dart';
import '../builder/profile_overview.dart';
import '../builder/resume_journey.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/profile_sections.dart';
import '../resume/resume_language_repository.dart';
import 'resume_language_dialog.dart';
import 'authenticated_navigation.dart';

/// Career overview: one card per section, real saved data only.
class CareerPage extends ConsumerWidget {
  const CareerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    final profile = ref.watch(firstProfileProvider);
    return SliceScaffold(
      title: copy.careerNav,
      leading: const BrandMark(size: 32),
      actions: const [CreditsPill()],
      bottom: const AuthenticatedNavigation(selected: 1),
      child: profile.when(
        loading: () => const FormLoadingState(),
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
        data: (value) => _CareerBody(profile: value),
      ),
    );
  }
}

class _CareerBody extends ConsumerWidget {
  const _CareerBody({required this.profile});
  final CareerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final p = profile.personal;
    String field(String f) => (p[f] ?? '').trim();
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: TokensV0.textSecondary,
    );
    Widget empty() => Text(copy.notProvided, style: secondary);
    Widget lines(EntitySection s, {int max = 2}) {
      final items = profile.of(s);
      if (items.isEmpty) return empty();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items.take(max))
            Padding(
              padding: const EdgeInsetsDirectional.only(top: TokensV0.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemTitle(item, locale).isEmpty
                        ? copy.notProvided
                        : itemTitle(item, locale),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (itemSubtitle(copy, item, locale).isNotEmpty)
                    Text(itemSubtitle(copy, item, locale), style: secondary),
                ],
              ),
            ),
          if (items.length > max)
            Text(copy.moreCount(items.length - max), style: secondary),
        ],
      );
    }

    String? count(EntitySection s) =>
        profile.count(s) == 0 ? null : copy.itemsAdded(profile.count(s));
    final skills = profile.of(EntitySection.skill);
    final languages = profile.of(EntitySection.language);
    final location = [
      field('city'),
      field('country'),
    ].where((v) => v.isNotEmpty).join(', ');
    final contactDone = [
      'full_name',
      'email',
      'phone',
    ].where((f) => field(f).isNotEmpty).length;
    final journey = ref.watch(resumeJourneyProvider(profile.id));
    final savedLanguage = ref.watch(savedResumeLanguageProvider(profile.id));
    final resumeLanguageReady = const [
      'en',
      'ar',
    ].contains(savedLanguage.valueOrNull ?? profile.resumeLanguage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryAction(
          key: const Key('career-resume'),
          label: Localizations.localeOf(context).languageCode == 'ar'
              ? 'إنشاء السيرة الذاتية'
              : 'Build resume',
          icon: Icons.description_outlined,
          onPressed:
              !resumeLanguageReady || journey.isLoading || journey.hasError
              ? null
              : () => context.go(
                  journey.valueOrNull?.complete == true
                      ? '/resume'
                      : '/builder/${journey.valueOrNull?.step ?? 1}',
                ),
        ),
        const SizedBox(height: TokensV0.space16),
        SliceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconTile(icon: Icons.badge_outlined),
                  const SizedBox(width: TokensV0.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.targetRole.trim().isEmpty
                              ? copy.careerTitle
                              : profile.targetRole.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(copy.profileSlot(profile.slot), style: secondary),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile.completeness != null) ...[
                const SizedBox(height: TokensV0.space16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        copy.completenessLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Text(
                      '${profile.completeness!.toStringAsFixed(0)}%',
                      key: const Key('career-completeness'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TokensV0.space8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(TokensV0.pillRadius),
                  child: LinearProgressIndicator(
                    value: profile.completeness! / 100,
                    minHeight: 6,
                    backgroundColor: TokensV0.surfaceContainer,
                  ),
                ),
              ],
              const SizedBox(height: TokensV0.space12),
              InactiveSlot(
                label: copy.aiAuditSoon,
                icon: Icons.fact_check_outlined,
              ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const Key('career-change-resume-language'),
            onPressed: () =>
                showCareerResumeLanguageDialog(context, ref, profile),
            icon: const Icon(Icons.translate),
            label: Text(copy.changeResumeLanguage),
          ),
        ),
        if (!resumeLanguageReady) ...[
          SliceCard(child: Text(copy.chooseResumeLanguage)),
        ] else ...[
          const SizedBox(height: TokensV0.space16),
          _SectionCard(
            key: const Key('career-edit-personal'),
            icon: Icons.person_outline,
            title: copy.personalInformation,
            badge: '$contactDone/3',
            done: contactDone == 3,
            onTap: () => context.go('/career/personal'),
            child: field('full_name').isEmpty && location.isEmpty
                ? empty()
                : Text(
                    [
                      field('full_name'),
                      location,
                    ].where((v) => v.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: secondary,
                  ),
          ),
          _SectionCard(
            key: const Key('career-edit-summary'),
            icon: Icons.notes_outlined,
            title: copy.stepSummary,
            onTap: () => context.go('/career/summary'),
            child: profile.summary.trim().isEmpty
                ? empty()
                : Text(
                    profile.summary.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
          ),
          _SectionCard(
            key: const Key('career-experience'),
            icon: Icons.work_outline,
            title: copy.stepExperience,
            badge: count(EntitySection.experience),
            done: profile.completeCount(EntitySection.experience) > 0,
            onTap: () => context.go('/career/section/experience'),
            trailing: TextButton.icon(
              key: const Key('career-add-experience'),
              onPressed: () =>
                  context.go('/career/edit/experience/new?origin=career'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(copy.addAction),
            ),
            child: lines(EntitySection.experience),
          ),
          _SectionCard(
            key: const Key('career-volunteer'),
            icon: Icons.volunteer_activism_outlined,
            title: copy.sectionVolunteer,
            badge: count(EntitySection.volunteer),
            done: false,
            onTap: () => context.go('/career/section/volunteer'),
            trailing: TextButton.icon(
              key: const Key('career-add-volunteer'),
              onPressed: () =>
                  context.go('/career/edit/volunteer/new?origin=career'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(copy.addAction),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [lines(EntitySection.volunteer)],
            ),
          ),
          _SectionCard(
            key: const Key('career-education'),
            icon: Icons.school_outlined,
            title: sectionTitle(copy, EntitySection.education),
            badge: count(EntitySection.education),
            done: profile.completeCount(EntitySection.education) > 0,
            onTap: () => context.go('/career/section/education'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [lines(EntitySection.education, max: 1)],
            ),
          ),
          _SectionCard(
            key: const Key('career-certifications'),
            icon: Icons.workspace_premium_outlined,
            title: copy.sectionCertifications,
            badge: count(EntitySection.certification),
            onTap: () => context.go('/career/section/certification'),
            child: lines(EntitySection.certification),
          ),
          _SectionCard(
            key: const Key('career-achievements'),
            icon: Icons.emoji_events_outlined,
            title: copy.sectionAchievements,
            badge: count(EntitySection.achievement),
            onTap: () => context.go('/career/section/achievement'),
            child: lines(EntitySection.achievement),
          ),
          _SectionCard(
            key: const Key('career-skills-languages'),
            icon: Icons.psychology_outlined,
            title: copy.skillsAndLanguages,
            badge: skills.isEmpty && languages.isEmpty
                ? null
                : '${skills.length} · ${languages.length}',
            done: skills.isNotEmpty || languages.isNotEmpty,
            onTap: () => context.go('/career/section/skills-languages'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (skills.isNotEmpty)
                  Wrap(
                    spacing: TokensV0.space8,
                    runSpacing: TokensV0.space8,
                    children: [
                      for (final s in skills.take(6))
                        _Tag(label: s.text('name')),
                      if (skills.length > 6)
                        _Tag(
                          label: copy.moreCount(skills.length - 6),
                          muted: true,
                        ),
                    ],
                  )
                else
                  empty(),
                const SizedBox(height: TokensV0.space8),
                if (languages.isEmpty)
                  empty()
                else
                  Text(
                    languages
                        .map(
                          (l) =>
                              '${l.text('name')} (${proficiencyLabel(copy, l.text('proficiency'))})',
                        )
                        .join(' · '),
                  ),
              ],
            ),
          ),
          _SectionCard(
            key: const Key('career-projects'),
            icon: Icons.folder_outlined,
            title: copy.sectionProjects,
            badge: count(EntitySection.project),
            onTap: () => context.go('/career/section/project'),
            child: lines(EntitySection.project),
          ),
        ],
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: TokensV0.surfaceContainerLow,
      borderRadius: BorderRadius.circular(TokensV0.controlRadius),
    ),
    child: Icon(icon, color: TokensV0.deepBlue, size: 20),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.child,
    this.badge,
    this.done = false,
    this.trailing,
    super.key,
  });
  final IconData icon;
  final String title;
  final String? badge;
  final bool done;
  final VoidCallback onTap;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: TokensV0.space12),
      child: Material(
        color: TokensV0.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TokensV0.cardRadius),
          side: const BorderSide(color: TokensV0.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(TokensV0.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(TokensV0.space16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconTile(icon: icon),
                const SizedBox(width: TokensV0.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: TokensV0.space8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (badge != null)
                            _Tag(
                              label: badge!,
                              color: done
                                  ? TokensV0.success
                                  : TokensV0.textSecondary,
                            ),
                        ],
                      ),
                      const SizedBox(height: TokensV0.space4),
                      child,
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.chevron_right,
                      color: TokensV0.textSecondary,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color, this.muted = false});
  final String label;
  final Color? color;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final tone = color ?? (muted ? TokensV0.textSecondary : TokensV0.deepBlue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? TokensV0.secondarySurface : tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TokensV0.chipRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tone,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
