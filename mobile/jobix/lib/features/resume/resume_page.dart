import 'dart:convert';
import '../../core/navigation/back_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../personal_information/profile_extras_repository.dart';
import 'resume_export_panel.dart';
import 'resume_preview_page.dart';
import 'resume_preview_snapshot.dart';
import 'resume_experience_widgets.dart';
import '../builder/profile_overview.dart';

/// Configuration references the Career Profile; it never copies editable data.
class ResumePage extends ConsumerStatefulWidget {
  const ResumePage({this.historicalExportId, super.key});
  final String? historicalExportId;
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
    setState(() {
      busy = true;
      message = null;
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
        'language': language,
        'template_id': 'resume_ats_${language}_v1',
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
      if (result is! Map) throw StateError('SAVE_NOT_CONFIRMED');
      await db.removeSetting(storageKey);
      await load();
      if (mounted) {
        setState(() {
          confirmedDraftFingerprint = null;
          message = t(
            'Language saved. Preview is available using the saved version.',
            'تم حفظ اللغة. يمكنك معاينة النسخة المحفوظة.',
          );
        });
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

  Future<void> showPreview() async {
    if (language == null || profile == null || busy || pending) return;
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
            'You have unsaved edits. Preview will show the last saved version only; nothing will be saved or discarded. Select Preview saved version to continue.',
            'لديك تعديلات غير محفوظة. ستعرض المعاينة آخر نسخة محفوظة فقط، ولن يتم حفظ التعديلات أو حذفها. اختر معاينة النسخة المحفوظة للمتابعة.',
          );
        });
      }
    } on ResumePreviewBlocked catch (error) {
      if (mounted) {
        setState(
          () => message = switch (error.code) {
            'SAVE_RECONCILIATION_REQUIRED' => t(
              'A previous save is still unconfirmed. Retry or resolve that request before Preview.',
              'هناك حفظ سابق لم يتم تأكيده. أعد المحاولة أو أكمل تسوية الطلب قبل المعاينة.',
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

  Future<void> _exportReviewedDocument(
    Map<String, dynamic> reviewedDocument,
  ) async {
    final panel = exportKey.currentState;
    if (panel == null) return;
    await panel.createPdf(reviewedDocument, widget.historicalExportId);
    if (panel.reviewRequired && mounted) {
      Navigator.of(context).pop();
    }
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
                    'Choose an ATS-friendly layout for your saved Career Profile.',
                    'اختر تصميمًا متوافقًا مع ATS لملفك المهني المحفوظ.',
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => context.go('/career'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    t('Edit profile content', 'تعديل محتوى الملف المهني'),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final code in ['en', 'ar'])
                      ChoiceChip(
                        label: Text(
                          code == 'en' ? 'English (LTR)' : 'العربية (RTL)',
                        ),
                        selected: language == code,
                        onSelected: busy || pending
                            ? null
                            : (_) => setState(() {
                                language = code;
                                confirmedDraftFingerprint = null;
                              }),
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
                if (languageDirty)
                  Text(
                    t(
                      'This language choice is not saved. Preview uses the saved language until you choose Save selected language.',
                      'اختيار اللغة غير محفوظ. ستستخدم المعاينة اللغة المحفوظة حتى تختار حفظ اللغة المحددة.',
                    ),
                  ),
                if (languageDirty)
                  TextButton(
                    onPressed: busy || pending ? null : saveLanguage,
                    child: Text(
                      t('Save selected language', 'حفظ اللغة المحددة'),
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
                  Text(message!, style: const TextStyle(color: TokensV0.error)),
                PrimaryAction(
                  label: t(
                    pending
                        ? 'Retry saved request'
                        : (confirmedDraftFingerprint != null || languageDirty
                              ? 'Preview saved version'
                              : 'Preview & Export'),
                    pending
                        ? 'إعادة محاولة الطلب المحفوظ'
                        : (confirmedDraftFingerprint != null || languageDirty
                              ? 'معاينة النسخة المحفوظة'
                              : 'معاينة وتصدير'),
                  ),
                  busy: busy,
                  onPressed: language == null
                      ? null
                      : (pending ? saveLanguage : showPreview),
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
                  historicalExportId: widget.historicalExportId,
                  onOperation: (id) => context.go('/resume-status/$id'),
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
                                exportKey.currentState?.creationEnabled == true,
                            onExport: () => _exportReviewedDocument(document),
                          ),
                        ),
                      );
                    }
                  },
                ),
                Text(
                  t(
                    'Preview is free. A new successful PDF export will cost 2 Credits once the export service is available.',
                    'المعاينة مجانية. سيكلف كل تصدير PDF جديد وناجح رصيدين عند توفر خدمة التصدير.',
                  ),
                ),
              ],
            ),
    );
  }
}
