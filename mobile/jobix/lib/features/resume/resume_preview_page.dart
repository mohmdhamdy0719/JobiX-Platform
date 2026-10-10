import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';

/// Canonical server content, fragmented into A4 columns for inspection only.
/// It does not rewrite the document hash or expose unsupported PDF controls.
class ResumePreviewPage extends ConsumerStatefulWidget {
  const ResumePreviewPage({
    required this.document,
    required this.onExport,
    required this.exportEnabled,
    required this.ownerId,
    super.key,
  });
  final Map<String, dynamic> document;
  final Future<void> Function() onExport;
  final bool exportEnabled;
  final String ownerId;
  @override
  ConsumerState<ResumePreviewPage> createState() => _ResumePreviewPageState();
}

class _ResumePreviewPageState extends ConsumerState<ResumePreviewPage> {
  late final WebViewController controller;
  final paperScroll = ScrollController();
  int page = 0, pages = 0;
  bool busy = false, failed = false;
  bool ownerInvalidated = false;
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String arabic) => ar ? arabic : en;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      // Only app-injected pagination runs. Canonical HTML has a restrictive
      // script-denying CSP and escaped profile content; all navigation is denied.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ResumePages',
        onMessageReceived: (message) {
          final count = int.tryParse(message.message);
          if (mounted && !ownerInvalidated && count != null && count >= 1) {
            setState(() => pages = count);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) {
            if (!ownerInvalidated) controller.runJavaScript(paginationScript);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => failed = true);
            }
          },
        ),
      );
    controller.loadHtmlString(widget.document['html'] as String);
    ref.listenManual(
      authSessionProvider.select((s) => s.valueOrNull?.user.id),
      (previous, next) {
        if ((next != null && next != widget.ownerId) ||
            (previous != null && next == null)) {
          ownerInvalidated = true;
          if (mounted) setState(() => failed = true);
          controller
              .loadHtmlString('<html><body></body></html>')
              .catchError((_) {});
        }
      },
      fireImmediately: true,
    );
  }

  static const paginationScript = '''
  document.fonts.ready.then(function() {
    if(document.getElementById('jobix-pages')) return;
    const viewportWidth = window.innerWidth;
    const container = document.createElement('div');
    container.id = 'jobix-pages';
    while(document.body.firstChild) container.appendChild(document.body.firstChild);
    document.body.appendChild(container);
    const style = document.createElement('style');
    style.textContent = 'html{width:210mm;background:white;overflow:hidden}body{width:210mm;height:297mm;min-height:0;margin:0;padding:18mm;overflow:hidden}#jobix-pages{width:174mm;height:261mm;column-width:174mm;column-gap:36mm;column-fill:auto}p,li{orphans:3;widows:3}h1,h2,h3,article header{break-after:avoid}';
    document.head.appendChild(style);
    const stride = 210 * 96 / 25.4;
    const gap = 36 * 96 / 25.4;
    const count = Math.max(1, Math.round((container.scrollWidth + gap) / stride));
    document.documentElement.style.zoom = Math.min(1, viewportWidth / stride);
    ResumePages.postMessage(String(count));
  });
  ''';
  @override
  void dispose() {
    paperScroll.dispose();
    super.dispose();
  }

  Future<void> turn(int next) async {
    if (ownerInvalidated || next < 0 || next >= pages) return;
    final rtl =
        widget.document['language'] == 'ar' ||
        (widget.document['configuration'] as Map?)?['language'] == 'ar';
    await controller.runJavaScript(
      "document.getElementById('jobix-pages').style.transform="
      "${jsonEncode('translateX(${(rtl ? 1 : -1) * next * 210}mm)')};",
    );
    if (paperScroll.hasClients) paperScroll.jumpTo(0);
    if (mounted) setState(() => page = next);
  }

  @override
  Widget build(BuildContext context) {
    final language =
        widget.document['language'] ??
        (widget.document['configuration'] as Map?)?['language'];
    final valid = (widget.document['issues'] as List? ?? []).isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(t('Preview', 'المعاينة'))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(t('ATS Professional', 'القالب المهني ATS')),
                      ),
                      Chip(
                        label: Text(
                          language == 'ar' ? 'العربية (RTL)' : 'English (LTR)',
                        ),
                      ),
                    ],
                  ),
                  Text(
                    t(
                      'A4 • Fixed ATS typography • Your saved content',
                      'A4 • خط ثابت متوافق مع ATS • محتواك المحفوظ',
                    ),
                  ),
                  Text(
                    t(
                      'Paginated layout preview. Final PDF pagination is verified during rendering.',
                      'معاينة مقسمة لصفحات. يتم التحقق من صفحات PDF النهائية أثناء الإنشاء.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: failed
                  ? Center(
                      child: Text(
                        t(
                          'Preview unavailable. Return and retry.',
                          'المعاينة غير متاحة. ارجع وأعد المحاولة.',
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, size) => SingleChildScrollView(
                        controller: paperScroll,
                        child: SizedBox(
                          width: size.maxWidth,
                          height: size.maxWidth * 297 / 210,
                          child: WebViewWidget(controller: controller),
                        ),
                      ),
                    ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: t('Previous page', 'الصفحة السابقة'),
                  onPressed: page > 0 ? () => turn(page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  pages == 0
                      ? t('Laying out pages…', 'جارٍ تجهيز الصفحات…')
                      : t(
                          'Page ${page + 1} of $pages',
                          'صفحة ${page + 1} من $pages',
                        ),
                ),
                IconButton(
                  tooltip: t('Next page', 'الصفحة التالية'),
                  onPressed: page + 1 < pages ? () => turn(page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t(
                      'Cost: 2 Credits • Free re-downloads for 7 days',
                      'التكلفة: رصيدان • إعادة تنزيل مجانية لمدة ٧ أيام',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: busy || !valid || !widget.exportEnabled || failed
                        ? null
                        : () async {
                            setState(() => busy = true);
                            try {
                              await widget.onExport();
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text(
                      t('Export PDF — 2 Credits', 'تصدير PDF — رصيدان'),
                    ),
                  ),
                  if (!widget.exportEnabled)
                    Text(
                      t(
                        'New exports are currently disabled. No Credits will be charged.',
                        'التصدير الجديد معطّل حاليًا. لن تُخصم أرصدة.',
                      ),
                      style: const TextStyle(color: TokensV0.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  if (!valid)
                    Text(
                      t(
                        'Return to fix or explicitly hide invalid sections.',
                        'ارجع لإصلاح الأقسام غير الصالحة أو إخفائها صراحةً.',
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      t('Edit resume settings', 'تعديل إعدادات السيرة الذاتية'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
