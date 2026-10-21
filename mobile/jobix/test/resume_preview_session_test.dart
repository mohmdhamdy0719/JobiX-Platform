import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/features/core_mvp/core_api.dart';
import 'package:jobix/features/resume/resume_preview_page.dart';
import 'package:jobix/l10n/app_localizations.dart';
// The existing locked WebView platform test interface; no new dependency.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class PreviewWebPlatform extends WebViewPlatform {
  final controllers = <PreviewWebController>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = PreviewWebController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => PreviewNavigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => PreviewWebWidget(params);
}

class PreviewWebController extends PlatformWebViewController {
  PreviewWebController(super.params) : super.implementation();
  JavaScriptChannelParams? channel;
  final html = <String>[];
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> enableZoom(bool enabled) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> loadHtmlString(String value, {String? baseUrl}) async {
    html.add(value);
    if (value.contains('MARKER')) {
      scheduleMicrotask(
        () => channel!.onMessageReceived(const JavaScriptMessage(message: '1')),
      );
    }
  }

  @override
  Future<void> runJavaScript(String script) async {}
}

class PreviewNavigation extends PlatformNavigationDelegate {
  PreviewNavigation(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class PreviewWebWidget extends PlatformWebViewWidget {
  PreviewWebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.white);
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language HTML-only mismatch refreshes Preview before the next tap; repeated close clears HTML',
      (tester) async {
        final platform = PreviewWebPlatform();
        WebViewPlatform.instance = platform;
        final navigator = GlobalKey<NavigatorState>();
        final original = <String, dynamic>{
          'html': '<html>ORIGINAL_MARKER</html>',
          'language': language,
          'issues': <String>[],
          'profile_version': 1,
        };
        final refreshed = {
          ...original,
          'html': '<html>REFRESHED_MARKER</html>',
        };
        final exported = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authSessionProvider.overrideWith((_) => const Stream.empty()),
              coreSummaryProvider.overrideWith(
                (_) async => CoreSummary(
                  balance: CreditBalance(
                    finalized: 8,
                    reserved: 0,
                    available: 8,
                    version: 1,
                  ),
                  profiles: const [],
                  slots: const [],
                ),
              ),
            ],
            child: MaterialApp(
              navigatorKey: navigator,
              locale: Locale(language),
              theme: foundationTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: Text('export root')),
            ),
          ),
        );
        for (var session = 0; session < 3; session++) {
          exported.clear();
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => ResumePreviewPage(
                document: original,
                ownerId: 'synthetic',
                exportEnabled: true,
                onEditProfile: () {},
                onExport: (reviewed) async {
                  exported.add(reviewed);
                  return exported.length == 1 ? refreshed : null;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final export = find.text(
            language == 'ar' ? 'تصدير PDF' : 'Export PDF',
          );
          await tester.tap(export);
          await tester.pumpAndSettle();
          expect(exported.single['html'], original['html']);
          expect(find.byType(ResumePreviewPage), findsOneWidget);
          expect(find.byKey(const Key('review-updated-preview')), findsNothing);
          expect(platform.controllers.last.html, [
            '<html>ORIGINAL_MARKER</html>',
            '<html>REFRESHED_MARKER</html>',
          ]);
          await tester.tap(export);
          await tester.pumpAndSettle();
          expect(exported.last, refreshed);
          expect(exported.last['profile_version'], original['profile_version']);
          expect(exported.last, isNot(same(original)));
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          expect(platform.controllers.last.html, [
            original['html'],
            refreshed['html'],
            '<html><body></body></html>',
          ]);
          expect(find.text('export root'), findsOneWidget);
        }
        expect(platform.controllers, hasLength(3));
        expect(original['profile_version'], 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
