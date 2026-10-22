import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../core_mvp/core_api.dart';
import 'resume_preview_layout.dart';

/// The locally reviewed saved Resume, fragmented into A4 columns for inspection.
/// Export obtains a fresh server-authoritative document before any submission.
class ResumePreviewPage extends ConsumerStatefulWidget {
  const ResumePreviewPage({
    required this.document,
    required this.onExport,
    required this.exportEnabled,
    required this.ownerId,
    required this.onEditProfile,
    super.key,
  });
  final Map<String, dynamic> document;
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic>) onExport;
  final bool exportEnabled;
  final String ownerId;
  final VoidCallback onEditProfile;
  static String get paginationScript =>
      _ResumePreviewPageState.paginationScript;
  @override
  ConsumerState<ResumePreviewPage> createState() => _ResumePreviewPageState();
}

class _ResumePreviewPageState extends ConsumerState<ResumePreviewPage>
    with WidgetsBindingObserver {
  late final WebViewController controller;
  late Map<String, dynamic> reviewedDocument;
  int page = 0, pages = 0;
  bool busy = false, failed = false;
  bool ownerInvalidated = false;
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String arabic) => ar ? arabic : en;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reviewedDocument = Map<String, dynamic>.from(widget.document);
    controller = WebViewController()
      // Only app-injected pagination runs. Canonical HTML has a restrictive
      // script-denying CSP and escaped profile content; all navigation is denied.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
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
    controller.loadHtmlString(reviewedDocument['html'] as String);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(coreSummaryProvider);
    }
  }

  static const paginationScript = '''
  document.fonts.ready.then(function() {
    if(document.getElementById('jobix-pages')) return;
    const viewport = document.querySelector('meta[name="viewport"]') ||
      document.head.appendChild(document.createElement('meta'));
    viewport.name = 'viewport';
    viewport.content = 'width=device-width, initial-scale=1, user-scalable=yes';
    const container = document.createElement('div');
    container.id = 'jobix-pages';
    while(document.body.firstChild) container.appendChild(document.body.firstChild);
    document.body.appendChild(container);
    const style = document.createElement('style');
    style.textContent = 'html{width:100%;background:white;overflow-x:hidden;overflow-y:auto;margin:0;padding:0}body{box-sizing:border-box;width:210mm;height:297mm;min-height:0;margin:0;padding:18mm;overflow:hidden}#jobix-pages{width:174mm;height:261mm;column-width:174mm;column-gap:36mm;column-fill:auto}p,li{orphans:3;widows:3}h1,h2,h3,article header{break-after:avoid}h1,.personal-header,article header{break-inside:avoid;page-break-inside:avoid}li{break-inside:avoid;page-break-inside:avoid}';
    document.head.appendChild(style);
    const stride = 210 * 96 / 25.4;
    const gap = 36 * 96 / 25.4;
    const count = Math.max(1, Math.ceil((container.scrollWidth + gap - 1) / stride));
    function fit() {
      document.body.style.zoom = Math.min(1,
        document.documentElement.clientWidth / stride);
    }
    window.addEventListener('resize', fit);
    return new Promise(function(resolve) {
      requestAnimationFrame(function() {
        fit();
        ResumePages.postMessage(String(count));
        resolve();
      });
    });
  });
  ''';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ownerInvalidated = true;
    controller
        .loadHtmlString('<html><body></body></html>')
        .catchError((Object _) {});
    super.dispose();
  }

  Future<void> turn(int next) async {
    if (ownerInvalidated || next < 0 || next >= pages) return;
    final rtl =
        reviewedDocument['language'] == 'ar' ||
        (reviewedDocument['configuration'] as Map?)?['language'] == 'ar';
    await controller.runJavaScript(
      "document.getElementById('jobix-pages').style.transform="
      "${jsonEncode('translateX(${(rtl ? 1 : -1) * next * 210}mm)')};",
    );
    await controller.runJavaScript('window.scrollTo(0, 0);');
    if (mounted) setState(() => page = next);
  }

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(coreSummaryProvider);
    final availableCredits = balanceState.valueOrNull?.balance.available;
    final language =
        reviewedDocument['language'] ??
        (reviewedDocument['configuration'] as Map?)?['language'];
    final valid = (reviewedDocument['issues'] as List? ?? []).isEmpty;
    return ResumePreviewLayout(
      language: language,
      page: page,
      pages: pages,
      busy: busy,
      exportEnabled: widget.exportEnabled,
      valid: valid,
      availableCredits: availableCredits,
      notice: null,
      paper: failed
          ? Center(
              child: Text(
                t(
                  'Preview unavailable. Return and retry.',
                  'المعاينة غير متاحة. ارجع وأعد المحاولة.',
                ),
              ),
            )
          : WebViewWidget(controller: controller),
      onPrevious: page > 0 && !ownerInvalidated ? () => turn(page - 1) : null,
      onNext: page + 1 < pages && !ownerInvalidated
          ? () => turn(page + 1)
          : null,
      onEditProfile: busy || ownerInvalidated ? null : widget.onEditProfile,
      onExport:
          busy ||
              pages == 0 ||
              !valid ||
              !widget.exportEnabled ||
              failed ||
              ownerInvalidated
          ? null
          : () async {
              setState(() => busy = true);
              try {
                final replacement = await widget.onExport(reviewedDocument);
                if (replacement != null && mounted && !ownerInvalidated) {
                  setState(() {
                    reviewedDocument = Map<String, dynamic>.from(replacement);
                    page = 0;
                    pages = 0;
                  });
                  await controller.loadHtmlString(
                    reviewedDocument['html'] as String,
                  );
                  if (context.mounted && !ownerInvalidated) {
                    final copy = AppLocalizations.of(context)!;
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(copy.reviewUpdatedResume),
                        content: Text(copy.resumeChangedSincePreview),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(copy.reviewUpdatedResume),
                          ),
                        ],
                      ),
                    );
                  }
                }
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
    );
  }
}
