import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../builder/builder_scaffold.dart';
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
  Future<void> writes = Future.value();
  bool busy = false, failed = false, dirty = false, allowPop = false;
  String? notice;
  bool get ar => AppLocalizations.of(context)!.localeName.startsWith('ar');
  String say(String en, String arabic) => ar ? arabic : en;
  int get maximum => widget.section == 'summary' ? 1000 : 200;
  bool get fromReview => widget.origin == 'review';
  String get backRoute => widget.builderStep != null
      ? '/builder/${widget.builderStep! - 1}'
      : fromReview
      ? '/builder/6'
      : '/career';

  Future<void> advance() async {
    if (busy || draft == null) return;
    if (dirty) await save();
    if (!mounted || dirty) return;
    allowPop = true;
    context.go(
      widget.builderStep != null
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
      final value = await repo.parent.load();
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
    final next = draft!.edit(value);
    setState(() {
      draft = next;
      dirty = true;
      notice = null;
    });
    writes = writes.then((_) => repository!.retain(next)).catchError((
      Object _,
    ) {
      if (mounted) {
        setState(() => notice = AppLocalizations.of(context)!.localWriteError);
      }
    });
  }

  Future<bool> persist() async {
    try {
      await writes;
      await repository!.retain(draft!);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => notice = AppLocalizations.of(context)!.localWriteError);
      }
      return false;
    }
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      if (!await persist()) return;
      if (draft!.text.trim().runes.length > maximum) {
        setState(
          () => notice = say(
            'The hard limit is $maximum characters. Your local draft is retained.',
            'الحد الأقصى $maximum حرفًا. تم الاحتفاظ بالمسودة على جهازك.',
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
            ? AppLocalizations.of(context)!.savedServer
            : AppLocalizations.of(context)!.savedDevice,
      );
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
        setState(() => notice = AppLocalizations.of(context)!.saveFailed);
      }
    } catch (_) {
      if (mounted) {
        setState(() => notice = AppLocalizations.of(context)!.saveFailed);
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
      builder: (context) => AlertDialog(
        title: Text(copy.conflictTitle),
        content: Text(copy.conflictBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.keepServer),
          ),
          TextButton(
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
      await repository!.retain(draft!);
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
      notice = choice ? copy.savedDevice : copy.savedServer;
    });
  }

  Future<void> leave() async {
    if (busy) return;
    final copy = AppLocalizations.of(context)!;
    if (dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(copy.leaveTitle),
          content: Text(copy.discardWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'stay'),
              child: Text(copy.stayAction),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: Text(copy.discardAction),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'retain'),
              child: Text(copy.saveLater),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'stay' || !mounted) return;
      try {
        await writes;
        if (choice == 'retain') {
          if (!await persist()) return;
        } else {
          await repository!.discard(profile!, widget.section);
        }
      } catch (_) {
        if (mounted) setState(() => notice = copy.outcomeUnknown);
        return;
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
    final minimum = widget.section == 'summary' ? 50 : 2;
    final state = widget.section == 'summary'
        ? profile?.summaryState
        : profile?.targetRoleState;
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(leave());
      },
      child: frame(
        copy,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (draft == null) ...[
              Text(
                failed
                    ? copy.profileUnavailable
                    : say('Loading…', 'جار التحميل…'),
              ),
              if (failed) TextButton(onPressed: load, child: Text(copy.retry)),
            ] else ...[
              SectionHeading(
                title: textSectionTitle(context, widget.section),
                subtitle: say(
                  'Optional. Write in your own words; incomplete content can be saved.',
                  'اختياري. اكتب بأسلوبك؛ يمكنك حفظ المحتوى غير المكتمل.',
                ),
              ),
              const SizedBox(height: TokensV0.space20),
              SliceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: Key('editor-${widget.section}'),
                      controller: controller,
                      readOnly: busy,
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
                        counterText: '$count / $maximum',
                        errorText: count > maximum
                            ? say('Hard limit exceeded', 'تم تجاوز الحد الأقصى')
                            : null,
                      ),
                    ),
                    const SizedBox(height: TokensV0.space12),
                    Text(
                      count == 0
                          ? say('Not used', 'غير مستخدم')
                          : count < minimum ||
                                (!dirty && state == 'NEEDS_ATTENTION')
                          ? say(
                              'Needs Attention — minimum $minimum characters',
                              'يحتاج إلى مراجعة — الحد الأدنى $minimum حرفًا',
                            )
                          : say(
                              'Completion is validated by the server when saved.',
                              'يتحقق الخادم من اكتمال المحتوى عند الحفظ.',
                            ),
                    ),
                  ],
                ),
              ),
              if (widget.section == 'summary') ...[
                const SizedBox(height: TokensV0.space12),
                const SummaryWritingHints(),
              ],
              const SizedBox(height: TokensV0.space20),
              if (widget.builderStep == null) ...[
                PrimaryAction(
                  key: Key('save-${widget.section}'),
                  label: copy.saveAction,
                  onPressed: busy ? null : (fromReview ? advance : save),
                ),
                const SizedBox(height: TokensV0.space12),
                TextButton(
                  onPressed: busy ? null : leave,
                  child: Text(fromReview ? copy.backAction : copy.saveLater),
                ),
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
    if (widget.builderStep != null) {
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
      leading: IconButton(
        onPressed: busy ? null : leave,
        icon: const Icon(Icons.arrow_back),
        tooltip: copy.backAction,
      ),
      child: child,
    );
  }
}
