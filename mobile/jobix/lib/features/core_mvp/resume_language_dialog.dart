import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/jobix_feedback.dart';
import '../../core/design/jobix_dialog.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../career_profile/career_profile.dart';
import '../auth/auth_controller.dart';
import '../resume/resume_language_repository.dart';

Future<void> showCareerResumeLanguageDialog(
  BuildContext context,
  WidgetRef ref,
  CareerProfile profile,
) async {
  final copy = AppLocalizations.of(context)!;
  final appLanguage = Localizations.localeOf(context).languageCode == 'ar'
      ? 'ar'
      : 'en';
  try {
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser?.id;
    if (user == null) throw StateError('AUTH_REQUIRED');
    final database = await ref.read(databaseProvider.future);
    final repository = ResumeLanguageRepository(
      database: database,
      user: user,
      profileId: profile.id,
      isCurrentUser: () => client.auth.currentUser?.id == user,
      readRemote: (profileId) async {
        final value = await client
            .rpc(
              'read_resume_configuration',
              params: {'requested_profile': profileId},
            )
            .timeout(const Duration(seconds: 15));
        return value == null ? null : Map<String, dynamic>.from(value as Map);
      },
      saveRemote: (request) async {
        final value = await client
            .rpc('save_resume_configuration', params: request)
            .timeout(const Duration(seconds: 15));
        return Map<String, dynamic>.from(value as Map);
      },
    );
    final initial = await repository.load(
      profileLanguage: profile.resumeLanguage,
      appLanguage: appLanguage,
    );
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _ResumeLanguageDialog(repository: repository, initial: initial),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(firstProfileProvider);
      ref.invalidate(savedResumeLanguageProvider(profile.id));
      showJobixFeedback(context, copy.resumeLanguageChanged);
    }
  } on PostgrestException catch (error) {
    if (context.mounted) {
      showJobixFeedback(
        context,
        error.message.contains('VERSION_CONFLICT')
            ? copy.saveFailed
            : copy.resumeLanguageSaveFailed,
        kind: JobixFeedbackKind.error,
      );
    }
  } catch (_) {
    if (context.mounted) {
      showJobixFeedback(
        context,
        copy.resumeLanguageSaveFailed,
        kind: JobixFeedbackKind.error,
      );
    }
  }
}

class _ResumeLanguageDialog extends StatefulWidget {
  const _ResumeLanguageDialog({
    required this.repository,
    required this.initial,
  });

  final ResumeLanguageRepository repository;
  final ResumeLanguageState initial;

  @override
  State<_ResumeLanguageDialog> createState() => _ResumeLanguageDialogState();
}

class _ResumeLanguageDialogState extends State<_ResumeLanguageDialog> {
  late String selected = widget.initial.language;
  late String savedLanguage = widget.initial.language;
  late int version = widget.initial.version;
  late bool pendingRequest = widget.initial.pending;
  bool saving = false;
  String? error;

  Future<void> save() async {
    if (saving) return;
    if (!pendingRequest && selected == savedLanguage) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      saving = true;
      pendingRequest = true;
      error = null;
    });
    try {
      await widget.repository.save(selected, version);
      if (mounted) Navigator.pop(context, true);
    } on ResumeLanguageConflict catch (conflict) {
      if (mounted) {
        setState(() {
          selected = savedLanguage = conflict.latest.language;
          version = conflict.latest.version;
          pendingRequest = false;
          error = AppLocalizations.of(context)!.conflictBody;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = AppLocalizations.of(context)!.saveFailed);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    return JobixAlertDialog(
      icon: const Icon(Icons.translate, color: TokensV0.primary),
      title: Text(copy.changeResumeLanguage),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(copy.resumeLanguageHint),
          const SizedBox(height: TokensV0.space16),
          for (final option in const [
            ('en', 'English (LTR)'),
            ('ar', 'العربية (RTL)'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: TokensV0.space8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected == option.$1
                      ? TokensV0.secondarySurface
                      : TokensV0.surfaceCard,
                  borderRadius: BorderRadius.circular(TokensV0.controlRadius),
                  border: Border.all(
                    color: selected == option.$1
                        ? TokensV0.primary
                        : TokensV0.border,
                  ),
                ),
                child: RadioListTile<String>(
                  key: Key('career-resume-language-${option.$1}'),
                  value: option.$1,
                  groupValue: selected,
                  onChanged: saving || pendingRequest
                      ? null
                      : (value) => setState(() => selected = value!),
                  title: Text(
                    option.$2,
                    textDirection: option.$1 == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: TokensV0.languageChoiceLabel(
                      languageCode: option.$1,
                      selected: selected == option.$1,
                    ),
                  ),
                ),
              ),
            ),
          if (error != null) Semantics(liveRegion: true, child: Text(error!)),
        ],
      ),
      actions: [
        if (!pendingRequest)
          JobixDialogAction.secondary(
            onPressed: saving ? null : () => Navigator.pop(context, false),
            child: Text(copy.cancelAction),
          ),
        JobixDialogAction.primary(
          key: const Key('career-resume-language-done'),
          onPressed: saving ? null : save,
          child: Text(copy.doneAction),
        ),
      ],
    );
  }
}
