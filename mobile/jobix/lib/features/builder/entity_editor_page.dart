import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/entity_repository.dart';
import '../career_profile/profile_sections.dart';
import 'builder_scaffold.dart';
import 'entity_labels.dart';
import 'save_feedback.dart';

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
  CareerProfile? profile;
  ProfileItem? item;
  Map<String, FieldProblem> problems = {};
  bool busy = false, failed = false;
  SaveIssue? issue;

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
    super.dispose();
  }

  Future<void> load() async {
    try {
      final value = await ref.read(firstProfileProvider.future);
      final repository = await ref.read(entityRepositoryProvider.future);
      final id = widget.itemId == 'new' ? newCommandKey() : widget.itemId;
      final saved = value
          .of(widget.section)
          .where((i) => i.id == id)
          .firstOrNull;
      final local = await repository.draft(value.id, widget.section, id);
      final current =
          local ?? saved ?? ProfileItem(id: id, section: widget.section);
      _fill(current);
      if (!mounted) return;
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
    final next = item!.copyWith(field, value);
    setState(() {
      item = next;
      problems = {};
      issue = null;
    });
    final repository = await ref.read(entityRepositoryProvider.future);
    await repository.retainDraft(profile!.id, next);
  }

  void close() => context.go(editorReturn(widget.section, widget.origin));

  void _fill(ProfileItem source) {
    for (final field in widget.section.fields) {
      if (field.kind == FieldKind.toggle) continue;
      final text = field.kind == FieldKind.list
          ? source.list(field.name).join(', ')
          : source.text(field.name);
      (controllers[field.name] ??= TextEditingController()).text = text;
    }
  }

  /// Discards local edits in favour of the server copy (or leaves when the
  /// item was removed elsewhere).
  Future<void> keepServer() async {
    final repository = await ref.read(entityRepositoryProvider.future);
    await repository.discardDraft(profile!.id, widget.section, item!.id);
    final server = serverItem;
    if (server == null) {
      if (mounted) close();
      return;
    }
    _fill(server);
    if (mounted) {
      setState(() {
        item = server;
        conflict = DraftConflict.none;
        problems = {};
      });
    }
  }

  /// Keeps local edits on top of the latest server baseline, by choice.
  Future<void> reapplyLocal() async {
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
    if (conflict != DraftConflict.none) return;
    final copy = item!;
    final found = copy.problems();
    if (found.isNotEmpty) {
      setState(() => problems = found);
      return;
    }
    setState(() => busy = true);
    try {
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
      onPressed: busy ? null : close,
    );
    if (item == null) {
      return SliceScaffold(
        title: title,
        leading: back,
        child: failed
            ? Text(copy.profileUnavailable)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) close();
      },
      child: SliceScaffold(
        title: title,
        leading: back,
        bottom: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : close,
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
              const SizedBox(height: TokensV0.space16),
            ],
            if (!item!.locallyComplete)
              Text(
                copy.incompleteSaveNote,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TokensV0.textSecondary),
              ),
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
    final disabledEnd =
        field.name == 'end_month' &&
        widget.section.hasCurrent &&
        item!.flag('is_current');
    final controller = controllers[field.name]!;
    final multiline = field.kind == FieldKind.multiline;
    return TextField(
      key: key,
      controller: controller,
      enabled: !busy && !disabledEnd,
      minLines: multiline ? 4 : 1,
      maxLines: multiline ? 8 : 1,
      maxLength: field.kind == FieldKind.list ? null : field.max,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      keyboardType: switch (field.kind) {
        FieldKind.month => TextInputType.datetime,
        FieldKind.url => TextInputType.url,
        FieldKind.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      inputFormatters: field.kind == FieldKind.month
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              LengthLimitingTextInputFormatter(7),
            ]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: field.kind == FieldKind.month ? copy.monthHint : null,
        helperText: multiline && field.minimum > 1
            ? copy.descriptionMinimum
            : null,
        helperMaxLines: 2,
        errorText: _error(copy, field),
      ),
      onChanged: (value) => edit(
        field.name,
        field.kind == FieldKind.list
            ? value.split(',').map((v) => v.trim()).toList()
            : value,
      ),
    );
  }

  String? _error(AppLocalizations copy, SectionField field) {
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
