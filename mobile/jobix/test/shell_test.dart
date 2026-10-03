import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/features/boot/startup.dart';
import 'package:jobix/features/shell/foundation_page.dart';
import 'package:jobix/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    // Test-only Arabic-capable font. Never packaged in production assets.
    final loader = FontLoader('FoundationTestFont')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('test/assets/DejaVuSans.ttf').readAsBytesSync(),
          ),
        ),
      );
    await loader.load();
  });
  Future<void> pumpShell(
    WidgetTester tester,
    String locale,
    StartupState state,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProvider.overrideWith((ref) async => state),
          localeProvider.overrideWith(() => TestLocale(locale)),
          themeProvider.overrideWithValue(
            foundationTheme().copyWith(
              textTheme: foundationTheme().textTheme.apply(
                fontFamily: 'FoundationTestFont',
              ),
              primaryTextTheme: foundationTheme().primaryTextTheme.apply(
                fontFamily: 'FoundationTestFont',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          theme: foundationTheme().copyWith(
            textTheme: foundationTheme().textTheme.apply(
              fontFamily: 'FoundationTestFont',
            ),
          ),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: FoundationPage(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final locale in ['en', 'ar']) {
    testWidgets('$locale shell direction, theme, and golden', (tester) async {
      await pumpShell(tester, locale, StartupState.signedOut);
      final context = tester.element(find.byType(Scaffold));
      expect(
        Directionality.of(context),
        locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(Theme.of(context).colorScheme.primary, TokensV0.primary);
      expect(find.text('Jobix'), findsOneWidget);
      expect(find.byKey(const Key('startup-state')), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/shell_$locale.png'),
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  }
  for (final state in [
    StartupState.signedIn,
    StartupState.updateRequired,
    StartupState.failed,
  ]) {
    testWidgets('legacy Foundation state ${state.name} remains usable', (
      tester,
    ) async {
      await pumpShell(tester, 'en', state);
      expect(find.byType(Scaffold), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FoundationPage)),
      );
      expect(await container.read(startupProvider.future), state);
      if (state == StartupState.signedIn) {
        expect(find.text('Sign out'), findsOneWidget);
      } else if (state == StartupState.updateRequired) {
        expect(find.text('An app update is required.'), findsOneWidget);
        expect(find.text('Sign out'), findsNothing);
      } else {
        expect(find.text('Retry'), findsOneWidget);
      }
    });
  }
  testWidgets('mixed text paragraph direction is rendered', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('مهندس Flutter', textDirection: TextDirection.rtl),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('مهندس Flutter')).textDirection,
      TextDirection.rtl,
    );
  });
}

class TestLocale extends LocaleController {
  TestLocale(this.locale);
  final String locale;
  @override
  Future<String?> build() async => locale;
}
