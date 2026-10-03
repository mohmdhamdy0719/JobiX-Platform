import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/features/boot/startup.dart';
import 'package:jobix/features/shell/foundation_page.dart';
import 'package:jobix/l10n/app_localizations.dart';
import 'support/production_fonts.dart';

void main() {
  setUpAll(loadProductionFonts);
  Future<void> pumpShell(
    WidgetTester tester,
    String locale,
    StartupState state, {
    StartupFailureStage? failureStage,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProvider.overrideWith((ref) async {
            if (failureStage != null) throw StartupFailure(failureStage);
            return state;
          }),
          localeProvider.overrideWith(() => TestLocale(locale)),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          theme: foundationTheme(languageCode: locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: FoundationPage(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () async => precacheImage(
        const AssetImage('assets/brand/logo_dark.png'),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.pump();
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
  for (final locale in ['en', 'ar']) {
    testWidgets('$locale redesigned guarded startup captures', (tester) async {
      for (final state in [
        StartupState.boot,
        StartupState.failed,
        StartupState.updateRequired,
      ]) {
        await pumpShell(
          tester,
          locale,
          state,
          failureStage: state == StartupState.failed
              ? StartupFailureStage.appPolicy
              : null,
        );
        await tester.runAsync(
          () async => precacheImage(
            const AssetImage('assets/brand/logo.png'),
            tester.element(find.byType(MaterialApp)),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/redesign_startup_${state.name}_$locale.png',
          ),
        );
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
