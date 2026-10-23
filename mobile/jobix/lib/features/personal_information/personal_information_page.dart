import 'dart:async';
import '../../core/navigation/back_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/design/jobix_dialog.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/design/jobix_feedback.dart';
import '../../core/providers.dart';
import '../../core/design/form_loading_state.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ar.dart';
import '../../l10n/app_localizations_en.dart';
import '../auth/auth_controller.dart';
import '../resume/resume_language_repository.dart';
import '../builder/builder_scaffold.dart';
import '../builder/profile_overview.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/career_profile_repository.dart';
import '../career_profile/text_section_repository.dart';
import '../home/home_page.dart';
import 'personal_information_fields.dart';
import 'personal_information_validator.dart';

class PersonalInformationPage extends ConsumerStatefulWidget {
  const PersonalInformationPage({this.builder = false, this.origin, super.key});
  // Step 1 of the guided builder (no app-language control here).
  final bool builder;
  // 'review' returns to Review after Back or a successful save.
  final String? origin;
  @override
  ConsumerState<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState
    extends ConsumerState<PersonalInformationPage> {
  final controllers = {
    for (final field in personalFields) field: TextEditingController(),
  };
  final targetRoleController = TextEditingController();
  final errors = <String>{};
  DraftRepository? repository;
  CareerProfile? profile;
  PersonalDraft? draft;
  TextSectionRepository? textRepository;
  TextSectionDraft? targetRoleDraft;
  String roleBaseline = '';
  Map<String, String> personalBaseline = {};
  String? languageBaseline;
  bool busy = false, failed = false, dirty = false, allowPop = false;
  String? notice;
  List<String> cityHistory = [];

  bool get hasUnsavedChanges =>
      dirty ||
      (profile != null &&
          targetRoleDraft != null &&
          (targetRoleDraft!.text.trim() != roleBaseline.trim() ||
              targetRoleDraft!.request != null));
  bool get needsServerSave =>
      hasUnsavedChanges ||
      draft?.localOnly == true ||
      targetRoleDraft?.localOnly == true ||
      hasPendingSave;
  bool get hasPendingSave =>
      draft?.frozen != null || targetRoleDraft?.request != null;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final repo = await ref.read(draftRepositoryProvider.future);
      final value = await repo.load();
      final local = await repo.draft(value);
      final textRepo = await ref.read(textSectionRepositoryProvider.future);
      final localRole = await textRepo.load(value, 'target_role');
      final rawCities = await repo.database.setting('cities_${repo.user}');
      if (!mounted) return;
      repository = repo;
      profile = value;
      textRepository = textRepo;
      targetRoleDraft =
          localRole ??
          TextSectionDraft(
            profileId: value.id,
            section: 'target_role',
            version: value.version,
            text: value.targetRole,
          );
      targetRoleController.text = targetRoleDraft!.text;
      roleBaseline = targetRoleDraft!.text;
      // Initial account suggestion only: do not reinsert an intentionally
      // cleared email from a local draft or overwrite saved profile contact.
      final authEmail = ref
          .read(supabaseClientProvider)
          .valueOrNull
          ?.auth
          .currentUser
          ?.email;
      final prefillEmail =
          local == null &&
          (value.personal['email'] ?? '').isEmpty &&
          !value.hasContact &&
          value.resumeLanguage == null &&
          authEmail != null &&
          authEmail.isNotEmpty;
      final appLanguage = Localizations.localeOf(context).languageCode == 'ar'
          ? 'ar'
          : 'en';
      final initializeLanguage =
          local == null &&
          value.resumeLanguage == null &&
          await ref.read(firstEntryProvider.future);
      final configuredLanguage =
          local == null &&
              value.resumeLanguage == null &&
              widget.origin == 'career'
          ? await ref.read(savedResumeLanguageProvider(value.id).future)
          : value.resumeLanguage;
      if (!mounted) return;
      draft =
          local ??
          PersonalDraft(
            profileId: value.id,
            baseVersion: value.version,
            personal: prefillEmail
                ? {...value.personal, 'email': authEmail}
                : value.personal,
            resumeLanguage:
                configuredLanguage ?? (initializeLanguage ? appLanguage : null),
          );
      for (final field in personalFields) {
        controllers[field]!.text = draft!.personal[field] ?? '';
      }
      cityHistory =
          rawCities?.split('\n').where((v) => v.isNotEmpty).toList() ?? [];
      resetEditBaseline();
      notice = local?.localOnly == true || localRole?.localOnly == true
          ? AppLocalizations.of(context)!.savedDevice
          : null;
      if (!mounted) return;
      ref.read(authFlowProvider.notifier).state = const AuthFlow();
      setState(() {
        failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    targetRoleController.dispose();
    super.dispose();
  }

  void retain(PersonalDraft value) {
    if (hasPendingSave) return;
    setState(() {
      draft = value;
      dirty =
          personalFields.any(
            (field) =>
                (value.personal[field] ?? '').trim() !=
                (personalBaseline[field] ?? '').trim(),
          ) ||
          value.resumeLanguage != languageBaseline;
      notice = null;
    });
  }

  void resetEditBaseline() {
    personalBaseline = Map<String, String>.from(draft!.personal);
    languageBaseline = draft!.resumeLanguage;
    dirty = false;
  }

  void retainTargetRole(String value) {
    if (hasPendingSave) return;
    final current = targetRoleDraft!;
    final next = current.edit(value);
    setState(() {
      targetRoleDraft = next;
      notice = null;
    });
  }

  Future<void> save() async {
    if (busy || !needsServerSave) return;
    var savingRole = false;
    var confirmedMutation = false;
    final copy = AppLocalizations.of(context)!;
    setState(() {
      busy = true;
      errors.clear();
      notice = null;
    });
    for (final field in personalFields) {
      if (validatePersonalField(field, draft!.personal[field] ?? '') != null) {
        errors.add(field);
      }
    }
    if (errors.isNotEmpty) {
      if (mounted) {
        setState(() {
          busy = false;
          notice = copy.saveFailed;
        });
        showJobixFeedback(
          context,
          copy.localeName.startsWith('ar')
              ? 'راجع الحقول المحددة. لم يتم حفظ أي تغيير في حسابك.'
              : 'Check the highlighted fields. No changes were saved to your account.',
          kind: JobixFeedbackKind.warning,
        );
      }
      return;
    }
    try {
      // Capture both parts locally before either explicit mutation begins.
      // These snapshots are not authoritative and never upload themselves.
      if (draft!.frozen == null && (dirty || draft!.localOnly)) {
        await repository!.retain(draft!.deviceOnly());
      }
      if (targetRoleDraft!.request == null &&
          (targetRoleDraft!.text != profile!.targetRole ||
              targetRoleDraft!.localOnly)) {
        await textRepository!.retain(targetRoleDraft!.deviceOnly());
      }
      // Resolve a durable, ambiguous role-save request before sending another
      // mutation against its old profile version.
      if (targetRoleDraft!.request != null) {
        savingRole = true;
        profile = await textRepository!.save(targetRoleDraft!);
        confirmedMutation = true;
        savingRole = false;
        targetRoleDraft =
            await textRepository!.load(profile!, 'target_role') ??
            TextSectionDraft(
              profileId: profile!.id,
              section: 'target_role',
              version: profile!.version,
              text: profile!.targetRole,
            );
        targetRoleController.text = targetRoleDraft!.text;
        if (draft!.frozen == null) {
          draft = PersonalDraft(
            profileId: draft!.profileId,
            baseVersion: profile!.version,
            personal: draft!.personal,
            resumeLanguage: draft!.resumeLanguage,
          );
        }
      }
      final personalChanged =
          draft!.frozen != null ||
          (dirty || draft!.localOnly) &&
              (personalFields.any(
                    (field) =>
                        (draft!.personal[field] ?? '').trim() !=
                        (profile!.personal[field] ?? '').trim(),
                  ) ||
                  draft!.resumeLanguage != profile!.resumeLanguage);
      if (!personalChanged && draft!.localOnly) {
        // An acknowledged saved value may have caught up with an older local
        // draft. Do not submit its obsolete version or invent a new mutation.
        await repository!.discard(profile!.id);
      }
      final saved = personalChanged ? await repository!.save(draft!) : profile!;
      confirmedMutation = confirmedMutation || personalChanged;
      if (!mounted) return;
      profile = saved;
      final retained = await repository!.draft(saved);
      draft =
          retained ??
          PersonalDraft(
            profileId: saved.id,
            baseVersion: saved.version,
            personal: saved.personal,
            resumeLanguage: saved.resumeLanguage,
          );
      resetEditBaseline();
      for (final field in personalFields) {
        controllers[field]!.text = draft!.personal[field] ?? '';
      }
      final city = saved.personal['city'] ?? '';
      if (city.isNotEmpty && !cityHistory.contains(city)) {
        cityHistory.add(city);
        await repository!.database.setSetting(
          'cities_${repository!.user}',
          cityHistory.join('\n'),
        );
      }
      // The profile mutation above advances the version. Rebase only a local
      // role draft with no frozen request; an ambiguous request keeps its
      // original identity and version for safe reconciliation.
      if (targetRoleDraft!.request == null) {
        if (targetRoleController.text.trim() == saved.targetRole.trim()) {
          await textRepository!.discard(saved, 'target_role');
        }
        targetRoleDraft = TextSectionDraft(
          profileId: saved.id,
          section: 'target_role',
          version: saved.version,
          text: targetRoleController.text,
        );
        if (targetRoleController.text.trim() != saved.targetRole.trim()) {
          savingRole = true;
          profile = await textRepository!.save(targetRoleDraft!);
          confirmedMutation = true;
          savingRole = false;
          targetRoleDraft =
              await textRepository!.load(profile!, 'target_role') ??
              TextSectionDraft(
                profileId: profile!.id,
                section: 'target_role',
                version: profile!.version,
                text: profile!.targetRole,
              );
          targetRoleController.text = targetRoleDraft!.text;
        }
      }
      if (retained == null) {
        // Target Role is a second, versioned Profile mutation. Keep the open
        // Personal form on the final acknowledged version, not the version
        // preceding that mutation. Never rebase an unresolved request.
        draft = PersonalDraft(
          profileId: profile!.id,
          baseVersion: profile!.version,
          personal: profile!.personal,
          resumeLanguage: profile!.resumeLanguage,
        );
        resetEditBaseline();
      }
      ref.invalidate(firstProfileProvider);
      ref.invalidate(unfinishedDraftProvider(saved.id));
      roleBaseline = targetRoleDraft!.text;
      if (mounted) {
        setState(() {
          notice = retained == null && !hasUnsavedChanges
              ? (confirmedMutation ? copy.savedServer : null)
              : copy.saveFailed;
        });
        if (confirmedMutation && retained == null && !hasUnsavedChanges) {
          showJobixFeedback(
            context,
            copy.localeName.startsWith('ar')
                ? 'تم حفظ معلوماتك.'
                : 'Personal information saved.',
          );
        }
      }
    } on LocalDraftSavedException {
      final local = await repository!.draft(profile!);
      final localRole = await textRepository!.load(profile!, 'target_role');
      if (!mounted) return;
      setState(() {
        draft = local ?? draft;
        targetRoleDraft = localRole ?? targetRoleDraft;
        roleBaseline = targetRoleDraft!.text;
        resetEditBaseline();
        notice = copy.savedDevice;
      });
      ref.invalidate(unfinishedDraftProvider(profile!.id));
      showJobixFeedback(context, copy.savedDevice);
    } catch (error) {
      if (!mounted) return;
      try {
        draft = await repository!.draft(profile!) ?? draft;
        targetRoleDraft =
            await textRepository!.load(profile!, 'target_role') ??
            targetRoleDraft;
      } catch (_) {
        // Keep the open editor value; report that the save is not confirmed.
      }
      if (!mounted) return;
      if (error is PostgrestException &&
          error.message.contains('VERSION_CONFLICT')) {
        if (savingRole) {
          await targetRoleConflict();
        } else {
          await conflict();
        }
      } else {
        setState(
          () => notice = hasPendingSave ? copy.outcomeUnknown : copy.saveFailed,
        );
        showJobixFeedback(
          context,
          hasPendingSave ? copy.outcomeUnknown : copy.saveFailed,
          kind: JobixFeedbackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> targetRoleConflict() async {
    final copy = AppLocalizations.of(context)!;
    try {
      final latest = await repository!.load(freshOnly: true);
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
      if (choice) {
        targetRoleDraft = TextSectionDraft(
          profileId: latest.id,
          section: 'target_role',
          version: latest.version,
          text: targetRoleController.text,
          localOnly: true,
        );
        await textRepository!.retain(targetRoleDraft!);
        roleBaseline = targetRoleDraft!.text;
        setState(
          () => notice = copy.localeName.startsWith('ar')
              ? 'تغييراتك غير محفوظة. اختر حفظ لتطبيقها.'
              : 'Your changes are not saved. Choose Save to apply them.',
        );
      } else {
        await repository!.database.discardSection(
          repository!.user,
          latest.id,
          'target_role',
        );
        targetRoleDraft = TextSectionDraft(
          profileId: latest.id,
          section: 'target_role',
          version: latest.version,
          text: latest.targetRole,
        );
        targetRoleController.text = latest.targetRole;
        setState(() => notice = copy.savedServer);
      }
    } catch (_) {
      if (mounted) setState(() => notice = copy.saveFailed);
    }
  }

  Future<void> conflict() async {
    final copy = AppLocalizations.of(context)!;
    try {
      final latest = await repository!.load(freshOnly: true);
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
      if (choice) {
        // Explicit rebasing, never last-write-wins.
        draft = PersonalDraft(
          profileId: latest.id,
          baseVersion: latest.version,
          personal: draft!.personal,
          resumeLanguage: draft!.resumeLanguage,
          localOnly: true,
        );
        await repository!.retain(draft!);
        resetEditBaseline();
      } else {
        await repository!.database.discardDraft(repository!.user, latest.id);
        draft = PersonalDraft(
          profileId: latest.id,
          baseVersion: latest.version,
          personal: latest.personal,
          resumeLanguage: latest.resumeLanguage,
        );
        resetEditBaseline();
        for (final field in personalFields) {
          controllers[field]!.text = draft!.personal[field] ?? '';
        }
      }
      if (mounted) {
        setState(
          () => notice = choice
              ? (copy.localeName.startsWith('ar')
                    ? 'تغييراتك غير محفوظة. اختر حفظ لتطبيقها.'
                    : 'Your changes are not saved. Choose Save to apply them.')
              : copy.savedServer,
        );
      }
    } catch (_) {
      if (mounted) setState(() => notice = copy.saveFailed);
    }
  }

  Future<void> leave() async {
    if (busy) return;
    if (hasPendingSave) {
      final copy = AppLocalizations.of(context)!;
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => JobixAlertDialog(
          title: Text(copy.outcomeUnknown),
          content: Text(
            copy.localeName.startsWith('ar')
                ? 'يجب تسوية الحفظ الأصلي قبل تجاهل التغييرات. أعد الطلب نفسه أو ابق هنا.'
                : 'The original save must be reconciled before these changes can be discarded. Retry the same request or stay here.',
          ),
          actions: [
            JobixDialogAction.secondary(
              onPressed: () => Navigator.pop(context, false),
              child: Text(copy.stayAction),
            ),
            JobixDialogAction.primary(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                copy.localeName.startsWith('ar') ? 'إعادة الحفظ' : 'Retry Save',
              ),
            ),
          ],
        ),
      );
      if (retry == true && mounted) await save();
      return;
    }
    if (!hasUnsavedChanges || draft == null) {
      exit();
      return;
    }
    final copy = AppLocalizations.of(context)!;
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
            key: const Key('discard-draft'),
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(copy.discardAction),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    setState(() => busy = true);
    try {
      if (draft!.frozen != null || targetRoleDraft?.request != null) {
        if (mounted) setState(() => notice = copy.outcomeUnknown);
        return;
      }
      // Input changes are only in memory. Preserve any previously explicitly
      // saved device draft; this exit abandons edits made since that snapshot.
      if (mounted) exit();
    } catch (_) {
      if (mounted) setState(() => notice = copy.outcomeUnknown);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get fromReview => widget.origin == 'review';

  void exit() {
    allowPop = true;
    if (profile != null) ref.invalidate(unfinishedDraftProvider(profile!.id));
    context.go(
      fromReview
          ? '/builder/6'
          : widget.builder
          ? '/home'
          : '/career',
    );
  }

  /// Continue (builder) / Save (from Review): save only when edited, and
  /// move on only after the server acknowledged the save.
  Future<void> advance() async {
    if (busy || draft == null) return;
    if (needsServerSave) await save();
    if (!mounted || needsServerSave) return;
    allowPop = true;
    context.go(
      fromReview
          ? '/builder/6'
          : widget.builder
          ? '/builder/2'
          : '/career',
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final merge = ref.watch(contextMergeProvider);
    if (failed || draft == null) {
      return JobixBackHandler(
        onBack: leave,
        child: SliceScaffold(
          title: copy.personalInformation,
          singleLineTitle: true,
          actions: widget.builder || fromReview
              ? const [CreditsPill(compact: true)]
              : null,
          leading: widget.builder && !fromReview
              ? null
              : IconButton(
                  tooltip: copy.backAction,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => requestJobixBack(context),
                ),
          child: failed
              ? Column(
                  children: [
                    Text(copy.profileUnavailable),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(firstProfileProvider);
                        load();
                      },
                      child: Text(copy.retry),
                    ),
                  ],
                )
              : const FormLoadingState(),
        ),
      );
    }
    final language = draft!.resumeLanguage;
    final profileCopy = language == 'ar'
        ? AppLocalizationsAr()
        : AppLocalizationsEn();
    return JobixBackHandler(
      onBack: leave,
      child: widget.builder && !fromReview
          ? BuilderScaffold(
              step: 1,
              busy: busy,
              onContinue: advance,
              child: body(copy, language, profileCopy, merge.hasError),
            )
          : SliceScaffold(
              title: copy.personalInformation,
              singleLineTitle: true,
              actions: fromReview ? const [CreditsPill(compact: true)] : null,
              leading: IconButton(
                key: const Key('leave-personal'),
                tooltip: copy.backAction,
                icon: const Icon(Icons.arrow_back),
                onPressed: busy ? null : () => requestJobixBack(context),
              ),
              bottom: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => requestJobixBack(context),
                      child: Text(
                        fromReview ? copy.backToReview : copy.leaveAction,
                      ),
                    ),
                  ),
                  const SizedBox(width: TokensV0.space12),
                  Expanded(
                    child: PrimaryAction(
                      key: const Key('save-personal'),
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
              child: body(copy, language, profileCopy, merge.hasError),
            ),
    );
  }

  Widget body(
    AppLocalizations copy,
    String? language,
    AppLocalizations profileCopy,
    bool mergeFailed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(copy.personalIntro),
        if (hasPendingSave) ...[
          const SizedBox(height: TokensV0.space12),
          SliceCard(
            child: Text(
              copy.localeName.startsWith('ar')
                  ? 'لم يتم تأكيد الحفظ. أعد الحفظ لتسوية الطلب الأصلي؛ التعديل متوقف حتى ذلك الحين.'
                  : 'This save is not confirmed. Retry Save to reconcile the original request; editing is locked until then.',
            ),
          ),
        ],
        if (widget.origin != 'career') ...[
          const SizedBox(height: TokensV0.space24),
          SliceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeading(
                  title: copy.resumeLanguage,
                  subtitle: copy.resumeLanguageHint,
                ),
                const SizedBox(height: TokensV0.space16),
                Container(
                  key: const Key('resume-language-options'),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: TokensV0.secondarySurface,
                    borderRadius: BorderRadius.circular(TokensV0.controlRadius),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ChoiceChip(
                            key: const Key('resume-en'),
                            label: const Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'English (LTR)',
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                            ),
                            showCheckmark: false,
                            labelPadding: EdgeInsets.zero,
                            padding: EdgeInsets.zero,
                            checkmarkColor: TokensV0.onPrimary,
                            labelStyle: TokensV0.languageChoiceLabel(
                              languageCode: 'en',
                              selected: language == 'en',
                            ),
                            selectedColor: TokensV0.primary,
                            backgroundColor: TokensV0.secondarySurface,
                            selected: language == 'en',
                            onSelected: busy || hasPendingSave
                                ? null
                                : (_) => retain(draft!.language('en')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ChoiceChip(
                            key: const Key('resume-ar'),
                            label: const Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'العربية (RTL)',
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            ),
                            showCheckmark: false,
                            labelPadding: EdgeInsets.zero,
                            padding: EdgeInsets.zero,
                            checkmarkColor: TokensV0.onPrimary,
                            labelStyle: TokensV0.languageChoiceLabel(
                              languageCode: 'ar',
                              selected: language == 'ar',
                            ),
                            selectedColor: TokensV0.primary,
                            backgroundColor: TokensV0.secondarySurface,
                            selected: language == 'ar',
                            onSelected: busy || hasPendingSave
                                ? null
                                : (_) => retain(draft!.language('ar')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (mergeFailed) ...[
          const SizedBox(height: TokensV0.space16),
          Text(copy.contextPending),
          TextButton(
            onPressed: () => ref.invalidate(contextMergeProvider),
            child: Text(copy.retry),
          ),
        ],
        if (notice != null) ...[
          const SizedBox(height: TokensV0.space16),
          SliceCard(child: Text(notice!)),
        ],
        const SizedBox(height: TokensV0.space24),
        if (language == null)
          Text(copy.chooseResumeLanguage)
        else
          PersonalInformationFields(
            copy: copy,
            writingCopy: profileCopy,
            clearLabel: copy.clearField,
            language: language,
            controllers: controllers,
            errors: errors,
            enabled: !busy && !hasPendingSave,
            regionEgypt:
                WidgetsBinding.instance.platformDispatcher.locale.countryCode ==
                'EG',
            cityHistory: cityHistory,
            targetRoleController: targetRoleController,
            onTargetRoleChanged: retainTargetRole,
            onChanged: (field, value) {
              errors.remove(field);
              retain(draft!.edit(field, value));
            },
            onBlur: (field) {
              if (!mounted) return;
              setState(() => errors.add(field));
            },
          ),
        const SizedBox(height: TokensV0.space24),
        SliceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(
                title: copy.localeName.startsWith('ar')
                    ? 'الصورة والروابط المخصصة'
                    : 'Photo & custom links',
                subtitle: copy.localeName.startsWith('ar')
                    ? 'أضف صورة للملف الشخصي وروابط مهنية لتخصيص سيرتك الذاتية.'
                    : 'Add a profile photo and professional links to personalize your resume.',
              ),
              const SizedBox(height: TokensV0.space12),
              OutlinedButton.icon(
                key: const Key('personal-extras'),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  copy.localeName.startsWith('ar')
                      ? 'إدارة الصورة والروابط'
                      : 'Manage photo & links',
                ),
                onPressed: busy
                    ? null
                    : () async {
                        if (hasUnsavedChanges) {
                          showJobixFeedback(
                            context,
                            hasPendingSave
                                ? copy.outcomeUnknown
                                : copy.localeName.startsWith('ar')
                                ? 'احفظ تغييرات المعلومات الشخصية أو تجاهلها قبل فتح الصورة والروابط.'
                                : 'Save or discard Personal Information changes before opening photo and links.',
                            kind: JobixFeedbackKind.warning,
                          );
                          return;
                        }
                        if (!mounted) return;
                        final origin = fromReview
                            ? 'review'
                            : widget.builder
                            ? 'builder'
                            : 'career';
                        context.go('/career/extras?origin=$origin');
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
