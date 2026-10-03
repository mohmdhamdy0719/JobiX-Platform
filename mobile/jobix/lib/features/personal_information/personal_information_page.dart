import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/design/app_language_button.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ar.dart';
import '../../l10n/app_localizations_en.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/career_profile_repository.dart';
import '../home/home_page.dart';
import 'personal_information_fields.dart';
import 'personal_information_validator.dart';

class PersonalInformationPage extends ConsumerStatefulWidget {
  const PersonalInformationPage({super.key});
  @override
  ConsumerState<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState
    extends ConsumerState<PersonalInformationPage> {
  final controllers = {
    for (final field in personalFields) field: TextEditingController(),
  };
  final errors = <String>{};
  DraftRepository? repository;
  CareerProfile? profile;
  PersonalDraft? draft;
  Future<void> writes = Future.value();
  bool busy = false,
      failed = false,
      dirty = false,
      storageFailed = false,
      allowPop = false;
  String? notice;
  List<String> cityHistory = [];
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final repo = await ref.read(draftRepositoryProvider.future);
      final value = await ref.read(firstProfileProvider.future);
      final local = await repo.draft(value);
      final rawCities = await repo.database.setting('cities_${repo.user}');
      if (!mounted) return;
      repository = repo;
      profile = value;
      draft =
          local ??
          PersonalDraft(
            profileId: value.id,
            baseVersion: value.version,
            personal: value.personal,
            resumeLanguage: value.resumeLanguage,
          );
      for (final field in personalFields) {
        controllers[field]!.text = draft!.personal[field] ?? '';
      }
      cityHistory =
          rawCities?.split('\n').where((v) => v.isNotEmpty).toList() ?? [];
      dirty = local != null;
      // Remove obsolete local intent metadata; routing is server-authoritative.
      await repo.database.removeSetting('registration_user');
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
    super.dispose();
  }

  void retain(PersonalDraft value) {
    setState(() {
      draft = value;
      dirty = true;
      notice = null;
    });
    writes = writes
        .then((_) => repository!.retain(value))
        .then((_) {
          if (mounted) setState(() => storageFailed = false);
        })
        .catchError((Object _) {
          if (mounted) setState(() => storageFailed = true);
        });
  }

  Future<bool> persistNow() async {
    try {
      await writes;
      await repository!.retain(draft!);
      if (mounted) setState(() => storageFailed = false);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          storageFailed = true;
          notice = AppLocalizations.of(context)!.localWriteError;
        });
      }
      return false;
    }
  }

  Future<void> save() async {
    if (busy) return;
    final copy = AppLocalizations.of(context)!;
    setState(() {
      busy = true;
      errors.clear();
      notice = null;
    });
    if (!await persistNow()) {
      if (mounted) setState(() => busy = false);
      return;
    }
    for (final field in personalFields) {
      if (validatePersonalField(field, draft!.personal[field] ?? '') != null) {
        errors.add(field);
      }
    }
    if (errors.isNotEmpty) {
      if (mounted) {
        setState(() {
          busy = false;
          notice = copy.savedDevice;
        });
      }
      return;
    }
    try {
      final saved = await repository!.save(draft!);
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
      dirty = retained != null;
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
      ref.invalidate(firstProfileProvider);
      ref.invalidate(unfinishedDraftProvider(saved.id));
      if (mounted) {
        setState(
          () => notice = retained == null ? copy.savedServer : copy.savedDevice,
        );
      }
    } catch (error) {
      if (!mounted) return;
      draft = await repository!.draft(profile!) ?? draft;
      if (!mounted) return;
      if (error is PostgrestException &&
          error.message.contains('VERSION_CONFLICT')) {
        await conflict();
      } else {
        setState(() => notice = copy.saveFailed);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> conflict() async {
    final copy = AppLocalizations.of(context)!;
    try {
      final latest = await repository!.load(freshOnly: true);
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
      if (choice) {
        // Explicit rebasing, never last-write-wins.
        draft = PersonalDraft(
          profileId: latest.id,
          baseVersion: latest.version,
          personal: draft!.personal,
          resumeLanguage: draft!.resumeLanguage,
        );
        await repository!.retain(draft!);
      } else {
        await repository!.database.discardDraft(repository!.user, latest.id);
        draft = PersonalDraft(
          profileId: latest.id,
          baseVersion: latest.version,
          personal: latest.personal,
          resumeLanguage: latest.resumeLanguage,
        );
        dirty = false;
        for (final field in personalFields) {
          controllers[field]!.text = draft!.personal[field] ?? '';
        }
      }
      if (mounted) {
        setState(() => notice = choice ? copy.savedDevice : copy.savedServer);
      }
    } catch (_) {
      if (mounted) setState(() => notice = copy.saveFailed);
    }
  }

  Future<void> leave() async {
    if (busy) return;
    if (!dirty || draft == null) {
      exit();
      return;
    }
    final copy = AppLocalizations.of(context)!;
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
            key: const Key('discard-draft'),
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(copy.discardAction),
          ),
          TextButton(
            key: const Key('save-later'),
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(copy.saveLater),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    setState(() => busy = true);
    try {
      if (choice == 'save') {
        if (!await persistNow()) return;
      } else {
        await writes;
        await repository!.discard(profile!.id);
      }
      if (mounted) exit();
    } catch (_) {
      if (mounted) setState(() => notice = copy.outcomeUnknown);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void exit() {
    allowPop = true;
    if (profile != null) ref.invalidate(unfinishedDraftProvider(profile!.id));
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final merge = ref.watch(contextMergeProvider);
    if (failed || draft == null) {
      return SliceScaffold(
        title: copy.personalInformation,
        leading: IconButton(
          tooltip: copy.backAction,
          icon: const Icon(Icons.arrow_back),
          onPressed: exit,
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
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final language = draft!.resumeLanguage;
    final profileCopy = language == 'ar'
        ? AppLocalizationsAr()
        : AppLocalizationsEn();
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(leave());
      },
      child: SliceScaffold(
        title: copy.personalInformation,
        leading: IconButton(
          key: const Key('leave-personal'),
          tooltip: copy.backAction,
          icon: const Icon(Icons.arrow_back),
          onPressed: busy ? null : leave,
        ),
        actions: const [AppLanguageButton()],
        bottom: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : leave,
                child: Text(copy.leaveAction),
              ),
            ),
            const SizedBox(width: TokensV0.space12),
            Expanded(
              child: PrimaryAction(
                key: const Key('save-personal'),
                label: copy.saveAction,
                busy: busy,
                onPressed: save,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(copy.personalIntro),
            const SizedBox(height: TokensV0.space24),
            SliceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(
                    title: copy.resumeLanguage,
                    subtitle: copy.resumeLanguageHint,
                  ),
                  const SizedBox(height: TokensV0.space16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: TokensV0.secondarySurface,
                      borderRadius: BorderRadius.circular(
                        TokensV0.controlRadius,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('resume-en'),
                            label: const Text('English (LTR)'),
                            showCheckmark: false,
                            selectedColor: TokensV0.surfaceCard,
                            backgroundColor: TokensV0.secondarySurface,
                            selected: language == 'en',
                            onSelected: busy
                                ? null
                                : (_) => retain(draft!.language('en')),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('resume-ar'),
                            label: const Text('العربية (RTL)'),
                            showCheckmark: false,
                            selectedColor: TokensV0.surfaceCard,
                            backgroundColor: TokensV0.secondarySurface,
                            selected: language == 'ar',
                            onSelected: busy
                                ? null
                                : (_) => retain(draft!.language('ar')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (merge.hasError) ...[
              const SizedBox(height: TokensV0.space16),
              Text(copy.contextPending),
              TextButton(
                onPressed: () => ref.invalidate(contextMergeProvider),
                child: Text(copy.retry),
              ),
            ],
            if (notice != null || storageFailed) ...[
              const SizedBox(height: TokensV0.space16),
              SliceCard(
                child: Text(storageFailed ? copy.localWriteError : notice!),
              ),
            ],
            const SizedBox(height: TokensV0.space24),
            if (language == null)
              Text(copy.chooseResumeLanguage)
            else
              PersonalInformationFields(
                copy: profileCopy,
                clearLabel: copy.discardAction,
                language: language,
                controllers: controllers,
                errors: errors,
                enabled: !busy,
                regionEgypt:
                    WidgetsBinding
                        .instance
                        .platformDispatcher
                        .locale
                        .countryCode ==
                    'EG',
                cityHistory: cityHistory,
                onChanged: (field, value) {
                  errors.add(field);
                  retain(draft!.edit(field, value));
                },
              ),
          ],
        ),
      ),
    );
  }
}
