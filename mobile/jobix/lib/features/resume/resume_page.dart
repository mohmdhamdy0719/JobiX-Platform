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
import 'resume_export_panel.dart';
import 'resume_preview_page.dart';
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
  String? language;
  int version = 0;
  bool busy = false, failed = false, saved = false, pending = false;
  final exportKey = GlobalKey<ResumeExportPanelState>();
  String? message;
  Map<String, dynamic>? preparedDocument;
  bool configurationConflict = false;
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
      final p = await ref.read(firstProfileProvider.future);
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
        language = data['language'] as String;
        version = data['version'] as int;
        saved = true;
      } else {
        language = p.resumeLanguage;
      }
      if (raw != null) {
        final request = jsonDecode(raw) as Map;
        language = request['language'] as String;
        pending = true;
        saved = false;
      }
      setState(() => failed = false);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> showPreview() async {
    if (language == null || profile == null || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final client = await ref.read(supabaseClientProvider.future);
      final user = client.auth.currentUser!.id;
      final db = await ref.read(databaseProvider.future);
      final storageKey = key(user, profile!.id);
      var raw = await db.setting(storageKey);
      if (!saved || raw != null) {
        raw ??= jsonEncode({
          'command_key': newCommandKey(),
          'requested_profile': profile!.id,
          'expected_version': version,
          'language': language,
          'template_id': 'resume_ats_${language}_v1',
        });
        await db.setSetting(storageKey, raw);
        pending = true;
        final result = await client
            .rpc(
              'save_resume_configuration',
              params: Map<String, dynamic>.from(jsonDecode(raw) as Map),
            )
            .timeout(const Duration(seconds: 15));
        if (client.auth.currentUser?.id != user) {
          throw StateError('AUTH_REQUIRED');
        }
        version = (result as Map)['version'] as int;
        language = result['language'] as String;
        saved = true;
        pending = false;
        await db.removeSetting(storageKey);
      }
      if (mounted) setState(() {});
      await exportKey.currentState?.preparePreview();
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
            'Preview could not be loaded. Your configuration request is retained. Retry to reconcile it; no Credits were charged.',
            'تعذّر تحميل المعاينة. تم الاحتفاظ بطلب الإعدادات؛ أعد المحاولة لتأكيده. لم تُخصم أي أرصدة.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
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
                                saved = false;
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
                    pending ? 'Retry saved request' : 'Preview & Export',
                    pending ? 'إعادة محاولة الطلب المحفوظ' : 'معاينة وتصدير',
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
                  historicalExportId: widget.historicalExportId,
                  onOperation: (id) => context.go('/resume-status/$id'),
                  canPrepare: saved && !pending && !busy,
                  initialDocument: preparedDocument,
                  showDocument: (document) async {
                    if (mounted) {
                      preparedDocument = document;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ResumePreviewPage(
                            document: document,
                            ownerId: ownerId!,
                            exportEnabled:
                                exportKey.currentState?.creationEnabled == true,
                            onExport: () async =>
                                exportKey.currentState?.createPdf(),
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
