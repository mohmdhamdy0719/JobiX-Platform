import 'dart:convert';
import '../../core/navigation/back_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import 'resume_render.dart';
import 'resume_export_panel.dart';

/// Configuration references the Career Profile; it never copies editable data.
class ResumePage extends ConsumerStatefulWidget {
  const ResumePage({super.key});
  @override
  ConsumerState<ResumePage> createState() => _ResumePageState();
}

class _ResumePageState extends ConsumerState<ResumePage> {
  CareerProfile? profile;
  String? language;
  int version = 0;
  bool busy = false, failed = false, saved = false, pending = false;
  WebViewController? preview;
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
      final data = await client
          .rpc('read_resume_configuration', params: {'requested_profile': p.id})
          .timeout(const Duration(seconds: 15));
      final db = await ref.read(databaseProvider.future);
      final raw = await db.setting(key(client.auth.currentUser!.id, p.id));
      if (!mounted) return;
      profile = p;
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
      final fresh = await (await ref.read(
        draftRepositoryProvider.future,
      )).load(freshOnly: true);
      final extras = await client.rpc(
        'read_profile_extras',
        params: {'requested_profile': fresh.id},
      );
      final latin = await rootBundle.load('assets/fonts/Inter.ttf');
      final arabic = await rootBundle.load(
        'assets/fonts/IBMPlexSansArabic-Regular.ttf',
      );
      final html = ResumeRender.html(
        profile: fresh,
        language: language!,
        latinFontBase64: base64Encode(
          latin.buffer.asUint8List(latin.offsetInBytes, latin.lengthInBytes),
        ),
        arabicFontBase64: base64Encode(
          arabic.buffer.asUint8List(arabic.offsetInBytes, arabic.lengthInBytes),
        ),
        additionalLinks: List<Map<String, dynamic>>.from(
          (extras as Map)['links'] as List,
        ),
      );
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) => request.url == 'about:blank'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
          ),
        );
      await controller.loadHtmlString(html);
      if (mounted) {
        setState(() {
          preview = controller;
          profile = fresh;
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
        if (preview != null) {
          setState(() => preview = null);
        } else {
          context.go('/career');
        }
      },
      child: frame(context),
    );
  }

  Widget frame(BuildContext context) {
    if (preview != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(t('Resume Preview', 'معاينة السيرة الذاتية')),
          leading: IconButton(
            icon: const BackButtonIcon(),
            onPressed: () => requestJobixBack(context),
          ),
        ),
        body: SafeArea(child: WebViewWidget(controller: preview!)),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t(
                'Draft A4 preview • selectable text • Export uses a separately confirmed online document.',
                'معاينة مسودة A4 • نص قابل للتحديد • التصدير يستخدم مستندًا متصلًا مؤكدًا بشكل منفصل.',
              ),
            ),
          ),
        ),
      );
    }
    return SliceScaffold(
      title: t('Build your resume', 'إنشاء سيرتك الذاتية'),
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
                    'Uses your saved Career Profile. Changing language or template never creates a new profile or translates your content.',
                    'تستخدم ملفك المهني المحفوظ. تغيير اللغة أو القالب لا ينشئ ملفًا جديدًا ولا يترجم المحتوى.',
                  ),
                ),
                const SizedBox(height: 20),
                for (final code in ['en', 'ar'])
                  RadioListTile<String>(
                    value: code,
                    groupValue: language,
                    title: Text(
                      code == 'en'
                          ? 'English — ATS Professional'
                          : 'العربية — قالب مهني متوافق مع ATS',
                    ),
                    onChanged: busy || pending
                        ? null
                        : (value) => setState(() {
                            language = value;
                            saved = false;
                          }),
                  ),
                const SizedBox(height: 20),
                if (message != null)
                  Text(message!, style: const TextStyle(color: TokensV0.error)),
                PrimaryAction(
                  label: t(
                    pending ? 'Retry saved request' : 'Save & preview',
                    pending ? 'إعادة محاولة الطلب المحفوظ' : 'حفظ ومعاينة',
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
                  profileId: profile!.id,
                  canPrepare: saved && !pending && !busy,
                  initialDocument: preparedDocument,
                  showDocument: (document) async {
                    final controller = WebViewController()
                      ..setJavaScriptMode(JavaScriptMode.disabled)
                      ..setNavigationDelegate(
                        NavigationDelegate(
                          onNavigationRequest: (_) =>
                              NavigationDecision.prevent,
                        ),
                      );
                    await controller.loadHtmlString(document['html'] as String);
                    if (mounted) {
                      setState(() {
                        preparedDocument = document;
                        preview = controller;
                      });
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
