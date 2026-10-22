import 'dart:convert';
import '../../core/navigation/back_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/design/jobix_feedback.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../personal_information/profile_extras_repository.dart';
import 'resume_export_panel.dart';
import 'resume_preview_page.dart';
import 'resume_preview_snapshot.dart';
import 'resume_experience_widgets.dart';
import '../builder/profile_overview.dart';
import 'resume_layout.dart';
import 'resume_layout_page.dart';
import 'resume_layout_repository.dart';

/// Configuration references the Career Profile; it never copies editable data.
class ResumePage extends ConsumerStatefulWidget {
  const ResumePage({super.key});
  @override
  ConsumerState<ResumePage> createState() => _ResumePageState();
}

class _ResumePageState extends ConsumerState<ResumePage> {
  CareerProfile? profile;
  String? ownerId;
  String? language, savedLanguage;
  int version = 0;
  bool busy = false, failed = false, pending = false;
  final exportKey = GlobalKey<ResumeExportPanelState>();
  String? message;
  Map<String, dynamic>? preparedDocument;
  bool configurationConflict = false;
  bool layoutPending = false;
  String? confirmedDraftFingerprint;
  bool get languageDirty => language != null && language != savedLanguage;
  String key(String user, String id) => 'resume:$user:$id';
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String arabic) => ar ? arabic : en;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final repository = await ref.read(draftRepositoryProvider.future);
      final p = await repository.load(freshOnly: true);
      final client = await ref.read(supabaseClientProvider.future);
      final actor = client.auth.currentUser?.id;
      if (actor == null) throw StateError('AUTH_REQUIRED');
      final data = await client
          .rpc('read_resume_configuration', params: {'requested_profile': p.id})
          .timeout(const Duration(seconds: 15));
      final db = await ref.read(databaseProvider.future);
      final raw = await db.setting(key(actor, p.id));
      layoutPending = await db.setting('resume:$actor:layout:${p.id}') != null;
      if (!mounted) return;
      if (client.auth.currentUser?.id != actor) {
        throw StateError('AUTH_REQUIRED');
      }
      profile = p;
      ownerId = actor;
      if (data is Map) {
        savedLanguage = data['language'] as String;
        version = data['version'] as int;
      } else {
        savedLanguage = p.resumeLanguage ?? 'en';
        version = 0;
      }
      language = savedLanguage;
      configurationConflict = false;
      if (raw != null) {
        final request = jsonDecode(raw) as Map;
        language = request['language'] as String;
        pending = true;
      } else {
        pending = false;
      }
      confirmedDraftFingerprint = null;
      setState(() => failed = false);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<ResumePreviewSnapshot> _loadLocalSnapshot() async {
    final client = await ref.read(supabaseClientProvider.future);
    final actor = client.auth.currentUser?.id;
    if (actor == null) throw StateError('AUTH_REQUIRED');
    final repository = await ref.read(draftRepositoryProvider.future);
    if (repository.user != actor) throw StateError('AUTH_REQUIRED');
    final extrasRepository = await ref.read(
      profileExtrasRepositoryProvider.future,
    );
    final fonts = await loadResumePreviewFonts();
    final loader = ResumePreviewSnapshotLoader(
      loadFreshProfile: () => repository.load(freshOnly: true),
      readFreshExtras: (profileId) async {
        final result = await extrasRepository.api.read(profileId);
        if (client.auth.currentUser?.id != actor) {
          throw StateError('AUTH_REQUIRED');
        }
        return result;
      },
      readConfiguration: (profileId) async {
        final result = await client
            .rpc(
              'read_resume_configuration',
              params: {'requested_profile': profileId},
            )
            .timeout(const Duration(seconds: 15));
        if (client.auth.currentUser?.id != actor) {
          throw StateError('AUTH_REQUIRED');
        }
        return result == null ? null : Map<String, dynamic>.from(result as Map);
      },
      inspectDrafts: (currentProfile, extras) => inspectResumePreviewDrafts(
        profileRepository: repository,
        extrasRepository: extrasRepository,
        profile: currentProfile,
        savedExtras: extras,
      ),
      latinFontBase64: fonts.$1,
      arabicFontBase64: fonts.$2,
    );
    final snapshot = await loader.load(
      confirmedDraftFingerprint: confirmedDraftFingerprint,
    );
    if (client.auth.currentUser?.id != actor) throw StateError('AUTH_REQUIRED');
    final keepSelectedLanguage = languageDirty;
    profile = snapshot.profile;
    ownerId = actor;
    version = snapshot.configuration['version'] as int;
    savedLanguage = snapshot.configuration['language'] as String;
    if (!keepSelectedLanguage) language = savedLanguage;
    return snapshot;
  }

  Future<void> saveLanguage() async {
    if (language == null || profile == null || busy) return;
    final selectedLanguage = language!;
    setState(() {
      busy = true;
      message = t('Saving Resume language…', 'جارٍ حفظ لغة السيرة الذاتية…');
    });
    try {
      final client = await ref.read(supabaseClientProvider.future);
      final user = client.auth.currentUser?.id;
      if (user == null || user != ownerId) throw StateError('AUTH_REQUIRED');
      final db = await ref.read(databaseProvider.future);
      final storageKey = key(user, profile!.id);
      var raw = await db.setting(storageKey);
      raw ??= jsonEncode({
        'command_key': newCommandKey(),
        'requested_profile': profile!.id,
        'expected_version': version,
        'language': selectedLanguage,
        'template_id': 'resume_ats_${selectedLanguage}_v1',
      });
      await db.setSetting(storageKey, raw);
      if (client.auth.currentUser?.id != user) {
        throw StateError('AUTH_REQUIRED');
      }
      setState(() => pending = true);
      final result = await client
          .rpc(
            'save_resume_configuration',
            params: Map<String, dynamic>.from(jsonDecode(raw) as Map),
          )
          .timeout(const Duration(seconds: 15));
      if (client.auth.currentUser?.id != user) {
        throw StateError('AUTH_REQUIRED');
      }
      if (result is! Map ||
          result['language'] != selectedLanguage ||
          result['version'] is! int) {
        throw StateError('SAVE_NOT_CONFIRMED');
      }
      await db.removeSetting(storageKey);
      if (mounted) {
        setState(() {
          savedLanguage = selectedLanguage;
          language = selectedLanguage;
          version = result['version'] as int;
          pending = false;
          configurationConflict = false;
          confirmedDraftFingerprint = null;
          message = null;
        });
        showJobixFeedback(
          context,
          t('Resume language updated.', 'تم تحديث لغة السيرة الذاتية.'),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          configurationConflict = error.message.contains('VERSION_CONFLICT');
          message = t(
            'The configuration was not saved. Retry, or reload the saved configuration if it changed elsewhere.',
            'لم يتم حفظ الإعدادات. أعد المحاولة أو أعد تحميل الإعدادات المحفوظة إذا تغيرت على جهاز آخر.',
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = t(
            'The save could not be confirmed. Retry the same saved request before Preview.',
            'تعذّر تأكيد الحفظ. أعد محاولة الطلب المحفوظ نفسه قبل المعاينة.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> selectLanguage(String selectedLanguage) async {
    if (busy || pending || layoutPending) return;
    if (selectedLanguage == savedLanguage && languageDirty) {
      setState(() {
        language = savedLanguage;
        confirmedDraftFingerprint = null;
        message = null;
      });
      return;
    }
    if (selectedLanguage == language) return;
    setState(() {
      language = selectedLanguage;
      confirmedDraftFingerprint = null;
    });
    await saveLanguage();
  }

  Future<void> showPreview() async {
    if (language == null || profile == null || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final snapshot = await _loadLocalSnapshot();
      if (!mounted) return;
      preparedDocument = snapshot.document;
      await exportKey.currentState?.showLocalDocument(snapshot.document);
      if (mounted) setState(() => confirmedDraftFingerprint = null);
    } on ResumePreviewNeedsConfirmation catch (error) {
      if (mounted) {
        setState(() {
          confirmedDraftFingerprint = error.fingerprint;
          message = t(
            'A save is awaiting server confirmation. Preview saved version shows only current cloud data; it will not retry or discard the pending request. Retry the same save to reconcile it.',
            'ما زال حفظٌ ما بانتظار تأكيد الخادم. تعرض معاينة النسخة المحفوظة البيانات السحابية الحالية فقط، دون إعادة الطلب المعلّق أو تجاهله. أعد محاولة الحفظ نفسه لتأكيد نتيجته.',
          );
        });
      }
    } on ResumePreviewBlocked catch (error) {
      if (mounted) {
        setState(
          () => message = switch (error.code) {
            'SAVE_RECONCILIATION_REQUIRED' => t(
              'The current saved version could not be checked. Try Preview again.',
              'تعذّر التحقق من النسخة المحفوظة الحالية. أعد محاولة المعاينة.',
            ),
            'SAVED_RESUME_CHANGED' => t(
              'The saved Resume changed while Preview was loading. Retry to review the latest version.',
              'تغيّرت السيرة المحفوظة أثناء تحميل المعاينة. أعد المحاولة لمراجعة أحدث نسخة.',
            ),
            'UNSUPPORTED_SAVED_CONFIGURATION' => t(
              'This saved presentation uses settings that Preview does not support yet.',
              'تستخدم إعدادات العرض المحفوظة خيارات لا تدعمها المعاينة حاليًا.',
            ),
            'INVALID_SAVED_LINK' => t(
              'A saved custom link is invalid. Review it before Preview.',
              'يوجد رابط محفوظ غير صالح. راجعه قبل المعاينة.',
            ),
            _ => t(
              'Preview is unavailable. Check your connection and try again.',
              'المعاينة غير متاحة. تحقق من الاتصال وأعد المحاولة.',
            ),
          },
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          configurationConflict = error.message.contains('VERSION_CONFLICT');
          message = t(
            'The configuration was not saved. Retry, or reload the saved configuration if it changed elsewhere.',
            'لم يتم حفظ الإعدادات. أعد المحاولة أو أعد تحميل الإعدادات المحفوظة إذا تغيرت على جهاز آخر.',
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = t(
            'Preview could not be loaded. No Credits or export records were changed. Retry after checking your connection.',
            'تعذّر تحميل المعاينة. لم تتغير الأرصدة أو سجلات التصدير. أعد المحاولة بعد التحقق من الاتصال.',
          ),
        );
      }
    } finally {
      preparedDocument = null;
      if (mounted) {
        exportKey.currentState?.clearLocalDocument();
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Map<String, dynamic>?> _exportReviewedDocument(
    Map<String, dynamic> reviewedDocument,
  ) async {
    final panel = exportKey.currentState;
    if (panel == null) return null;
    return panel.createPdf(reviewedDocument);
  }

  Future<void> editLayout() async {
    if (busy || pending || profile == null) return;
    setState(() => busy = true);
    try {
      final client = await ref.read(supabaseClientProvider.future);
      final actor = client.auth.currentUser?.id;
      if (actor == null || actor != ownerId) throw StateError('AUTH_REQUIRED');
      final db = await ref.read(databaseProvider.future);
      final store = ResumeLayoutRepository(
        database: db,
        user: actor,
        profileId: profile!.id,
        isCurrentUser: () => client.auth.currentUser?.id == actor,
        saveRemote: (request) async => Map<String, dynamic>.from(
          await client
                  .rpc('save_resume_layout', params: request)
                  .timeout(const Duration(seconds: 20))
              as Map,
        ),
      );
      final frozen = await store.pending();
      // Always display the latest server-confirmed configuration. A frozen
      // save is reconciled separately with its original command key.
      final snapshot = await _loadLocalSnapshotForLayout();
      final configuration = snapshot.configuration;
      if (!mounted || client.auth.currentUser?.id != actor) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ResumeLayoutPage(
            initial: ResumeLayout.fromConfiguration(configuration),
            pending: frozen != null,
            hasPending: () async => await store.pending() != null,
            onRetryPending: () async {
              await store.retryPending();
              final latest = await _loadLocalSnapshotForLayout();
              return ResumeLayout.fromConfiguration(latest.configuration);
            },
            onReload: () async => ResumeLayout.fromConfiguration(
              (await _loadLocalSnapshotForLayout()).configuration,
            ),
            onSave: (layout) async {
              await store.save(
                layout: layout,
                profileVersion: profile!.version,
                configurationVersion: version,
                language: savedLanguage!,
              );
              if (client.auth.currentUser?.id != actor) {
                throw StateError('AUTH_REQUIRED');
              }
            },
          ),
        ),
      );
      if (mounted) await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => message = t(
            'The saved layout could not be loaded safely. Check your connection and retry.',
            'تعذّر تحميل التصميم المحفوظ بأمان. تحقق من الاتصال وأعد المحاولة.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Layout editing may inspect saved data even when other local edits exist.
  // It never previews, saves, or discards those profile edits.
  Future<({CareerProfile profile, Map<String, dynamic> configuration})>
  _loadLocalSnapshotForLayout() async {
    final repository = await ref.read(draftRepositoryProvider.future);
    final p = await repository.load(freshOnly: true);
    final client = await ref.read(supabaseClientProvider.future);
    if (client.auth.currentUser?.id != ownerId) {
      throw StateError('AUTH_REQUIRED');
    }
    final result = await client
        .rpc('read_resume_configuration', params: {'requested_profile': p.id})
        .timeout(const Duration(seconds: 15));
    if (client.auth.currentUser?.id != ownerId || p.id != profile?.id) {
      throw StateError('AUTH_REQUIRED');
    }
    final config = result == null
        ? <String, dynamic>{'version': 0, 'language': p.resumeLanguage ?? 'en'}
        : Map<String, dynamic>.from(result as Map);
    profile = p;
    version = config['version'] as int;
    savedLanguage = config['language'] as String;
    return (profile: p, configuration: config);
  }

  @override
  Widget build(BuildContext context) {
    return JobixBackHandler(
      onBack: () {
        if (busy) return;
        context.go('/career');
      },
      child: frame(context),
    );
  }

  Widget frame(BuildContext context) {
    return SliceScaffold(
      title: t('Resume Export', 'تصدير السيرة الذاتية'),
      actions: const [CreditsPill()],
      leading: IconButton(
        icon: const BackButtonIcon(),
        onPressed: () => requestJobixBack(context),
      ),
      child: profile == null
          ? failed
                ? Column(
                    children: [
                      Text(
                        t(
                          'Resume settings are unavailable.',
                          'إعدادات السيرة الذاتية غير متاحة.',
                        ),
                      ),
                      TextButton(
                        onPressed: load,
                        child: Text(t('Retry', 'إعادة المحاولة')),
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t(
                    'Customize your resume layout and choose what to include.',
                    'خصّص تصميم سيرتك الذاتية واختر ما تريد تضمينه.',
                  ),
                ),
                TextButton.icon(
                  onPressed: busy || pending ? null : editLayout,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(t('Edit resume layout', 'تعديل تصميم السيرة')),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (final code in ['en', 'ar'])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 4,
                          ),
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Center(
                                child: Text(
                                  code == 'en'
                                      ? 'English (LTR)'
                                      : 'العربية (RTL)',
                                ),
                              ),
                            ),
                            selected: language == code,
                            onSelected: busy || pending || layoutPending
                                ? null
                                : (_) => selectLanguage(code),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'Resume language is independent of app language. Your content is not automatically translated.',
                    'لغة السيرة مستقلة عن لغة التطبيق. لا تتم ترجمة محتواك تلقائيًا.',
                  ),
                ),
                if (languageDirty && !busy)
                  Text(
                    t(
                      'This language choice is not saved. Preview will use the saved language.',
                      'اختيار اللغة غير محفوظ. ستستخدم المعاينة اللغة المحفوظة.',
                    ),
                  ),
                if (pending)
                  TextButton(
                    onPressed: busy ? null : saveLanguage,
                    child: Text(
                      t('Retry saving this language', 'إعادة محاولة حفظ اللغة'),
                    ),
                  ),
                if (layoutPending)
                  TextButton(
                    onPressed: busy ? null : editLayout,
                    child: Text(
                      t(
                        'Resolve pending layout save',
                        'تسوية حفظ التصميم المعلّق',
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  t('Layout Template', 'قالب التصميم'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (language != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ResumeTemplateCard(
                      language: language!,
                      onInspect: () => showDialog<void>(
                        context: context,
                        builder: (dialog) => Dialog(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ResumeTemplateCard(
                                  language: language!,
                                  enlarged: true,
                                  onInspect: () => Navigator.pop(dialog),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog),
                                  child: Text(
                                    t('Close sample', 'إغلاق النموذج'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                SliceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Standard ATS typography', 'خط قياسي متوافق مع ATS'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(
                          'A4 • Single column • Fixed margins and typography. Only renderer-supported options are shown.',
                          'A4 • عمود واحد • هوامش وخط ثابتان. تظهر الخيارات المدعومة فقط.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (message != null)
                  Text(
                    message!,
                    style: TextStyle(
                      color:
                          message ==
                              t(
                                'Resume language saved.',
                                'تم حفظ لغة السيرة الذاتية.',
                              )
                          ? TokensV0.success
                          : message ==
                                t(
                                  'Saving Resume language…',
                                  'جارٍ حفظ لغة السيرة الذاتية…',
                                )
                          ? TokensV0.primary
                          : TokensV0.error,
                    ),
                  ),
                PrimaryAction(
                  label: t(
                    confirmedDraftFingerprint != null ||
                            pending ||
                            layoutPending
                        ? 'Preview saved version'
                        : 'Preview & Export',
                    confirmedDraftFingerprint != null ||
                            pending ||
                            layoutPending
                        ? 'معاينة النسخة المحفوظة'
                        : 'معاينة وتصدير',
                  ),
                  busy: busy,
                  onPressed: language == null ? null : showPreview,
                ),
                if (configurationConflict)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final client = await ref.read(
                              supabaseClientProvider.future,
                            );
                            final db = await ref.read(databaseProvider.future);
                            await db.removeSetting(
                              key(client.auth.currentUser!.id, profile!.id),
                            );
                            if (!mounted) return;
                            setState(() {
                              pending = false;
                              configurationConflict = false;
                              message = null;
                            });
                            await load();
                          },
                    child: Text(
                      t(
                        'Reload saved configuration',
                        'إعادة تحميل الإعدادات المحفوظة',
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ResumeExportPanel(
                  key: exportKey,
                  profileId: profile!.id,
                  experience: true,
                  onOperation: (id) => context.push('/resume-status/$id'),
                  canPrepare: !pending && !busy,
                  rebuildLocalDocument: () async =>
                      (await _loadLocalSnapshot()).document,
                  initialDocument: preparedDocument,
                  showDocument: (document) async {
                    if (mounted) {
                      preparedDocument = document;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ResumePreviewPage(
                            document: document,
                            ownerId: ownerId!,
                            onEditProfile: () {
                              Navigator.of(context).pop();
                              if (mounted) context.go('/career');
                            },
                            exportEnabled:
                                exportKey.currentState?.creationEnabled ==
                                    true &&
                                !pending &&
                                !layoutPending,
                            onExport: _exportReviewedDocument,
                          ),
                        ),
                      );
                    }
                  },
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: TokensV0.primary.withValues(alpha: .05),
                    border: BorderDirectional(
                      start: BorderSide(color: TokensV0.primary, width: 2),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    t(
                      'Preview is free. A successful new PDF export costs 2 Credits. Valid downloads are free for 7 days after the file is created.',
                      'المعاينة مجانية. يكلف تصدير PDF جديد ناجح رصيدين. يتاح تنزيل الملف الصالح مجانًا لمدة ٧ أيام بعد إنشائه.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}
