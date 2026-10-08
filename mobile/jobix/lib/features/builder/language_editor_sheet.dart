import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/profile_sections.dart';
import 'entity_labels.dart';

/// State/controller lifetime belongs to the modal route, not its pop-result
/// future. The latter completes before reverse animation/unmount finishes.
class LanguageEditorSheet extends StatefulWidget {
  const LanguageEditorSheet({this.existing, super.key});
  final ProfileItem? existing;
  @override
  State<LanguageEditorSheet> createState() => _LanguageEditorSheetState();
}

class _LanguageEditorSheetState extends State<LanguageEditorSheet> {
  late final name = TextEditingController(
    text: widget.existing?.text('name') ?? '',
  );
  late String? level = widget.existing?.text('proficiency');
  bool leaving = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (leaving) return;
    leaving = true;
    try {
      final original = widget.existing;
      if (original != null &&
          (name.text != original.text('name') ||
              level != original.text('proficiency'))) {
        final copy = AppLocalizations.of(context)!;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(copy.leaveTitle),
            content: Text(copy.discardWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(copy.stayAction),
              ),
              TextButton(
                key: const Key('discard-language'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(copy.discardAction),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return;
      }
      if (mounted) Navigator.pop(context);
    } finally {
      leaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(leave());
      },
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          TokensV0.pageGutter,
          0,
          TokensV0.pageGutter,
          MediaQuery.viewInsetsOf(context).bottom + TokensV0.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? copy.addLanguage : copy.editAction,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TokensV0.space16),
            TextField(
              key: const Key('language-name'),
              controller: name,
              maxLength: 100,
              decoration: InputDecoration(labelText: copy.fieldLanguage),
            ),
            DropdownButtonFormField<String>(
              key: const Key('language-level'),
              value: level,
              decoration: InputDecoration(labelText: copy.fieldProficiency),
              items: [
                for (final p in proficiencies)
                  DropdownMenuItem(
                    value: p,
                    child: Text(proficiencyLabel(copy, p)),
                  ),
              ],
              onChanged: (v) => setState(() => level = v),
            ),
            const SizedBox(height: TokensV0.space16),
            FilledButton(
              key: const Key('language-save'),
              onPressed: () {
                if (leaving) return;
                final item = ProfileItem(
                  id: widget.existing?.id ?? newCommandKey(),
                  section: EntitySection.language,
                  version: widget.existing?.version ?? 0,
                  values: {'name': name.text, 'proficiency': level},
                );
                if (item.problems().isEmpty) Navigator.pop(context, item);
              },
              child: Text(copy.saveAction),
            ),
            TextButton(
              key: const Key('language-back'),
              onPressed: leave,
              child: Text(copy.backAction),
            ),
          ],
        ),
      ),
    );
  }
}
