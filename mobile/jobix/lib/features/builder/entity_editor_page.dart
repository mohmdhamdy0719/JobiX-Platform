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
import '../../core/navigation/back_policy.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/entity_repository.dart';
import '../career_profile/profile_sections.dart';
import 'builder_scaffold.dart';
import 'entity_labels.dart';
import 'save_feedback.dart';
import 'month_input_formatter.dart';
import 'section_writing_guidance.dart';
import 'jobix_improvement.dart';

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
  Future<void> writes = Future.value();
  bool leaving = false, saveAttempted = false;
  bool get dirty =>
      item != null &&
      (serverItem == null ||
          jsonEncode(item!.payload()) != jsonEncode(serverItem!.payload()));

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
      final value = await ref.read(firstProfileProvider.future);
      if (!mounted) return;
      final repository = await ref.read(entityRepositoryProvider.future);
      final recovered = widget.itemId == 'new'
          ? (await repository.unsavedNew(value, widget.section)).firstOrNull
          : null;
      final id = widget.itemId == 'new'
          ? recovered?.id ?? newCommandKey()
          : widget.itemId;
      final saved = value
          .of(widget.section)
          .where((i) => i.id == id)
          .firstOrNull;
      final local = await repository.draft(value.id, widget.section, id);
      final current =
          local ?? saved ?? ProfileItem(id: id, section: widget.section);
      if (!mounted) return;
      _fill(current);
      setState(() {
        profile = value;
        item = current;
        serverItem = saved;
        conflict = local == null
            ? DraftConflict.none
            : draftConflict(local, saved);
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> edit(String field, Object? value) async {
    if (busy || leaving || item == null) return;
    final next = item!.copyWith(field, value);
    setState(() {
      item = next;
      problems = {};
      issue = null;
      saveAttempted = false;
    });
    final repositoryFuture = ref.read(entityRepositoryProvider.future);
    final profileId = profile!.id;
    writes = writes
        .then((_) async {
          final repository = await repositoryFuture;
          await repository.retainDraft(profileId, next);
        })
        .catchError((Object error) {
          if (mounted) setState(() => issue = saveIssue(error));
        });
    await writes;
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
      final pendingItem = pending?.itemId == item?.id && pending != null;
      if (item != null && (pendingItem || serverItem != null && dirty)) {
        final copy = AppLocalizations.of(context)!;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => JobixAlertDialog(
            title: Text(copy.leaveTitle),
            content: Text(
              pendingItem ? copy.pendingBackWarning : copy.discardWarning,
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
      // Drain every queued local edit before deleting its scoped draft.
      // The frozen pending command is intentionally a separate outbox entry.
      await writes;
      if (!mounted) return;
      if (profile != null && item != null) {
        await repository!.discardDraft(profile!.id, widget.section, item!.id);
      }
      if (mounted) close();
    } catch (error) {
      if (mounted) setState(() => issue = saveIssue(error));
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
      degreeOtherController.text = value.startsWith('other:')
          ? value.substring(6)
          : degreeCodes.contains(value)
          ? ''
          : value;
    }
  }

  /// Discards local edits in favour of the server copy (or leaves when the
  /// item was removed elsewhere).
  Future<void> keepServer() async {
    await writes;
    if (!mounted) return;
    final repository = await ref.read(entityRepositoryProvider.future);
    await repository.discardDraft(profile!.id, widget.section, item!.id);
    final server = serverItem;
    if (server == null) {
      if (mounted) close();
      return;
    }
    if (mounted) {
      _fill(server);
      setState(() {
        item = server;
        conflict = DraftConflict.none;
        problems = {};
      });
    }
  }

  /// Keeps local edits on top of the latest server baseline, by choice.
  Future<void> reapplyLocal() async {
    await writes;
    if (!mounted) return;
    final next = item!.rebased(serverItem?.version ?? 0);
    final repository = await ref.read(entityRepositoryProvider.future);
    await repository.retainDraft(profile!.id, next);
    if (mounted) {
      setState(() {
        item = next;
        conflict = DraftConflict.none;
      });
    }
  }

  Future<void> save() async {
    if (busy || leaving || item == null || conflict != DraftConflict.none) {
      return;
    }
    final copy = item!;
    setState(() => saveAttempted = true);
    final found = copy.problems();
    if (found.isNotEmpty) {
      setState(() => problems = found);
      return;
    }
    setState(() => busy = true);
    try {
      await writes;
      if (!mounted) return;
      final repository = await ref.read(entityRepositoryProvider.future);
      await repository.retainDraft(profile!.id, copy);
      await repository.upsert(profile!, copy);
      ref.invalidate(firstProfileProvider);
      if (mounted) close();
    } catch (error) {
      if (mounted) setState(() => issue = saveIssue(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> retryPending() async {
    setState(() => busy = true);
    try {
      final repository = await ref.read(entityRepositoryProvider.future);
      final result = await repository.resume(profile!.id);
      ref.invalidate(firstProfileProvider);
      if (result != null) profile = result;
      if (mounted) setState(() => issue = null);
    } catch (error) {
      if (mounted) setState(() => issue = saveIssue(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reload() async {
    ref.invalidate(firstProfileProvider);
    final value = await ref.read(firstProfileProvider.future);
    final server = value
        .of(widget.section)
        .where((i) => i.id == item!.id)
        .firstOrNull;
    if (mounted) {
      setState(() {
        profile = value;
        serverItem = server;
        // Unchanged item: retrying on the new profile version is safe.
        // Changed or removed item: the user must choose explicitly.
        conflict = draftConflict(item!, server);
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
                  copy.localeName.startsWith('ar')
                      ? 'لا يمكن إضافة هذا العنصر بعد. راجع الحقول المحددة؛ تم الاحتفاظ بمسودتك.'
                      : "This item can't be added yet. Check the highlighted fields; your draft is retained.",
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
            SectionWritingGuidance(section: widget.section),
            const SizedBox(height: TokensV0.space16),
            for (final field in widget.section.fields) ...[
              _field(copy, field),
              if (field.name == 'description') ...[
                const SizedBox(height: TokensV0.space8),
                JobixImprovement(original: item!.text('description')),
              ],
              const SizedBox(height: TokensV0.space16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(AppLocalizations copy, SectionField field) {
    final label = fieldLabel(copy, widget.section, field.name);
    final key = Key('field-${field.name}');
    if (field.kind == FieldKind.toggle) {
      return SwitchListTile.adaptive(
        key: key,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: item!.flag(field.name),
        onChanged: busy ? null : (v) => edit(field.name, v),
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
        onChanged: busy ? null : (v) => edit(field.name, v),
      );
    }
    if (widget.section == EntitySection.education && field.name == 'degree') {
      final selected = degreeOption(item!.text('degree'));
      final ar = copy.localeName.startsWith('ar');
      const labelsEn = {
        'degree:high_school': 'High school',
        'degree:associate': 'Associate degree',
        'degree:bachelor': "Bachelor's degree",
        'degree:master': "Master's degree",
        'degree:doctorate': 'Doctorate',
        'degree:diploma': 'Diploma',
        'degree:certificate': 'Certificate',
        'degree:other': 'Other',
      };
      const labelsAr = {
        'degree:high_school': 'الثانوية العامة',
        'degree:associate': 'درجة جامعية متوسطة',
        'degree:bachelor': 'درجة البكالوريوس',
        'degree:master': 'درجة الماجستير',
        'degree:doctorate': 'درجة الدكتوراه',
        'degree:diploma': 'دبلوم',
        'degree:certificate': 'شهادة',
        'degree:other': 'أخرى',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: key,
            value: selected.isEmpty ? null : selected,
            decoration: InputDecoration(
              labelText: '$label *',
              errorText: _error(copy, field),
            ),
            items: [
              for (final option in degreeCodes)
                DropdownMenuItem(
                  value: option,
                  child: Text((ar ? labelsAr : labelsEn)[option]!),
                ),
            ],
            onChanged: busy
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
                      degreeOtherController.clear();
                      edit('degree', value);
                    }
                  },
          ),
          if (selected == 'degree:other') ...[
            const SizedBox(height: TokensV0.space8),
            TextField(
              key: const Key('field-degree-other'),
              enabled: !busy,
              controller: degreeOtherController,
              inputFormatters: [LengthLimitingTextInputFormatter(194)],
              decoration: InputDecoration(
                labelText: ar ? 'اكتب المؤهل' : 'Enter qualification',
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
      enabled: !busy && !disabledEnd,
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
        labelText: field.required || (field.name == 'end_month' && !disabledEnd)
            ? '$label *'
            : label,
        hintText: field.kind == FieldKind.month
            ? copy.monthHint
            : field.name == 'description'
            ? _descriptionHint(widget.section, copy.localeName.startsWith('ar'))
            : null,
        errorText: _error(copy, field),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: copy.localeName.startsWith('ar')
                    ? 'مسح الحقل'
                    : 'Clear field',
                icon: const Icon(Icons.clear, size: 18),
                onPressed: busy || disabledEnd
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
          ? 'صِف مسؤولياتك وإسهاماتك الرئيسية والنتائج القابلة للقياس.'
          : 'Describe your responsibilities, key contributions, and measurable results.',
    EntitySection.education =>
      arabic
          ? 'أضف المقررات أو المشاريع أو التكريمات أو الإنجازات الأكاديمية ذات الصلة.'
          : 'Add relevant coursework, projects, honors, or academic achievements.',
    EntitySection.achievement =>
      arabic
          ? 'صِف ما حققته، ولماذا كان مهمًا، وأي نتيجة قابلة للقياس.'
          : 'Describe what you achieved, why it mattered, and any measurable result.',
    EntitySection.volunteer =>
      arabic
          ? 'صِف القضية التي دعمتها ودورك وكيف أسهمت.'
          : 'Describe the cause you supported, your role, and how you contributed.',
    EntitySection.project =>
      arabic
          ? 'صِف ما أنشأته، والأدوات التي استخدمتها، والنتيجة.'
          : 'Describe what you built, the tools you used, and the result.',
    _ => null,
  };

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
