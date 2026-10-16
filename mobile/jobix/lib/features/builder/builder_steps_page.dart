import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/form_loading_state.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/entity_repository.dart';
import '../career_profile/profile_sections.dart';
import 'builder_scaffold.dart';
import 'entity_cards.dart';
import 'entity_editor_page.dart';
import 'save_feedback.dart';
import 'language_editor_sheet.dart';

/// Small local catalog for type-to-add. Custom skills are always allowed.
const skillCatalog = [
  'Communication', 'Teamwork', 'Leadership', 'Problem Solving', //
  'Project Management', 'Microsoft Excel', 'Data Analysis', 'SQL',
  'Python', 'JavaScript', 'Flutter', 'Customer Service', 'Sales',
  'Marketing', 'Accounting', 'Graphic Design', 'Public Speaking',
  'Time Management', 'Research', 'Writing',
];

const stepSections = {
  3: [EntitySection.experience, EntitySection.volunteer],
  4: [
    EntitySection.education,
    EntitySection.certification,
    EntitySection.achievement,
  ],
  5: [EntitySection.skill, EntitySection.project, EntitySection.language],
};

/// Steps 3–5: repeatable sections. Saves happen per item, so Continue only
/// navigates; every step can be skipped.
class BuilderSectionsStep extends ConsumerStatefulWidget {
  const BuilderSectionsStep({
    required this.step,
    this.origin = EditorOrigin.builder,
    super.key,
  });
  final int step;

  /// From Review, the step is a section editor: Back and Continue return
  /// to Review, and item editors return there after saving.
  final EditorOrigin origin;
  bool get fromReview => origin == EditorOrigin.review;
  @override
  ConsumerState<BuilderSectionsStep> createState() =>
      _BuilderSectionsStepState();
}

class _BuilderSectionsStepState extends ConsumerState<BuilderSectionsStep> {
  bool busy = false, resumed = false;
  SaveIssue? issue;
  final skillController = TextEditingController();
  final skillFocus = FocusNode();

  @override
  void dispose() {
    skillController.dispose();
    skillFocus.dispose();
    super.dispose();
  }

  Future<void> recover(CareerProfile profile) async {
    if (resumed) return;
    resumed = true;
    try {
      final repository = await ref.read(entityRepositoryProvider.future);
      // Navigating Back must not submit anything. Preserve interrupted Save
      // identity and let the explicit Retry action reconcile its outcome.
      if (await repository.pending(profile.id) != null && mounted) {
        setState(() => issue = SaveIssue.pending);
      }
    } catch (error) {
      if (mounted) setState(() => issue = saveIssue(error));
    }
  }

  Future<void> run(
    Future<CareerProfile> Function(EntityRepository repository) action,
  ) async {
    if (!mounted || busy) return;
    setState(() {
      busy = true;
      issue = null;
    });
    try {
      final repository = await ref.read(entityRepositoryProvider.future);
      await action(repository);
      if (mounted) ref.invalidate(firstProfileProvider);
    } catch (error) {
      if (mounted) setState(() => issue = saveIssue(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> retry(CareerProfile profile) async {
    setState(() => busy = true);
    try {
      final repository = await ref.read(entityRepositoryProvider.future);
      await repository.resume(profile.id);
      ref.invalidate(firstProfileProvider);
      if (mounted) setState(() => issue = null);
    } catch (error) {
      if (mounted) setState(() => issue = saveIssue(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void openEditor(EntitySection section, String id) => context.go(
    '/career/edit/${section.key}/$id?origin=${widget.origin.name}',
  );

  Future<void> remove(CareerProfile profile, ProfileItem item) async {
    if (!await confirmRemove(context)) return;
    await run((r) => r.delete(profile, item.section, item.id));
  }

  Future<void> addSkill(CareerProfile profile, String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return;
    if (profile
        .of(EntitySection.skill)
        .any((s) => nameKey(s.text('name')) == nameKey(name))) {
      setState(() => issue = SaveIssue.duplicate);
      return;
    }
    skillController.clear();
    await run(
      (r) => r.upsert(
        profile,
        ProfileItem(
          id: newCommandKey(),
          section: EntitySection.skill,
          values: {'name': name},
        ),
      ),
    );
  }

  Future<void> languageSheet(
    CareerProfile profile, [
    ProfileItem? existing,
  ]) async {
    final result = await showModalBottomSheet<ProfileItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => LanguageEditorSheet(existing: existing),
    );
    if (result == null || !mounted) return;
    final duplicate = profile
        .of(EntitySection.language)
        .any(
          (l) =>
              l.id != result.id &&
              nameKey(l.text('name')) == nameKey(result.text('name')),
        );
    if (duplicate) {
      setState(() => issue = SaveIssue.duplicate);
      return;
    }
    await run((r) => r.upsert(profile, result));
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final async = ref.watch(firstProfileProvider);
    final profile = async.valueOrNull;
    if (profile != null) unawaited(recover(profile));
    final sections = stepSections[widget.step]!;
    final next = widget.step + 1;
    final total = profile == null
        ? 0
        : sections.fold<int>(0, (sum, s) => sum + profile.count(s));
    return BuilderScaffold(
      step: widget.step,
      reviewEditor: widget.fromReview,
      busy: busy,
      meta: total > 0 ? copy.itemsAdded(total) : null,
      onBack: () => context.go(
        widget.fromReview
            ? '/builder/6'
            : widget.origin == EditorOrigin.career
            ? '/career'
            : '/builder/${widget.step - 1}',
      ),
      onContinue: profile == null
          ? null
          : () =>
                context.go(widget.fromReview ? '/builder/6' : '/builder/$next'),
      continueLabel: widget.fromReview
          ? copy.backToReview
          : total == 0 && widget.step == 3
          ? copy.skipAction
          : null,
      child: profile == null
          ? Center(
              child: async.hasError
                  ? TextButton(
                      onPressed: () => ref.invalidate(firstProfileProvider),
                      child: Text(copy.retry),
                    )
                  : const FormLoadingState(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (issue != null) ...[
                  saveIssueCard(saveIssueText(copy, issue!), switch (issue!) {
                    SaveIssue.pending ||
                    SaveIssue.unknown => (copy.retrySave, () => retry(profile)),
                    SaveIssue.conflict => (
                      copy.reloadAction,
                      () {
                        ref.invalidate(firstProfileProvider);
                        setState(() => issue = null);
                      },
                    ),
                    _ => null,
                  }),
                  const SizedBox(height: TokensV0.space16),
                ],
                for (final section in sections) ...[
                  if (section == EntitySection.skill)
                    _skills(copy, profile)
                  else
                    EntityCardList(
                      section: section,
                      items: profile.of(section),
                      enabled: !busy,
                      showHeading: sections.length > 1,
                      onAdd: section == EntitySection.language
                          ? () => languageSheet(profile)
                          : () => openEditor(section, 'new'),
                      onEdit: (item) => section == EntitySection.language
                          ? languageSheet(profile, item)
                          : openEditor(section, item.id),
                      onRemove: (item) => remove(profile, item),
                    ),
                  const SizedBox(height: TokensV0.space24),
                  if (section == EntitySection.volunteer) ...[
                    Text(
                      copy.volunteerEvidenceHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: TokensV0.textSecondary,
                      ),
                    ),
                    const SizedBox(height: TokensV0.space16),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _skills(AppLocalizations copy, CareerProfile profile) {
    final skills = profile.of(EntitySection.skill);
    final taken = skills.map((s) => nameKey(s.text('name'))).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          copy.sectionSkills,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: TokensV0.space8),
        Wrap(
          spacing: TokensV0.space8,
          runSpacing: TokensV0.space8,
          children: [
            for (final skill in skills)
              InputChip(
                key: Key('skill-${skill.id}'),
                label: Text(skill.text('name')),
                onDeleted: busy ? null : () => remove(profile, skill),
                deleteButtonTooltipMessage: copy.removeAction,
              ),
          ],
        ),
        const SizedBox(height: TokensV0.space8),
        Row(
          children: [
            Expanded(
              child: RawAutocomplete<String>(
                textEditingController: skillController,
                focusNode: skillFocus,
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(TokensV0.cardRadius),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 220,
                        maxWidth: 320,
                      ),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final option in options)
                            ListTile(
                              dense: true,
                              title: Text(option),
                              onTap: () => onSelected(option),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                optionsBuilder: (value) {
                  final query = nameKey(value.text);
                  if (query.isEmpty) return const [];
                  return skillCatalog.where(
                    (s) =>
                        nameKey(s).contains(query) &&
                        !taken.contains(nameKey(s)),
                  );
                },
                // Selection edits the input; only Add/submit commits it.
                onSelected: (value) => skillController.text = value,
                fieldViewBuilder: (context, controller, focus, submit) {
                  return TextField(
                    key: const Key('skill-input'),
                    controller: controller,
                    focusNode: focus,
                    maxLength: 100,
                    enabled: !busy,
                    decoration: InputDecoration(
                      hintText: copy.skillHint,
                      counterText: '',
                    ),
                    onSubmitted: (value) => addSkill(profile, value),
                  );
                },
              ),
            ),
            const SizedBox(width: TokensV0.space8),
            FilledButton.tonal(
              key: const Key('skill-add'),
              onPressed: busy
                  ? null
                  : () => addSkill(profile, skillController.text),
              child: Text(copy.addAction),
            ),
          ],
        ),
      ],
    );
  }
}
