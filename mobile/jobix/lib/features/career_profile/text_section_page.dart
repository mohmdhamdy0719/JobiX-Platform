import 'dart:async';
import '../../core/navigation/back_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/jobix_dialog.dart';
import '../../core/design/tokens.dart';
import '../../core/design/jobix_feedback.dart';
import '../../core/design/form_loading_state.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../builder/builder_scaffold.dart';
import '../builder/jobix_improvement.dart';
import '../builder/profile_overview.dart';
import '../home/home_page.dart';
import 'career_profile.dart';
import 'text_section_repository.dart';
import 'summary_writing_hints.dart';

String textSectionTitle(BuildContext context, String section) {
  final ar = AppLocalizations.of(context)!.localeName.startsWith('ar');
  return section == 'summary'
      ? (ar ? 'الملخص المهني' : 'Professional Summary')
      : (ar ? 'الدور المستهدف' : 'Target Role');
}

class TextSectionPage extends ConsumerStatefulWidget {
  const TextSectionPage({
    required this.section,
    this.builderStep,
    this.origin,
    super.key,
  });
  final String section;
  // Non-null when shown as a guided builder step.
  final int? builderStep;
  // 'review' returns to Review after Back or a successful save.
  final String? origin;
  @override
  ConsumerState<TextSectionPage> createState() => _TextSectionPageState();
}

class _TextSectionPageState extends ConsumerState<TextSectionPage> {
  final controller = TextEditingController();
  TextSectionRepository? repository;
  CareerProfile? profile;
  TextSectionDraft? draft;
  bool busy = false, failed = false, dirty = false, allowPop = false;
  String? notice;
  bool get ar => AppLocalizations.of(context)!.localeName.startsWith('ar');
  String say(String en, String arabic) => ar ? arabic : en;
  int get maximum => widget.section == 'summary' ? 1000 : 200;
  bool get fromReview => widget.origin == 'review';
  bool get fromPersonal => widget.origin == 'personal';
  bool get hasPendingSave => draft?.request != null;
  String get backRoute => fromReview
      ? '/builder/6'
      : fromPersonal
      ? '/career/personal'
      : widget.builderStep != null
      ? '/builder/${widget.builderStep! - 1}'
      : '/career';

  Future<void> advance() async {
    if (busy || draft == null) return;
    if (dirty) await save();
    if (!mounted || dirty) return;
    allowPop = true;
    context.go(
      fromPersonal
          ? '/career/personal'
          : !fromReview && widget.builderStep != null
          ? '/builder/${widget.builderStep! + 1}'
          : '/builder/6',
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final repo = await ref.read(textSectionRepositoryProvider.future);
      // Fresh acknowledged content if online; an encrypted acknowledged cache only
      // for real connectivity failures, matching the existing Profile repository.
      final value = await repo.parent.load(freshOnly: true);
      await repo.parent.draft(value);
      final local = await repo.load(value, widget.section);
      if (!mounted) return;
      repository = repo;
      profile = value;
      draft =
          local ??
          TextSectionDraft(
            profileId: value.id,
            section: widget.section,
            version: value.version,
            text: widget.section == 'summary'
                ? value.summary
                : value.targetRole,
          );
      controller.text = draft!.text;
      setState(() {
        failed = false;
        dirty = local != null;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  void edit(String value) {
    if (hasPendingSave) return;
    final next = draft!.edit(value);
    setState(() {
      draft = next;
      dirty = true;
      notice = null;
    });
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      if (draft!.text.trim().runes.length > maximum) {
        setState(
          () => notice = say(
            'The hard limit is $maximum characters. Nothing was saved.',
            'الحد الأقصى $maximum حرفًا. لم يتم حفظ أي تغيير.',
          ),
        );
        return;
      }
      final result = await repository!.save(draft!);
      final retained = await repository!.load(result, widget.section);
      if (!mounted) return;
      profile = result;
      draft =
          retained ??
          TextSectionDraft(
            profileId: result.id,
            section: widget.section,
            version: result.version,
            text: widget.section == 'summary'
                ? result.summary
                : result.targetRole,
          );
      controller.text = draft!.text;
      dirty = retained != null;
      ref.invalidate(firstProfileProvider);
      ref.invalidate(unfinishedDraftProvider(result.id));
      setState(
        () => notice = retained == null
            ? null
            : AppLocalizations.of(context)!.savedDevice,
      );
      if (retained == null) {
        showJobixFeedback(context, say('Changes saved.', 'تم حفظ التغييرات.'));
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.message == 'VERSION_CONFLICT') {
        try {
          await conflict();
        } catch (_) {
          if (mounted) {
            setState(() => notice = AppLocalizations.of(context)!.saveFailed);
          }
        }
      } else {
        final unresolved = await repository!.load(profile!, widget.section);
        if (!mounted) return;
        if (unresolved?.request != null) {
          draft = unresolved;
          controller.text = unresolved!.text;
          dirty = true;
        }
        setState(
          () => notice = hasPendingSave
              ? AppLocalizations.of(context)!.outcomeUnknown
              : AppLocalizations.of(context)!.saveFailed,
        );
      }
    } catch (_) {
      if (mounted) {
        final unresolved = await repository!.load(profile!, widget.section);
        if (!mounted) return;
        if (unresolved?.request != null) {
          draft = unresolved;
          controller.text = unresolved!.text;
          dirty = true;
        }
        setState(
          () => notice = hasPendingSave
              ? AppLocalizations.of(context)!.outcomeUnknown
              : AppLocalizations.of(context)!.saveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> conflict() async {
    final copy = AppLocalizations.of(context)!;
    final latest = await repository!.parent.load(freshOnly: true);
    if (!mounted) return;
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => JobixAlertDialog(
        title: Text(copy.conflictTitle),
        content: Text(copy.conflictBody),
        actions: [
          JobixDialogAction.secondary(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.keepServer),
          ),
          JobixDialogAction.primary(
            onPressed: () => Navigator.pop(context, true),
            child: Text(copy.reapplyLocal),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    profile = latest;
    draft = TextSectionDraft(
      profileId: latest.id,
      section: widget.section,
      version: latest.version,
      text: choice
          ? controller.text
          : widget.section == 'summary'
          ? latest.summary
          : latest.targetRole,
    );
    if (choice) {
      // Reapply is held only in this editor until the next explicit Save.
    } else {
      await repository!.parent.database.discardSection(
        repository!.parent.user,
        latest.id,
        widget.section,
      );
    }
    if (!mounted) return;
    setState(() {
      controller.text = draft!.text;
      dirty = choice;
      notice = choice
          ? (copy.localeName.startsWith('ar')
                ? 'تغييراتك غير محفوظة. اختر حفظ لتطبيقها.'
                : 'Your changes are not saved. Choose Save to apply them.')
          : copy.savedServer;
    });
  }

  Future<void> leave() async {
    if (busy) return;
    final copy = AppLocalizations.of(context)!;
    if (hasPendingSave) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => JobixAlertDialog(
          title: Text(copy.outcomeUnknown),
          content: Text(
            say(
              'The original save must be confirmed before discarding these changes. Retry the same request or stay here.',
              'يجب تأكيد الحفظ الأصلي قبل تجاهل هذه التغييرات. أعد الطلب نفسه أو ابق هنا.',
            ),
          ),
          actions: [
            JobixDialogAction.secondary(
              onPressed: () => Navigator.pop(context, false),
              child: Text(copy.stayAction),
            ),
            JobixDialogAction.primary(
              onPressed: () => Navigator.pop(context, true),
              child: Text(say('Retry Save', 'إعادة الحفظ')),
            ),
          ],
        ),
      );
      if (retry == true && mounted) await save();
      return;
    }
    if (dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => JobixAlertDialog(
          title: Text(copy.leaveTitle),
          content: Text(copy.discardWarning),
          actions: [
            JobixDialogAction.secondary(
              onPressed: () => Navigator.pop(context, 'stay'),
              child: Text(copy.stayAction),
            ),
            JobixDialogAction.destructive(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: Text(copy.discardAction),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'stay' || !mounted) return;
      setState(() => busy = true);
      try {
        await repository!.discard(profile!, widget.section);
      } catch (_) {
        if (mounted) setState(() => notice = copy.outcomeUnknown);
        return;
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    if (mounted) {
      if (profile != null) ref.invalidate(unfinishedDraftProvider(profile!.id));
      setState(() => allowPop = true);
      context.go(backRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final count = controller.text.trim().runes.length;
    return JobixBackHandler(
      onBack: leave,
      child: frame(
        copy,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (draft == null) ...[
              if (failed)
                Text(copy.profileUnavailable)
              else
                const FormLoadingState(),
              if (failed) TextButton(onPressed: load, child: Text(copy.retry)),
            ] else ...[
              SectionHeading(title: textSectionTitle(context, widget.section)),
              if (hasPendingSave) ...[
                const SizedBox(height: TokensV0.space12),
                SliceCard(
                  child: Text(
                    say(
                      'This save is not confirmed. The original request is preserved; retry Save to reconcile it. Editing is locked until then.',
                      'لم يتم تأكيد هذا الحفظ. الطلب الأصلي محفوظ؛ أعد الحفظ لتسويته. التعديل متوقف حتى ذلك الحين.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: TokensV0.space20),
              SliceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: Key('editor-${widget.section}'),
                      controller: controller,
                      readOnly: busy || hasPendingSave,
                      onChanged: edit,
                      minLines: widget.section == 'summary' ? 6 : 1,
                      maxLines: widget.section == 'summary' ? 12 : 3,
                      decoration: InputDecoration(
                        hintText: widget.section == 'summary'
                            ? say(
                                'Tell us about your experience, strengths, and career direction.',
                                'حدثنا عن خبرتك ونقاط قوتك وتوجهك المهني.',
                              )
                            : say(
                                'e.g. Senior Frontend Developer',
                                'مثال: مطوّر واجهات أمامية أول',
                              ),
                        suffixIcon: controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: say('Clear field', 'مسح الحقل'),
                                icon: const Icon(Icons.clear),
                                onPressed: busy
                                    ? null
                                    : () {
                                        controller.clear();
                                        edit('');
                                      },
                              ),
                        errorText: count > maximum
                            ? say('Hard limit exceeded', 'تم تجاوز الحد الأقصى')
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TokensV0.space12),
              const SizedBox(height: TokensV0.space20),
              if (widget.section == 'summary') ...[
                JobixImprovement(original: controller.text),
                const SizedBox(height: TokensV0.space12),
                const SummaryWritingHints(),
              ],
              if (notice != null)
                Text(notice!, key: const Key('section-notice')),
            ],
          ],
        ),
      ),
    );
  }

  Widget frame(AppLocalizations copy, Widget child) {
    if (widget.builderStep != null && !fromReview) {
      return BuilderScaffold(
        step: widget.builderStep!,
        busy: busy,
        onBack: leave,
        onContinue: draft == null ? null : advance,
        child: child,
      );
    }
    return SliceScaffold(
      title: textSectionTitle(context, widget.section),
      singleLineTitle: true,
      actions: widget.builderStep != null || fromReview
          ? const [CreditsPill(compact: true)]
          : null,
      leading: IconButton(
        onPressed: busy ? null : () => requestJobixBack(context),
        icon: const Icon(Icons.arrow_back),
        tooltip: copy.backAction,
      ),
      bottom: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : () => requestJobixBack(context),
              child: Text(fromReview ? copy.backToReview : copy.backAction),
            ),
          ),
          const SizedBox(width: TokensV0.space12),
          Expanded(
            child: PrimaryAction(
              key: Key('save-${widget.section}'),
              label: hasPendingSave
                  ? (copy.localeName.startsWith('ar')
                        ? 'إعادة الحفظ'
                        : 'Retry Save')
                  : copy.saveAction,
              busy: busy,
              onPressed: fromReview ? advance : save,
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}
