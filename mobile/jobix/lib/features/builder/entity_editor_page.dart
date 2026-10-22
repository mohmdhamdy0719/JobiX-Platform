import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/design/form_loading_state.dart';
import '../../core/design/jobix_dialog.dart';
import '../../core/design/jobix_feedback.dart';
import 'profile_overview.dart';
import '../../core/navigation/back_policy.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/career_profile_repository.dart';
import '../career_profile/entity_repository.dart';
import '../career_profile/profile_sections.dart';
import 'builder_scaffold.dart';
import 'entity_labels.dart';
import 'save_feedback.dart';
import 'month_input_formatter.dart';
import 'section_writing_guidance.dart';
import 'jobix_improvement.dart';
import 'education_catalog.dart';

String editorReturn(EntitySection section, EditorOrigin origin) =>
    switch (origin) {
      EditorOrigin.review => '/builder/6',
      EditorOrigin.career => '/career',
      EditorOrigin.builder => '/builder/${stepFor(section)}',
    };

/// Dedicated Back/Save editor shared by every repeatable section.
class EntityEditorPage extends ConsumerStatefulWidget {
  const EntityEditorPage({
    required this.section,
    required this.itemId,
    required this.origin,
    super.key,
  });
  final EntitySection section;
  final String itemId; // 'new' creates a client-generated id.
  final EditorOrigin origin;
  @override
  ConsumerState<EntityEditorPage> createState() => _EntityEditorPageState();
}

class _EntityEditorPageState extends ConsumerState<EntityEditorPage> {
  final controllers = <String, TextEditingController>{};
  final degreeOtherController = TextEditingController();
  CareerProfile? profile;
  ProfileItem? item;
  Map<String, FieldProblem> problems = {};
  bool busy = false, failed = false;
  SaveIssue? issue;
  bool leaving = false, saveAttempted = false;
  bool get savePending => issue == SaveIssue.unknown;
  ProfileItem? serverDraft;
  ProfileItem? localDraftItem;
  bool get dirty =>
      item != null &&
      (localDraftItem != null || serverItem != null || serverDraft != null) &&
      jsonEncode(item!.payload()) !=
          jsonEncode((localDraftItem ?? serverItem ?? serverDraft)!.payload());

  /// Set while the draft's baseline differs from the server item; Save is
  /// blocked until the user picks a version.
  DraftConflict conflict = DraftConflict.none;
  ProfileItem? serverItem;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    degreeOtherController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final repository = await ref.read(entityRepositoryProvider.future);
      final value = await repository.parent.load();
      if (!mounted) return;
      await repository.parent.draft(value);
      final unresolved = await repository.pending(value.id);
      final recovered = widget.itemId == 'new'
          ? (await repository.unsavedNew(value, widget.section)).firstOrNull
          : null;
      final id = widget.itemId == 'new'
          ? recovered?.id ?? newCommandKey()
          : widget.itemId;
      final sectionItems = value.items[widget.section] ?? const [];
      final saved = sectionItems
          .where((i) => i.id == id && !i.isDraft)
          .firstOrNull;
      final persistedDraft = sectionItems
          .where((i) => i.id == id && i.isDraft && !i.isLocalDraft)
          .firstOrNull;
      final local = await repository.draft(value.id, widget.section, id);
      final current =
          local ??
          persistedDraft ??
          saved ??
          ProfileItem(id: id, section: widget.section);
      if (!mounted) return;
      _fill(current);
      setState(() {
        profile = value;
        item = current;
        serverItem = saved;
        serverDraft = persistedDraft;
        localDraftItem = local?.isLocalDraft == true ? local : null;
        issue = unresolved == null ? null : SaveIssue.unknown;
        conflict = unresolved != null || local == null
            ? DraftConflict.none
            : draftConflict(local, saved ?? persistedDraft);
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  void edit(String field, Object? value) {
    if (busy || leaving || savePending || item == null) return;
    final next = item!.copyWith(field, value);
    setState(() {
      item = next;
      problems = {};
      issue = null;
      saveAttempted = false;
    });
  }

  void close() => context.go(editorReturn(widget.section, widget.origin));

  Future<void> leave() async {
    if (busy || leaving) return;
    leaving = true;
    try {
      final repository = item != null && profile != null
          ? await ref.read(entityRepositoryProvider.future)
          : null;
      final pending = repository == null
          ? null
          : await repository.pending(profile!.id);
      if (!mounted) return;
      final pendingItem = pending != null;
      if (item != null &&
          (pendingItem ||
              (serverItem != null ||
                      serverDraft != null ||
                      localDraftItem != null) &&
                  dirty)) {
        final copy = AppLocalizations.of(context)!;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => JobixAlertDialog(
            title: Text(copy.leaveTitle),
            content: Text(
              pendingItem
                  ? copy.pendingBackWarning
                  : serverDraft != null || localDraftItem != null
                  ? (copy.localeName.startsWith('ar')
                        ? 'سيتم تجاهل التغييرات التي أجريتها هنا، وستبقى المسودة المحفوظة على هذا الجهاز كما هي.'
                        : 'Changes made in this editing session will be discarded. The saved device-only draft will remain unchanged.')
                  : copy.discardWarning,
            ),
            actions: [
              JobixDialogAction.secondary(
                onPressed: () => Navigator.pop(context, false),
                child: Text(copy.stayAction),
              ),
              JobixDialogAction.destructive(
                key: const Key('discard-entity'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(pendingItem ? copy.backAction : copy.discardAction),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return;
      }
      if (!mounted) return;
      if (mounted) close();
    } catch (error) {
      final repository = await ref.read(entityRepositoryProvider.future);
      final failure = profile == null
          ? SaveIssue.rejected
          : await confirmedSaveIssue(error, repository, profile!.id);
      if (mounted) setState(() => issue = failure);
    } finally {
      leaving = false;
    }
  }

  void _fill(ProfileItem source) {
    for (final field in widget.section.fields) {
      if (field.kind == FieldKind.toggle) continue;
      final text = field.kind == FieldKind.list
          ? source.list(field.name).join(', ')
          : source.text(field.name);
      (controllers[field.name] ??= TextEditingController()).text = text;
    }
    if (widget.section == EntitySection.education) {
      final value = source.text('degree');
      final selected = degreeOption(value);
      degreeOtherController.text = selected == 'degree:other'
          ? value.startsWith('other:')
                ? value.substring(6)
                : value
          : '';
    }
  }

  /// Discards local edits in favour of the server copy (or leaves when the
  /// item was removed elsewhere).
  Future<void> keepServer() async {
    if (!mounted) return;
    final repository = await ref.read(entityRepositoryProvider.future);
    await repository.discardDraft(profile!.id, widget.section, item!.id);
    final server = serverItem ?? serverDraft;
    if (server == null) {
      if (mounted) close();
      return;
    }
    if (mounted) {
      _fill(server);
      setState(() {
        item = server;
        localDraftItem = null;
        conflict = DraftConflict.none;
        problems = {};
      });
      ref.invalidate(
        entityDraftsProvider(EntityDraftQuery(profile!.id, widget.section)),
      );
    }
  }

  /// Keeps local edits on top of the latest server baseline, by choice.
  Future<void> reapplyLocal() async {
    if (!mounted) return;
    final next = item!.rebased((serverItem ?? serverDraft)?.version ?? 0);
    if (mounted) {
      setState(() {
        item = next;
        conflict = DraftConflict.none;
      });
    }
  }

  Future<void> save() async {
    if (busy ||
        leaving ||
        savePending ||
        item == null ||
        conflict != DraftConflict.none) {
      return;
    }
    final copy = item!;
    setState(() => saveAttempted = true);
    final found = copy.problems();
    final blocking = found.values.any(
      (problem) => problem != FieldProblem.required,
    );
    if (blocking) {
      setState(() => problems = found);
      return;
    }
    var saveAsDraft = false;
    if (found.isNotEmpty) {
      final ar = AppLocalizations.of(context)!.localeName.startsWith('ar');
      if (serverItem != null) {
        // An incomplete edit must never unpublish the saved Complete row.
        // Keep these changes in the editor until corrected or abandoned.
        setState(() => problems = found);
        showJobixFeedback(
          context,
          ar
              ? 'أكمل الحقول المطلوبة قبل الحفظ. لم يتغير الإدخال المحفوظ.'
              : 'Complete the required fields before saving. Your saved entry is unchanged.',
        );
        return;
      }
      if (!copy.hasMeaningfulInput) {
        setState(() => problems = found);
        showJobixFeedback(
          context,
          AppLocalizations.of(context)!.draftNeedsInformation,
          kind: JobixFeedbackKind.error,
        );
        return;
      }
      final saveDraft = await showDialog<bool>(
        context: context,
        builder: (dialog) => JobixAlertDialog(
          title: Text(ar ? 'حفظ كمسودة؟' : 'Save as draft?'),
          content: Text(AppLocalizations.of(context)!.saveDraftPrompt),
          actions: [
            JobixDialogAction.secondary(
              key: const Key('back-from-entry-draft-confirmation'),
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(ar ? 'رجوع' : 'Back'),
            ),
            JobixDialogAction.primary(
              key: const Key('save-entry-as-draft'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(ar ? 'حفظ كمسودة' : 'Save as draft'),
            ),
          ],
        ),
      );
      if (saveDraft != true || !mounted) return;
      saveAsDraft = true;
    }
    setState(() => busy = true);
    try {
      final repository = await ref.read(entityRepositoryProvider.future);
      if (saveAsDraft) {
        await repository.saveLocalDraft(profile!.id, copy);
      } else {
        await repository.upsert(profile!, copy);
        ref.invalidate(firstProfileProvider);
      }
      ref.invalidate(
        entityDraftsProvider(EntityDraftQuery(profile!.id, widget.section)),
      );
      if (mounted) {
        showJobixFeedback(
          context,
          saveAsDraft
              ? AppLocalizations.of(context)!.savedDevice
              : copy.section == EntitySection.education
              ? (AppLocalizations.of(context)!.localeName.startsWith('ar')
                    ? 'تم حفظ المؤهل.'
                    : 'Education saved.')
              : (AppLocalizations.of(context)!.localeName.startsWith('ar')
                    ? 'تم حفظ التغييرات.'
                    : 'Changes saved.'),
        );
      }
      if (mounted) close();
    } on LocalDraftSavedException {
      ref.invalidate(
        entityDraftsProvider(EntityDraftQuery(profile!.id, widget.section)),
      );
      if (mounted) {
        showJobixFeedback(context, AppLocalizations.of(context)!.savedDevice);
        close();
      }
    } catch (error) {
      final repository = await ref.read(entityRepositoryProvider.future);
      final failure = await confirmedSaveIssue(error, repository, profile!.id);
      if (mounted) setState(() => issue = failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> retryPending() async {
    setState(() => busy = true);
    try {
      final repository = await ref.read(entityRepositoryProvider.future);
      final result = await repository.resume(profile!.id);
      if (result != null) {
        ref.invalidate(firstProfileProvider);
        ref.invalidate(
          entityDraftsProvider(EntityDraftQuery(profile!.id, widget.section)),
        );
        profile = result;
        if (mounted) {
          showJobixFeedback(context, AppLocalizations.of(context)!.savedServer);
          close();
        }
      } else if (mounted) {
        setState(() => issue = null);
      }
    } catch (error) {
      final repository = await ref.read(entityRepositoryProvider.future);
      final failure = await confirmedSaveIssue(error, repository, profile!.id);
      if (mounted) setState(() => issue = failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reload() async {
    ref.invalidate(firstProfileProvider);
    final repository = await ref.read(entityRepositoryProvider.future);
    final value = await repository.parent.load(freshOnly: true);
    final server = value
        .of(widget.section)
        .where((i) => i.id == item!.id)
        .firstOrNull;
    final persistedDraft =
        (value.items[widget.section] ?? const <ProfileItem>[])
            .where((i) => i.id == item!.id && i.isDraft)
            .firstOrNull;
    if (mounted) {
      setState(() {
        profile = value;
        serverItem = server;
        serverDraft = persistedDraft;
        // Unchanged item: retrying on the new profile version is safe.
        // Changed or removed item: the user must choose explicitly.
        conflict = draftConflict(item!, server ?? persistedDraft);
        issue = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final title = sectionTitle(copy, widget.section);
    final back = IconButton(
      key: const Key('editor-back'),
      tooltip: copy.backAction,
      icon: const BackButtonIcon(),
      onPressed: busy ? null : () => requestJobixBack(context),
    );
    if (item == null) {
      return JobixBackHandler(
        onBack: leave,
        child: SliceScaffold(
          title: title,
          leading: back,
          child: failed
              ? Text(copy.profileUnavailable)
              : const FormLoadingState(),
        ),
      );
    }
    return JobixBackHandler(
      onBack: leave,
      child: SliceScaffold(
        title: title,
        singleLineTitle: true,
        actions: widget.origin == EditorOrigin.career
            ? null
            : const [CreditsPill(compact: true)],
        leading: back,
        bottom: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => requestJobixBack(context),
                child: Text(copy.backAction),
              ),
            ),
            const SizedBox(width: TokensV0.space12),
            Expanded(
              child: PrimaryAction(
                key: const Key('editor-save'),
                label: copy.saveAction,
                busy: busy,
                onPressed: conflict == DraftConflict.none ? save : null,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (problems.isNotEmpty) ...[
              Semantics(
                liveRegion: true,
                child: saveIssueCard(
                  item?.hasMeaningfulInput == false
                      ? copy.draftNeedsInformation
                      : copy.incompleteEntry,
                ),
              ),
              const SizedBox(height: TokensV0.space16),
            ],
            if (conflict != DraftConflict.none) ...[
              _ConflictCard(
                text: conflict == DraftConflict.removed
                    ? copy.itemRemovedElsewhere
                    : copy.itemChangedElsewhere,
                keepServer: (copy.keepServerVersion, keepServer),
                keepLocal: (copy.reapplyMyChanges, reapplyLocal),
              ),
              const SizedBox(height: TokensV0.space16),
            ],
            if (issue != null) ...[
              _IssueCard(
                text: saveIssueText(copy, issue!),
                action: switch (issue!) {
                  SaveIssue.pending ||
                  SaveIssue.unknown => (copy.retrySave, retryPending),
                  SaveIssue.conflict => (copy.reloadAction, reload),
                  _ => null,
                },
              ),
              const SizedBox(height: TokensV0.space16),
            ],
            for (final field in widget.section.fields) ...[
              _field(copy, field),
              if (field.name == 'description') ...[
                const SizedBox(height: TokensV0.space8),
                JobixImprovement(original: item!.text('description')),
              ],
              const SizedBox(height: TokensV0.space16),
            ],
            const SizedBox(height: TokensV0.space8),
            SectionWritingGuidance(section: widget.section),
          ],
        ),
      ),
    );
  }

  Widget _field(AppLocalizations copy, SectionField field) {
    final label = fieldLabel(copy, widget.section, field.name);
    final key = Key('field-${field.name}');
    final isEducationSuggestion =
        widget.section == EntitySection.education &&
        (field.name == 'institution' || field.name == 'field_of_study');
    if (isEducationSuggestion) {
      final catalog =
          ref.watch(educationCatalogProvider).valueOrNull ??
          EducationCatalogData.fallback;
      final institutions = field.name == 'institution';
      return EducationAutocompleteField(
        key: ValueKey('education-autocomplete-${field.name}'),
        fieldKey: key,
        controller: controllers[field.name]!,
        label: field.required ? '$label *' : label,
        hint: _fieldHint(
          widget.section,
          field.name,
          copy.localeName.startsWith('ar'),
        )!,
        language: copy.localeName.startsWith('ar') ? 'ar' : 'en',
        suggestions: institutions ? catalog.institutions : catalog.studyFields,
        errorText: _error(copy, field),
        clearLabel: copy.clearField,
        enabled: !busy && !savePending,
        onChanged: (value) => edit(field.name, value),
      );
    }
    if (field.kind == FieldKind.toggle) {
      return SwitchListTile.adaptive(
        key: key,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: item!.flag(field.name),
        onChanged: busy || savePending ? null : (v) => edit(field.name, v),
      );
    }
    if (field.name == 'proficiency') {
      return DropdownButtonFormField<String>(
        key: key,
        value: proficiencies.contains(item!.text('proficiency'))
            ? item!.text('proficiency')
            : null,
        decoration: InputDecoration(
          labelText: label,
          errorText: _error(copy, field),
        ),
        items: [
          for (final p in proficiencies)
            DropdownMenuItem(value: p, child: Text(proficiencyLabel(copy, p))),
        ],
        onChanged: busy || savePending ? null : (v) => edit(field.name, v),
      );
    }
    if (widget.section == EntitySection.education && field.name == 'degree') {
      final selected = degreeOption(item!.text('degree'));
      final ar = copy.localeName.startsWith('ar');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: key,
            value: selected.isEmpty ? null : selected,
            hint: Text(_fieldHint(widget.section, 'degree', ar)!),
            decoration: InputDecoration(
              labelText: '$label *',
              errorText: _error(copy, field),
            ),
            items: [
              for (final option in degreeCodes)
                DropdownMenuItem(
                  value: option,
                  child: Text(degreeChoiceLabel(option, ar ? 'ar' : 'en')),
                ),
            ],
            onChanged: busy || savePending
                ? null
                : (value) {
                    if (value == null) return;
                    if (value == 'degree:other') {
                      edit(
                        'degree',
                        degreeOtherController.text.trim().isEmpty
                            ? ''
                            : 'other:${degreeOtherController.text}',
                      );
                    } else {
                      edit('degree', value);
                    }
                  },
          ),
          if (selected == 'degree:other') ...[
            const SizedBox(height: TokensV0.space8),
            TextField(
              key: const Key('field-degree-other'),
              enabled: !busy && !savePending,
              controller: degreeOtherController,
              inputFormatters: [LengthLimitingTextInputFormatter(194)],
              decoration: InputDecoration(
                labelText: copy.fieldDegreeTitle,
                hintText: copy.fieldDegreeTitleHint,
                errorText:
                    saveAttempted && degreeOtherController.text.trim().isEmpty
                    ? copy.problemRequired
                    : null,
              ),
              onChanged: (value) =>
                  edit('degree', value.trim().isEmpty ? '' : 'other:$value'),
            ),
          ],
        ],
      );
    }
    final disabledEnd =
        field.name == 'end_month' &&
        widget.section.hasCurrent &&
        item!.flag('is_current');
    final controller = controllers[field.name]!;
    final multiline = field.kind == FieldKind.multiline;
    final input = TextField(
      key: key,
      controller: controller,
      enabled: !busy && !savePending && !disabledEnd,
      minLines: multiline ? 4 : 1,
      maxLines: multiline ? 8 : 1,
      keyboardType: switch (field.kind) {
        FieldKind.month => TextInputType.number,
        FieldKind.url => TextInputType.url,
        FieldKind.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      inputFormatters: field.kind == FieldKind.month
          ? [const MonthInputFormatter()]
          : null,
      textDirection:
          field.kind == FieldKind.month || field.kind == FieldKind.url
          ? TextDirection.ltr
          : null,
      decoration: InputDecoration(
        labelText: field.name == 'description'
            ? null
            : field.required || (field.name == 'end_month' && !disabledEnd)
            ? '$label *'
            : label,
        hintText: field.kind == FieldKind.month
            ? copy.monthHint
            : field.name == 'description'
            ? _descriptionHint(widget.section, copy.localeName.startsWith('ar'))
            : _fieldHint(
                widget.section,
                field.name,
                copy.localeName.startsWith('ar'),
              ),
        errorText: _error(copy, field),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: copy.localeName.startsWith('ar')
                    ? 'مسح الحقل'
                    : 'Clear field',
                icon: const Icon(Icons.clear, size: 18),
                onPressed: busy || savePending || disabledEnd
                    ? null
                    : () {
                        controller.clear();
                        edit(
                          field.name,
                          field.kind == FieldKind.list ? <String>[] : '',
                        );
                      },
              ),
      ),
      onChanged: (value) => edit(
        field.name,
        field.kind == FieldKind.list
            ? value.split(',').map((v) => v.trim()).toList()
            : value,
      ),
    );
    if (field.name == 'description') {
      return Semantics(label: label, child: input);
    }
    if (!multiline) return input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        input,
        const SizedBox(height: TokensV0.space12),
      ],
    );
  }

  String? _descriptionHint(
    EntitySection section,
    bool arabic,
  ) => switch (section) {
    EntitySection.experience =>
      arabic
          ? 'اكتب عن مسؤولياتك وإسهاماتك والإنجازات ذات الصلة.'
          : 'Write about your responsibilities, contributions, and relevant achievements…',
    EntitySection.education =>
      arabic
          ? 'اكتب عن المقررات أو المشاريع أو الإنجازات الأكاديمية ذات الصلة…'
          : 'Write about relevant coursework, projects, or academic achievements…',
    EntitySection.achievement =>
      arabic
          ? 'اكتب عن الإنجاز وأهميته، واذكر نتيجة موثقة إن وجدت.'
          : 'Write about the achievement and why it mattered; include a verified result if relevant.',
    EntitySection.certification =>
      arabic
          ? 'أضف المهارات أو المعرفة التي أثبتتها هذه الشهادة.'
          : 'Describe the skills or knowledge demonstrated by this certification.',
    EntitySection.volunteer =>
      arabic
          ? 'صِف القضية التي دعمتها ودورك وكيف أسهمت.'
          : 'Describe the cause you supported, your role, and how you contributed.',
    EntitySection.project =>
      arabic
          ? 'صِف هدف المشروع ومساهمتك والنتيجة التي حققها.'
          : "Describe the project's purpose, your contribution, and its outcome.",
    _ => null,
  };

  String? _fieldHint(EntitySection section, String field, bool arabic) {
    if (field == 'role' && section == EntitySection.project) {
      return arabic ? 'مثال: منسق المشروع' : 'e.g., Project Coordinator';
    }
    if (field == 'name') {
      return switch (section) {
        EntitySection.certification =>
          arabic
              ? 'اسم الشهادة كما يظهر في وثيقتها'
              : 'Name shown on your certificate',
        EntitySection.project =>
          arabic ? 'مثال: مشروع مجتمعي' : 'e.g., Community project',
        EntitySection.skill => arabic ? 'مثال: التواصل' : 'e.g., Communication',
        EntitySection.language => arabic ? 'مثال: العربية' : 'e.g., Arabic',
        _ => null,
      };
    }
    const en = {
      'job_title': 'e.g., Marketing Specialist',
      'company': 'e.g., Jobix Company',
      'location': 'e.g., Alexandria, Egypt',
      'degree': 'e.g., Bachelor of Commerce',
      'institution': 'e.g., Alexandria University',
      'field_of_study': 'e.g., Business Administration',
      'organization': 'e.g., a community organization',
      'role': 'e.g., Volunteer Coordinator',
      'name': 'Enter the name shown on your Resume',
      'issuer': 'Enter the issuing organization',
      'title': 'Use a concise title for the achievement',
      'project_month': 'Choose the month the project took place',
      'proficiency': 'Choose the level that best describes your language',
      'url': 'e.g., https://example.com',
      'credential_id': 'Enter your credential ID, if available',
      'technologies': 'List tools you actually used',
    };
    const ar = {
      'job_title': 'مثال: أخصائي تسويق',
      'company': 'مثال: Jobix Company',
      'location': 'مثال: الإسكندرية، مصر',
      'degree': 'مثال: بكالوريوس التجارة',
      'institution': 'مثال: جامعة الإسكندرية',
      'field_of_study': 'مثال: إدارة الأعمال',
      'organization': 'مثال: مؤسسة مجتمعية',
      'role': 'مثال: منسق متطوعين',
      'name': 'اكتب الاسم الذي سيظهر في سيرتك الذاتية',
      'issuer': 'اكتب اسم الجهة المانحة',
      'title': 'اكتب عنوانًا موجزًا للإنجاز',
      'project_month': 'اختر شهر تنفيذ المشروع',
      'proficiency': 'اختر المستوى الذي يصف لغتك بدقة',
      'url': 'مثال: https://example.com',
      'credential_id': 'اكتب رقم الاعتماد إن توفر',
      'technologies': 'اذكر الأدوات التي استخدمتها بالفعل',
    };
    if (field == 'end_month') return null;
    return (arabic ? ar : en)[field];
  }

  String? _error(AppLocalizations copy, SectionField field) {
    if (widget.section == EntitySection.education &&
        field.name == 'degree' &&
        item!.text('degree').startsWith('other:') &&
        item!.text('degree').substring(6).trim().isEmpty) {
      return copy.problemRequired;
    }
    final problem = problems[field.name];
    return problem == null ? null : problemText(copy, problem);
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.text, this.action});
  final String text;
  final (String, VoidCallback)? action;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('save-issue'),
    padding: const EdgeInsets.all(TokensV0.space12),
    decoration: BoxDecoration(
      color: TokensV0.errorContainer,
      borderRadius: BorderRadius.circular(TokensV0.cardRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(color: TokensV0.onErrorContainer)),
        if (action != null)
          TextButton(onPressed: action!.$2, child: Text(action!.$1)),
      ],
    ),
  );
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.text,
    required this.keepServer,
    required this.keepLocal,
  });
  final String text;
  final (String, VoidCallback) keepServer, keepLocal;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('draft-conflict'),
    padding: const EdgeInsets.all(TokensV0.space12),
    decoration: BoxDecoration(
      color: TokensV0.errorContainer,
      borderRadius: BorderRadius.circular(TokensV0.cardRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(color: TokensV0.onErrorContainer)),
        const SizedBox(height: TokensV0.space8),
        Wrap(
          spacing: TokensV0.space8,
          runSpacing: TokensV0.space8,
          children: [
            TextButton(
              key: const Key('conflict-keep-server'),
              onPressed: keepServer.$2,
              child: Text(keepServer.$1),
            ),
            TextButton(
              key: const Key('conflict-keep-local'),
              onPressed: keepLocal.$2,
              child: Text(keepLocal.$1),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Public so step pages can show the same issue card.
Widget saveIssueCard(String text, [(String, VoidCallback)? action]) =>
    _IssueCard(text: text, action: action);
