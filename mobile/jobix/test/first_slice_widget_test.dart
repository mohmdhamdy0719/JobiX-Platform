import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/app.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/core/navigation/router.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/features/auth/auth_controller.dart';
import 'package:jobix/features/boot/startup.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/onboarding/research_context.dart';
import 'support/slice_fakes.dart';

final testStartupProvider = StateProvider<StartupState>(
  (ref) => StartupState.signedOut,
);

void main() {
  configureSqlCipher(
    testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
  );
  late Directory directory;
  late AppDatabase database;
  late FakeProfileApi api;
  late DraftRepository repository;
  late FakeAuthApi auth;
  ProviderContainer? container;
  setUpAll(() async {
    final packages =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map;
    final flutter = (packages['packages'] as List).cast<Map>().firstWhere(
      (p) => p['name'] == 'flutter',
    );
    final sdk = Directory.fromUri(
      Uri.parse(flutter['rootUri'] as String),
    ).parent.parent.path;
    for (final entry in {
      'Inter': 'assets/fonts/Inter.ttf',
      'FoundationTestFont': 'test/assets/DejaVuSans.ttf',
      'MaterialIcons':
          '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(File(entry.value).readAsBytesSync()),
          ),
        );
      await loader.load();
    }
  });
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('jobix-widget-');
    database = AppDatabase(
      encryptedDatabase(File('${directory.path}/db'), generateDatabaseKey()),
    );
    api = FakeProfileApi();
    repository = DraftRepository(database, api, 'user-one', () => true);
    auth = FakeAuthApi();
    await database.setting(
      'locale',
    ); // Open the actual encrypted engine outside the widget flow.
  });
  tearDown(() async {
    container?.dispose();
    container = null;
    await database.close();
    directory.deleteSync(recursive: true);
  });
  Future<void> pump(
    WidgetTester tester, {
    StartupState state = StartupState.signedOut,
    ResearchProgress progress = const ResearchProgress(),
    String locale = 'en',
    bool newEntry = false,
    bool mixedFont = false,
    Size size = const Size(402, 874),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await database.saveOnboarding(progress.encode());
    await database.setSetting('locale', locale);
    final theme = foundationTheme();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((_) async => database),
        startupProvider.overrideWith(
          (ref) async => ref.watch(testStartupProvider),
        ),
        authSessionProvider.overrideWith((_) => Stream.value(testSession())),
        authLinkServiceProvider.overrideWith((_) async {}),
        authApiProvider.overrideWith((_) async => auth),
        draftRepositoryProvider.overrideWith((_) async => repository),
        firstEntryProvider.overrideWith((_) async => newEntry),
        contextMergeProvider.overrideWith((_) async {}),
        themeProvider.overrideWithValue(
          theme.copyWith(
            textTheme: theme.textTheme.apply(
              fontFamily: locale == 'ar' || mixedFont
                  ? 'FoundationTestFont'
                  : 'Inter',
            ),
          ),
        ),
      ],
    );
    container!.read(testStartupProvider.notifier).state = state;
    auth.onSignedIn = () =>
        container!.read(testStartupProvider.notifier).state =
            StartupState.signedIn;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container!, child: const JobixApp()),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () async => precacheImage(
        const AssetImage('assets/brand/logo.png'),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  const complete = ResearchProgress(
    onboardingDone: true,
    stage: 'student',
    goal: 'unsure',
    location: 'remote',
    help: ['cv'],
  );
  Future<void> route(WidgetTester tester, String path) async {
    container!.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'exactly three onboarding screens, then research; skip also reaches Q1',
    (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('onboarding-title-0')), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/slice_onboarding_en.png'),
      );
      for (var next = 1; next <= 2; next++) {
        await tester.tap(find.byKey(const Key('onboarding-continue')));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('onboarding-title-$next')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('onboarding-continue')));
      await tester.pumpAndSettle();
      expect(find.text('1/4'), findsOneWidget);
    },
  );
  testWidgets(
    'skip persists introduction completion but never skips ordered research',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('skip-onboarding')));
      await tester.pumpAndSettle();
      expect(find.text('1/4'), findsOneWidget);
      expect(
        ResearchProgress.decode(await database.onboarding()).onboardingDone,
        true,
      );
      expect(
        container!.read(routerProvider).routeInformationProvider.value.uri.path,
        '/research',
      );
    },
  );
  testWidgets(
    'four questions retain selections; Q4 maximum remains three; auth follows',
    (tester) async {
      await pump(
        tester,
        progress: const ResearchProgress(onboardingDone: true),
        locale: 'ar',
      );
      expect(
        Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/slice_research_ar.png'),
      );
      for (final value in ['student', 'unsure', 'remote']) {
        await tester.tap(find.byKey(Key('research-option-$value')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('research-continue')));
        await tester.pumpAndSettle();
      }
      for (final value in ['cv', 'skills', 'online', 'paths']) {
        final choice = find.byKey(Key('research-option-$value'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
      }
      expect(
        ResearchProgress.decode(await database.onboarding()).help.length,
        3,
      );
      await tester.tap(find.byKey(const Key('research-continue')));
      await tester.pumpAndSettle();
      expect(
        container!.read(routerProvider).routeInformationProvider.value.uri.path,
        '/auth',
      );
    },
  );
  testWidgets('app language switch changes general UI and persists', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('app-language')));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
    expect(await database.setting('locale'), 'ar');
  });
  testWidgets('email signup waits for confirmation; login cannot bypass it', (
    tester,
  ) async {
    await pump(tester, progress: complete);
    await route(tester, '/auth?mode=signup');
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'test password',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your email'), findsWidgets);
    expect(auth.calls, ['signup']);
    expect(await database.setting('registration_user'), isNull);
    await route(tester, '/auth?mode=login');
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'test password',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('could not complete authentication'),
      findsOneWidget,
    );
    expect(
      container!.read(routerProvider).routeInformationProvider.value.uri.path,
      '/auth',
    );
  });
  testWidgets(
    'Google and forgot-password boundaries use real controller calls, with explicit failures',
    (tester) async {
      await pump(tester, progress: complete);
      await route(tester, '/auth?mode=login');
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/slice_auth_en.png'),
      );
      auth.googleOpened = false;
      await tester.tap(find.byKey(const Key('auth-google')));
      await tester.pumpAndSettle();
      expect(auth.calls, ['google']);
      expect(find.textContaining('could not open'), findsOneWidget);
      await route(tester, '/forgot');
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'test@example.com',
      );
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(auth.calls, ['google', 'reset']);
      expect(find.textContaining('If an account exists'), findsOneWidget);
    },
  );
  testWidgets(
    'returning user opens Home then Career resumes the unfinished local Personal step',
    (tester) async {
      await repository.retain(
        const PersonalDraft(
          profileId: 'profile-one',
          baseVersion: 1,
          personal: {'full_name': 'Unfinished'},
          resumeLanguage: 'en',
        ),
      );
      await pump(tester, state: StartupState.signedIn);
      expect(find.byKey(const Key('continue-career')), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/slice_home_en.png'),
      );
      await tester.tap(find.byKey(const Key('continue-career')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('personal-full_name')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('personal-full_name')))
            .controller!
            .text,
        'Unfinished',
      );
    },
  );
  testWidgets(
    'new registration enters Personal directly with no invented Resume language',
    (tester) async {
      await pump(tester, state: StartupState.signedIn, newEntry: true);
      expect(find.byKey(const Key('resume-en')), findsOneWidget);
      expect(find.byKey(const Key('personal-full_name')), findsNothing);
      expect(find.textContaining('Choose a Resume Language'), findsOneWidget);
    },
  );
  testWidgets(
    'sign-out warns about local work and can be cancelled without data loss',
    (tester) async {
      await repository.retain(
        const PersonalDraft(
          profileId: 'profile-one',
          baseVersion: 1,
          personal: {'full_name': 'Local work'},
        ),
      );
      await pump(tester, state: StartupState.signedIn);
      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      expect(find.textContaining('removes unsaved local work'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('continue-career')), findsOneWidget);
      expect(
        (await repository.draft(api.server))!.personal['full_name'],
        'Local work',
      );
      expect(auth.calls, isEmpty);
    },
  );
  testWidgets(
    'App English / Resume Arabic changes only labels and field direction, not content',
    (tester) async {
      await pump(
        tester,
        state: StartupState.signedIn,
        newEntry: true,
        mixedFont: true,
      );
      await tester.tap(find.byKey(const Key('resume-ar')));
      await tester.pumpAndSettle();
      expect(find.text('Full Name'), findsNothing);
      expect(find.text('الاسم الكامل'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.ltr,
      );
      final field = find.byKey(const Key('personal-full_name'));
      await tester.enterText(field, 'مهندس Flutter');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .textDirection,
        TextDirection.rtl,
      );
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/slice_personal_mixed.png'),
      );
      await tester.tap(find.byKey(const Key('resume-en')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        'مهندس Flutter',
      );
      expect(find.text('Full Name'), findsOneWidget);
      expect(await database.setting('locale'), 'en');
    },
  );
  testWidgets(
    'Save & Continue Later allows incomplete content, and Discard never deletes saved data',
    (tester) async {
      await pump(tester, state: StartupState.signedIn, newEntry: true);
      await tester.tap(find.byKey(const Key('resume-en')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('personal-full_name')),
        'Local only',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leave-personal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-later')));
      await tester.pumpAndSettle();
      expect(
        container!.read(routerProvider).routeInformationProvider.value.uri.path,
        '/home',
      );
      expect(
        (await repository.draft(api.server))!.personal['full_name'],
        'Local only',
      );
      await tester.tap(find.byKey(const Key('continue-career')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-personal')));
      await tester.pumpAndSettle();
      expect(api.server.personal['full_name'], 'Local only');
      await tester.enterText(
        find.byKey(const Key('personal-full_name')),
        'Discard this',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leave-personal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discard-draft')));
      await tester.pumpAndSettle();
      expect(await repository.draft(api.server), isNull);
      expect(api.server.personal['full_name'], 'Local only');
    },
  );
  testWidgets(
    'optional manual city remains custom and suggests only previously saved user values',
    (tester) async {
      await database.setSetting('cities_user-one', 'My custom city');
      await pump(tester, state: StartupState.signedIn, newEntry: true);
      await tester.tap(find.byKey(const Key('resume-en')));
      await tester.pumpAndSettle();
      final city = find.byKey(const Key('personal-city'));
      await tester.ensureVisible(city);
      await tester.enterText(city, 'My custom');
      await tester.pumpAndSettle();
      expect(find.text('My custom city'), findsOneWidget);
      await tester.tap(find.text('My custom city'));
      await tester.pumpAndSettle();
      expect(
        (await repository.draft(api.server))!.personal['city'],
        'My custom city',
      );
    },
  );
  testWidgets(
    'small phone and large text do not overflow first-slice navigation',
    (tester) async {
      await pump(tester, size: const Size(320, 568), locale: 'ar');
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    },
  );
}
