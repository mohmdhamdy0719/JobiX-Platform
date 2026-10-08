import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:jobix/app.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/core/navigation/router.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/features/auth/auth_controller.dart';
import 'package:jobix/features/auth/provider_settings.dart';
import 'package:jobix/features/boot/startup.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/core_mvp/core_api.dart';
import 'package:jobix/features/career_profile/text_section_repository.dart';
import 'package:jobix/features/onboarding/research_context.dart';
import 'package:jobix/features/career_profile/entity_repository.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:jobix/features/builder/ai_allowance.dart';
import 'support/entity_fakes.dart';
import 'support/slice_fakes.dart';
import 'support/production_fonts.dart';
import 'package:jobix/l10n/app_localizations.dart';

final testStartupProvider = StateProvider<StartupState>(
  (ref) => StartupState.signedOut,
);

void main() {
  configureSqlCipher(
    testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
  );
  late Directory directory;
  late AppDatabase database;
  late String databaseKey;
  late FakeProfileApi api;
  late DraftRepository repository;
  late FakeAuthApi auth;
  late _CoreFixture core;
  late FakeEntityServer entities;
  ProviderContainer? container;
  setUpAll(loadProductionFonts);
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('jobix-widget-');
    databaseKey = generateDatabaseKey();
    database = AppDatabase(
      encryptedDatabase(File('${directory.path}/db'), databaseKey),
    );
    api = FakeProfileApi();
    repository = DraftRepository(database, api, 'user-one', () => true);
    auth = FakeAuthApi();
    core = _CoreFixture();
    entities = FakeEntityServer(api);
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
    bool googleEnabled = true,
    bool providerFailure = false,
    Size size = const Size(402, 874),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await database.saveOnboarding(progress.encode());
    await database.setSetting('locale', locale);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((_) async => database),
        startupProvider.overrideWith(
          (ref) async => ref.watch(testStartupProvider),
        ),
        authSessionProvider.overrideWith((_) => Stream.value(testSession())),
        authLinkServiceProvider.overrideWith((_) async {}),
        authApiProvider.overrideWith((_) async => auth),
        coreApiProvider.overrideWith((_) async => core),
        authProviderSettingsProvider.overrideWith((_) async {
          if (providerFailure) {
            throw const FormatException('Test settings unavailable');
          }
          return AuthProviderSettings(googleEnabled: googleEnabled);
        }),
        draftRepositoryProvider.overrideWith((_) async => repository),
        aiAllowanceProvider.overrideWith(
          (_) async => throw StateError('Allowance unavailable'),
        ),
        textSectionRepositoryProvider.overrideWith(
          (_) async => TextSectionRepository(repository, (draft) async {
            api.server = CareerProfile(
              id: api.server.id,
              version: api.server.version + 1,
              personal: api.server.personal,
              resumeLanguage: api.server.resumeLanguage,
              summary: draft.section == 'summary'
                  ? draft.request!['text'] as String
                  : api.server.summary,
              targetRole: draft.section == 'target_role'
                  ? draft.request!['text'] as String
                  : api.server.targetRole,
              summaryState: 'NEEDS_ATTENTION',
              completeness: 0,
            );
            return api.server;
          }),
        ),
        entityRepositoryProvider.overrideWith(
          (_) async => EntityRepository(repository, entities.send),
        ),
        firstEntryProvider.overrideWith((_) async => newEntry),
        contextMergeProvider.overrideWith((_) async {}),
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
        const AssetImage('assets/brand/logo_dark.png'),
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

  void noUnsupportedContent(WidgetTester tester) {
    final text = tester.allWidgets
        .whereType<Text>()
        .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
        .join(' ')
        .toLowerCase();
    for (final forbidden in [
      'marcus vance',
      'alex harrison',
      'saudi arabia',
      'riyadh',
      'recruiter approved',
      '100% parsed',
      'ats parsing optimized',
      'ats priority',
      'deliverable',
      'official id standard',
      'executive search',
      'gulf',
      'gcc',
      '0/6 ai uses',
      'ats match',
      '94% strong',
      'ats 98%',
      'recruiter match',
      'keywords: 14/14',
      'product strategy',
      'cross-functional lead',
      'zero-hallucination',
      'quantified impact',
      '80% of screening',
      'ai panel simulation',
      'السعودية',
      'الرياض',
      'معتمد من مسؤولي التوظيف',
    ]) {
      expect(
        text,
        isNot(contains(forbidden)),
        reason: 'Unsupported rendered content: $forbidden',
      );
    }
  }

  testWidgets(
    'exactly three onboarding screens, then research; skip also reaches Q1',
    (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('onboarding-title-0')), findsOneWidget);
      noUnsupportedContent(tester);
      expect(find.text('Sign in to an existing account'), findsNothing);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/slice_onboarding_en.png'),
      );
      for (var next = 1; next <= 2; next++) {
        await tester.tap(find.byKey(const Key('onboarding-continue')));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('onboarding-title-$next')), findsOneWidget);
        noUnsupportedContent(tester);
        expect(find.text('Sign in to an existing account'), findsNothing);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/slice_onboarding_${next + 1}_en.png'),
        );
      }
      await tester.tap(find.byKey(const Key('onboarding-continue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('research-step')), findsOneWidget);
    },
  );
  for (final locale in ['en', 'ar']) {
    testWidgets('text sections native captures and saved drafts $locale', (
      tester,
    ) async {
      await pump(
        tester,
        state: StartupState.signedIn,
        locale: locale,
        size: const Size(402, 1100),
      );
      for (final section in ['summary', 'target_role']) {
        container!
            .read(routerProvider)
            .go(
              section == 'summary' ? '/career/summary' : '/career/target-role',
            );
        await tester.pumpAndSettle();
        expect(find.byKey(Key('editor-$section')), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).first)),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/text_${section}_$locale.png'),
        );
        await tester.enterText(
          find.byKey(Key('editor-$section')),
          locale == 'ar' ? 'مسودة' : 'draft',
        );
        await tester.pumpAndSettle();
        final retained = await database.sectionDraft(
          repository.user,
          api.server.id,
          section,
        );
        expect(
          TextSectionDraft.decode(retained!).text,
          locale == 'ar' ? 'مسودة' : 'draft',
        );
        await tester.ensureVisible(find.byKey(Key('save-$section')));
        await tester.tap(find.byKey(Key('save-$section')));
        await tester.pumpAndSettle();
        expect(
          await database.sectionDraft(repository.user, api.server.id, section),
          isNull,
        );
        expect(tester.takeException(), isNull);
      }
    });
    testWidgets('core shell native production-font captures $locale', (
      tester,
    ) async {
      await pump(tester, state: StartupState.signedIn, locale: locale);
      for (final page in ['home', 'career', 'settings', 'credits']) {
        container!.read(routerProvider).go('/$page');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).first)),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        noUnsupportedContent(tester);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/core_${page}_$locale.png'),
        );
      }
    });
    testWidgets('core shell narrow scaled layouts $locale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        state: StartupState.signedIn,
        locale: locale,
        size: const Size(320, 740),
      );
      for (final page in ['home', 'career', 'settings', 'credits']) {
        container!.read(routerProvider).go('/$page');
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$locale $page overflow',
        );
      }
    });
  }
  testWidgets('main tabs are guarded and return to the current profile', (
    tester,
  ) async {
    await pump(tester, state: StartupState.signedIn);
    for (final destination in ['career', 'settings', 'home']) {
      await tester.tap(find.byKey(Key('nav-$destination')));
      await tester.pumpAndSettle();
      expect(
        container!.read(routerProvider).routeInformationProvider.value.uri.path,
        '/$destination',
      );
    }
    expect(find.byKey(const Key('continue-career')), findsOneWidget);
  });
  testWidgets('failed authoritative balance never becomes a zero fallback', (
    tester,
  ) async {
    core.bootstrapFails = true;
    await pump(tester, state: StartupState.signedIn);
    final copy = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(copy.balanceUnavailable), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('5'), findsNothing);
    core.bootstrapFails = false;
    await tester.tap(find.byTooltip(copy.retry).first);
    await tester.pumpAndSettle();
    expect(find.text(copy.creditsCount(5)), findsOneWidget);
  });
  testWidgets('credit history failure is not a fabricated empty ledger', (
    tester,
  ) async {
    core.historyFails = true;
    await pump(tester, state: StartupState.signedIn);
    container!.read(routerProvider).go('/credits');
    await tester.pumpAndSettle();
    final copy = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(copy.creditHistoryLoadFailed), findsOneWidget);
    expect(find.text(copy.creditHistoryEmpty), findsNothing);
    core.historyFails = false;
    await tester.tap(find.text(copy.retry).first);
    await tester.pumpAndSettle();
    expect(find.text(copy.creditHistoryEmpty), findsOneWidget);
    expect(core.historyCalls, 2);
  });
  testWidgets('Settings sign-out cancellation preserves the encrypted draft', (
    tester,
  ) async {
    await repository.retain(
      const PersonalDraft(
        profileId: 'profile-one',
        baseVersion: 1,
        personal: {'full_name': 'Local work'},
      ),
    );
    await pump(tester, state: StartupState.signedIn);
    container!.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-sign-out')),
      250,
    );
    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(
      (await repository.draft(api.server))!.personal['full_name'],
      'Local work',
    );
    expect(
      container!.read(routerProvider).routeInformationProvider.value.uri.path,
      '/settings',
    );
  });
  testWidgets(
    'skip persists introduction completion but never skips ordered research',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('skip-onboarding')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('research-step')), findsOneWidget);
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
  for (final locale in ['en', 'ar']) {
    for (final size in [const Size(320, 568), const Size(800, 1280)]) {
      testWidgets(
        '$locale illustrated onboarding stays usable at $size with enlarged text',
        (tester) async {
          await pump(tester, locale: locale, size: size);
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          for (var page = 0; page < 3; page++) {
            final title = find.byKey(Key('onboarding-title-$page'));
            expect(title, findsOneWidget);
            await tester.ensureVisible(title);
            await tester.pumpAndSettle();
            noUnsupportedContent(tester);
            expect(tester.takeException(), isNull);
            final next = find.byKey(const Key('onboarding-continue'));
            final bounds = tester.getRect(next);
            expect(bounds.bottom, lessThanOrEqualTo(size.height));
            expect(bounds.height, greaterThanOrEqualTo(48));
            expect(find.byKey(const Key('skip-onboarding')), findsOneWidget);
            await tester.tap(next);
            await tester.pumpAndSettle();
          }
          expect(find.byKey(const Key('research-step')), findsOneWidget);
          expect(
            container!
                .read(routerProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            '/research',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
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
  testWidgets(
    'first-time login URLs stay gated until Q1-Q4; approved research renders',
    (tester) async {
      await pump(tester);
      for (final path in ['/auth?mode=login', '/forgot', '/confirm']) {
        await route(tester, path);
        expect(
          container!
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/onboarding',
        );
      }
      await tester.tap(find.byKey(const Key('skip-onboarding')));
      await tester.pumpAndSettle();
      const answers = ['student', 'unsure', 'remote', 'cv'];
      for (var question = 0; question < 4; question++) {
        for (final path in [
          '/auth?mode=login',
          '/auth?mode=signup',
          '/forgot',
        ]) {
          await route(tester, path);
          expect(
            container!
                .read(routerProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            '/research',
          );
          expect(
            tester.widget<Text>(find.byKey(const Key('research-step'))).data,
            AppLocalizations.of(
              tester.element(find.byType(Scaffold)),
            )!.researchStep(question + 1),
          );
        }
        noUnsupportedContent(tester);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/slice_research_q${question + 1}_en.png'),
        );
        final option = find.byKey(Key('research-option-${answers[question]}'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('research-continue')));
        await tester.pumpAndSettle();
      }
      expect(
        container!.read(routerProvider).routeInformationProvider.value.uri.path,
        '/auth',
      );
      expect(auth.calls, isEmpty);
    },
  );
  testWidgets(
    'empty Profile and region suggestion never send fictional or unaccepted personal values',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale(
        'en',
        'EG',
      );
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      await pump(tester, state: StartupState.signedIn, newEntry: true);
      expect(api.server.personal, isEmpty);
      expect(api.server.resumeLanguage, isNull);
      expect(api.requests, isEmpty);
      noUnsupportedContent(tester);
      await tester.tap(find.byKey(const Key('resume-en')));
      await tester.pumpAndSettle();
      for (final field in personalFields.where((f) => f != 'city')) {
        expect(
          tester
              .widget<TextField>(
                field == 'country'
                    ? find.byKey(Key('personal-$field'))
                    : find.descendant(
                        of: find.byKey(Key('personal-$field')),
                        matching: find.byType(TextField),
                      ),
              )
              .controller!
              .text,
          isEmpty,
        );
      }
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('personal-city')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.byKey(const Key('use-egypt')), findsOneWidget);
      noUnsupportedContent(tester);
      // Tall test render exposes all supplied sections; it is not a device capture.
      tester.view.physicalSize = const Size(402, 1700);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/slice_personal_empty_en.png'),
      );
      expect(api.server.personal, isEmpty);
      expect(api.requests, isEmpty);
      await tester.tap(find.byKey(const Key('builder-continue')));
      await tester.pumpAndSettle();
      expect(api.server.resumeLanguage, 'en');
      expect(api.server.personal.values.every((v) => v.isEmpty), true);
      expect(api.requests.single.frozen!['personal'], isEmpty);
      // Continue moves on only after the acknowledged save.
      expect(
        container!.read(routerProvider).routeInformationProvider.value.uri.path,
        '/builder/2',
      );
      container!.read(routerProvider).go('/builder/1');
      await tester.pumpAndSettle();
      // Accepting a suggestion remains local until a separate explicit Save.
      await tester.tap(find.byKey(const Key('use-egypt')));
      await tester.pumpAndSettle();
      expect(
        (await repository.draft(api.server))!.personal['country'],
        'Egypt',
      );
      expect(api.server.personal['country'], '');
      expect(api.requests.length, 1);
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
    expect(await database.setting('registration_user'), 'new-user');
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
    // Unconfirmed login stays signed out and lands on the confirm step.
    expect(
      container!.read(routerProvider).routeInformationProvider.value.uri.path,
      '/confirm',
    );
    expect(auth.calls, ['signup', 'signin']);
    await tester.tap(find.byKey(const Key('resend-confirmation')));
    await tester.pumpAndSettle();
    expect(auth.calls.last, 'resend');
    final copy = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(copy.confirmationResent), findsOneWidget);
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
      await pump(tester, state: StartupState.signedIn, newEntry: true);
      await tester.tap(find.byKey(const Key('resume-ar')));
      await tester.pumpAndSettle();
      expect(find.text('Full Name'), findsNothing);
      expect(find.text('الاسم الكامل'), findsOneWidget);
      // App-language chrome (Step 1 of the builder) stays English.
      expect(find.text('Continue'), findsOneWidget);
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
      // Step 1 has no App Language control; it lives in Settings.
      expect(find.byKey(const Key('app-language')), findsNothing);
      noUnsupportedContent(tester);
      await container!.read(localeProvider.notifier).setOverride('ar');
      await tester.pumpAndSettle();
      expect(await database.setting('locale'), 'ar');
      expect((await repository.draft(api.server))!.resumeLanguage, 'en');
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        'مهندس Flutter',
      );
      expect(find.text('Full Name'), findsOneWidget);
      final ar = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      expect(find.text(ar.continueAction), findsOneWidget);
      noUnsupportedContent(tester);
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
      expect(find.byKey(const Key('builder-back')), findsNothing);
      // Native system Back still offers safe draft retention; Step 1 has no
      // on-screen Back affordance.
      await tester.binding.handlePopRoute();
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
      // Home resumes the first unfinished builder step with the local draft.
      await tester.tap(find.byKey(const Key('continue-career')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('builder-continue')));
      await tester.pumpAndSettle();
      expect(api.server.personal['full_name'], 'Local only');
      expect(
        container!.read(routerProvider).routeInformationProvider.value.uri.path,
        '/builder/2',
      );
      container!.read(routerProvider).go('/career/personal');
      await tester.pumpAndSettle();
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
  for (final locale in ['en', 'ar']) {
    testWidgets(
      '$locale signup/login, validation, keyboard and scaled layout',
      (tester) async {
        await pump(tester, progress: complete, locale: locale);
        await route(tester, '/auth?mode=signup');
        final copy = AppLocalizations.of(
          tester.element(find.byType(Scaffold)),
        )!;
        expect(find.text(copy.forgotPassword), findsNothing);
        expect(
          Theme.of(
            tester.element(find.byType(Scaffold)),
          ).textTheme.bodyMedium!.fontFamily,
          locale == 'ar' ? 'IBM Plex Sans Arabic' : 'Inter',
        );
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('auth-email')))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('auth-password')))
              .controller!
              .text,
          isEmpty,
        );
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/redesign_signup_$locale.png'),
        );
        await tester.tap(find.byKey(const Key('auth-submit')));
        await tester.pumpAndSettle();
        expect(find.text(copy.invalidEmail), findsOneWidget);
        expect(find.text(copy.passwordRequired), findsOneWidget);
        expect(auth.calls, isEmpty);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/redesign_signup_validation_$locale.png'),
        );
        await route(tester, '/auth?mode=login');
        expect(find.text(copy.forgotPassword), findsOneWidget);
        expect(find.byKey(const Key('app-language')), findsNothing);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/redesign_login_$locale.png'),
        );
        await tester.enterText(
          find.byKey(const Key('auth-email')),
          'engineer@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('auth-password')),
          'example secret',
        );
        final editable = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('auth-email')),
            matching: find.byType(EditableText),
          ),
        );
        expect(editable.textDirection, TextDirection.ltr);
        // Simulated keyboard inset, not a Samsung IME/device capture.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('auth-submit')));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const Key('auth-submit'))).bottom,
          lessThan(575),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/redesign_login_keyboard_$locale.png'),
        );
        tester.view.resetViewInsets();
        tester.testTextInput.hide();
        FocusManager.instance.primaryFocus?.unfocus();
        await route(tester, '/auth?mode=signup');
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('auth-email')))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('auth-password')))
              .controller!
              .text,
          isEmpty,
        );
        tester.view.physicalSize = const Size(320, 568);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('auth-submit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetViewInsets);
      },
    );
    testWidgets(
      '$locale onboarding and research captures use production fonts',
      (tester) async {
        await pump(tester, locale: locale);
        for (var page = 0; page < 3; page++) {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/redesign_intro_${page + 1}_$locale.png'),
          );
          await tester.tap(find.byKey(const Key('onboarding-continue')));
          await tester.pumpAndSettle();
        }
        for (var question = 0; question < 4; question++) {
          expect(find.byKey(const Key('app-language')), findsNothing);
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'goldens/redesign_research_${question + 1}_$locale.png',
            ),
          );
          final value = ['student', 'unsure', 'remote', 'cv'][question];
          final tile = find.byKey(Key('research-option-$value'));
          await tester.ensureVisible(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
          await tester.tap(find.byKey(const Key('research-continue')));
          await tester.pumpAndSettle();
        }
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/redesign_auth_gateway_$locale.png'),
        );
      },
    );
  }
  testWidgets('disabled Google is hidden without preventing email login', (
    tester,
  ) async {
    await pump(tester, progress: complete, googleEnabled: false);
    await route(tester, '/auth?mode=login');
    expect(find.byKey(const Key('auth-google')), findsNothing);
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
  });
  testWidgets(
    'provider discovery failure is explicit and does not fabricate Google',
    (tester) async {
      await pump(tester, progress: complete, providerFailure: true);
      await route(tester, '/auth?mode=login');
      expect(find.byKey(const Key('auth-google')), findsNothing);
      expect(find.byKey(const Key('auth-provider-retry')), findsOneWidget);
      expect(find.textContaining('could not be verified'), findsOneWidget);
    },
  );
  testWidgets('stored auth errors relocalize without altering typed text', (
    tester,
  ) async {
    await pump(tester, progress: complete);
    auth.signInError = const AuthException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );
    await route(tester, '/auth?mode=login');
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'test@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'example');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    final en = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(en.authInvalidCredentials), findsOneWidget);
    await container!.read(localeProvider.notifier).setOverride('ar');
    await tester.pumpAndSettle();
    final copy = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(copy.authInvalidCredentials), findsOneWidget);
    expect(find.text(en.authInvalidCredentials), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('auth-email')))
          .controller!
          .text,
      'test@example.com',
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/redesign_auth_error_ar.png'),
    );
  });
  for (final locale in ['en', 'ar']) {
    for (final size in [const Size(320, 568), const Size(800, 1280)]) {
      testWidgets(
        '$locale ordered research remains reachable at $size with 1.6 text scale',
        (tester) async {
          await pump(
            tester,
            locale: locale,
            size: size,
            progress: const ResearchProgress(onboardingDone: true),
          );
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          await tester.pumpAndSettle();
          for (var question = 0; question < 4; question++) {
            final last = find.byKey(
              Key('research-option-${researchOptions[question].last}'),
            );
            await tester.ensureVisible(last);
            await tester.pumpAndSettle();
            expect(tester.getSize(last).height, greaterThanOrEqualTo(48));
            expect(tester.takeException(), isNull);
            final choice = find.byKey(
              Key(
                'research-option-${['student', 'unsure', 'remote', 'cv'][question]}',
              ),
            );
            await tester.ensureVisible(choice);
            await tester.tap(choice);
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('research-continue')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(
            container!
                .read(routerProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            '/auth',
          );
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        },
      );
    }
  }

  // ---- Guided builder (steps 3-6), editors and Review ----
  const experienceId = '0b8f3c1e-5d2a-4c7e-9f10-2a3b4c5d6e7f';
  const seededExperience = ProfileItem(
    id: experienceId,
    section: EntitySection.experience,
    version: 1,
    complete: true,
    values: {
      'job_title': 'Flutter Developer',
      'company': 'First Co',
      'start_month': '2023-01',
      'is_current': true,
      'description': 'Built and shipped the mobile app end to end.',
    },
  );
  void seedProfile() {
    api.server = const CareerProfile(
      id: 'profile-one',
      version: 1,
      resumeLanguage: 'en',
      completeness: 45,
      items: {
        EntitySection.experience: [seededExperience],
        EntitySection.skill: [
          ProfileItem(
            id: '1c2d3e4f-0000-4000-8000-000000000001',
            section: EntitySection.skill,
            version: 1,
            complete: true,
            values: {'name': 'Dart'},
          ),
        ],
        EntitySection.language: [
          ProfileItem(
            id: '1c2d3e4f-0000-4000-8000-000000000002',
            section: EntitySection.language,
            version: 1,
            complete: true,
            values: {'name': 'Arabic', 'proficiency': 'NATIVE'},
          ),
        ],
      },
    );
  }

  String currentPath() =>
      container!.read(routerProvider).routeInformationProvider.value.uri.path;

  testWidgets('existing language edit owns its controller through dismissal', (
    tester,
  ) async {
    seedProfile();
    await pump(tester, state: StartupState.signedIn, size: const Size(402, 1100));
    await route(tester, '/builder/5');
    const id = '1c2d3e4f-0000-4000-8000-000000000002';
    final menu = find.byKey(const Key('menu-language-$id'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final copy = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    await tester.tap(find.text(copy.editAction).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'opening an existing record');
    await tester.tap(find.byKey(const Key('language-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.profFluent).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.saveAction).last);
    // Check both the popped result and reverse-animation/unmount lifetime.
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'saving and dismissing');
    expect(api.server.of(EntitySection.language).single.text('proficiency'), 'FLUENT');
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.editAction).last);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(currentPath(), '/builder/5');
    expect(entities.requests, hasLength(1));
    expect(tester.takeException(), isNull, reason: 'reopening and system Back');
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('builder steps and Review native captures $locale', (
      tester,
    ) async {
      seedProfile();
      await pump(
        tester,
        state: StartupState.signedIn,
        locale: locale,
        size: const Size(402, 1100),
      );
      for (final step in [3, 4, 5, 6]) {
        await route(tester, '/builder/$step');
        expect(tester.takeException(), isNull, reason: 'step $step');
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).first)),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(find.byKey(const Key('builder-progress')), findsOneWidget);
        noUnsupportedContent(tester);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/builder_step${step}_$locale.png'),
        );
      }
      expect(find.byKey(Key('review-experience-$experienceId')), findsOne);
      expect(find.text('Dart'), findsOneWidget);
      expect(entities.requests, isEmpty, reason: 'viewing never writes');
    });
    testWidgets(
      'invalid month drafts remain editable after disk reopen $locale',
      (tester) async {
        await pump(
          tester,
          state: StartupState.signedIn,
          locale: locale,
          size: const Size(402, 1100),
        );
        const cases = [
          (EntitySection.experience, 3, 'start_month', '2024-13'),
          (EntitySection.education, 4, 'start_month', '2024-00'),
          (EntitySection.certification, 4, 'issue_month', '2024-13'),
          (EntitySection.achievement, 4, 'achieved_month', '2024-00'),
          (EntitySection.project, 5, 'project_month', '2024-13'),
        ];
        for (final (section, step, field, invalid) in cases) {
          await route(tester, '/builder/$step');
          final add = find.byKey(Key('add-${section.key}'));
          await tester.ensureVisible(add);
          await tester.tap(add);
          await tester.pumpAndSettle();
          final input = find.byKey(Key('field-$field'));
          await tester.ensureVisible(input);
          await tester.enterText(input, invalid);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('editor-save')));
          await tester.pumpAndSettle();
          final copy = AppLocalizations.of(
            tester.element(find.byType(Scaffold)),
          )!;
          expect(find.text(copy.problemMonth), findsOneWidget);
          expect(entities.requests, isEmpty);
          await tester.tap(find.byKey(const Key('editor-back')));
          await tester.pumpAndSettle();
          expect(currentPath(), '/builder/$step');
          expect(find.text(invalid), findsWidgets);
          expect(tester.takeException(), isNull);
          final drafts = await EntityRepository(
            repository,
            entities.send,
          ).unsavedNew(api.server, section);
          final id = drafts.single.id;

          // Close both the app and its SQLCipher connection, then open the
          // persisted file with the same key and fresh providers.
          await tester.pumpWidget(const SizedBox());
          container!.dispose();
          container = null;
          await tester.runAsync(() async {
            await database.close();
            database = AppDatabase(
              encryptedDatabase(File('${directory.path}/db'), databaseKey),
            );
            await database.setting('locale');
          });
          repository = DraftRepository(database, api, 'user-one', () => true);
          await pump(
            tester,
            state: StartupState.signedIn,
            locale: locale,
            size: const Size(402, 1100),
          );
          await route(tester, '/builder/$step');
          expect(find.text(invalid), findsWidgets);
          expect(tester.takeException(), isNull);
          final menu = find.byKey(Key('menu-${section.key}-$id'));
          await tester.ensureVisible(menu);
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.text(copy.editAction).last);
          await tester.pumpAndSettle();
          expect(currentPath(), '/career/edit/${section.key}/$id');
          expect(
            tester
                .widget<TextField>(find.byKey(Key('field-$field')))
                .controller!
                .text,
            invalid,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
    testWidgets('builder narrow scaled layouts $locale', (tester) async {
      seedProfile();
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        state: StartupState.signedIn,
        locale: locale,
        size: const Size(320, 740),
      );
      for (final path in [
        '/builder/3',
        '/builder/4',
        '/builder/5',
        '/builder/6',
        '/career/edit/experience/$experienceId',
      ]) {
        await route(tester, path);
        expect(tester.takeException(), isNull, reason: '$locale $path');
      }
    });
  }

  testWidgets('Review -> Edit -> Save -> Review persists across restart', (
    tester,
  ) async {
    seedProfile();
    await pump(
      tester,
      state: StartupState.signedIn,
      size: const Size(402, 1100),
    );
    await route(tester, '/builder/6');
    final entry = find.byKey(const Key('review-experience-$experienceId'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(currentPath(), '/career/edit/experience/$experienceId');
    await tester.enterText(find.byKey(const Key('field-company')), 'Edited Co');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    // The editor returns to its origin only after the server acknowledged.
    expect(currentPath(), '/builder/6');
    expect(entities.requests.single.type, 'upsert_item');
    expect(
      api.server.of(EntitySection.experience).single.text('company'),
      'Edited Co',
    );
    expect(find.textContaining('Edited Co'), findsWidgets);
    // Restart: a fresh app reads the acknowledged snapshot again.
    await tester.pumpWidget(const SizedBox());
    container!.dispose();
    await pump(
      tester,
      state: StartupState.signedIn,
      size: const Size(402, 1100),
    );
    await route(tester, '/builder/6');
    expect(find.textContaining('Edited Co'), findsWidgets);
    expect(find.textContaining('First Co'), findsNothing);
  });

  testWidgets(
    'adding from a builder step returns there; remove needs confirmation',
    (tester) async {
      await pump(
        tester,
        state: StartupState.signedIn,
        size: const Size(402, 1100),
      );
      await route(tester, '/builder/3');
      await tester.tap(find.byKey(const Key('add-experience')));
      await tester.pumpAndSettle();
      expect(currentPath(), startsWith('/career/edit/experience/'));
      const values = {
        'job_title': 'Mobile Engineer',
        'company': 'New Co',
        'start_month': '2021-04',
        'end_month': '2023-02',
        'description': 'Owned releases and the design system rollout.',
      };
      for (final entry in values.entries) {
        final field = find.byKey(Key('field-${entry.key}'));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-save')));
      await tester.pumpAndSettle();
      expect(currentPath(), '/builder/3');
      final saved = api.server.of(EntitySection.experience).single;
      expect(saved.text('company'), 'New Co');
      expect(saved.complete, true);
      // Client-generated ids are UUIDs, not the literal 'new'.
      expect(saved.id, isNot('new'));
      expect(saved.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(find.byKey(Key('card-experience-${saved.id}')), findsOneWidget);
      await tester.tap(find.byKey(Key('menu-experience-${saved.id}')));
      await tester.pumpAndSettle();
      final copy = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      await tester.tap(find.text(copy.removeAction).last);
      await tester.pumpAndSettle();
      // Cancelling keeps the item.
      await tester.tap(find.text(copy.cancelAction));
      await tester.pumpAndSettle();
      expect(api.server.of(EntitySection.experience), hasLength(1));
      await tester.tap(find.byKey(Key('menu-experience-${saved.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(copy.removeAction).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-remove')));
      await tester.pumpAndSettle();
      expect(api.server.of(EntitySection.experience), isEmpty);
      expect(entities.requests.map((r) => r.type), [
        'upsert_item',
        'delete_item',
      ]);
    },
  );

  String currentLocation() => container!
      .read(routerProvider)
      .routeInformationProvider
      .value
      .uri
      .toString();

  void bumpServerExperience(String company) {
    final current = api.server;
    api.server = CareerProfile(
      id: current.id,
      version: current.version + 1,
      resumeLanguage: current.resumeLanguage,
      completeness: current.completeness,
      items: {
        ...current.items,
        EntitySection.experience: [
          seededExperience.rebased(2).copyWith('company', company),
        ],
      },
    );
  }

  for (final choice in ['local', 'server']) {
    testWidgets('a stale draft asks before saving: keep $choice', (
      tester,
    ) async {
      seedProfile();
      // A draft started from item version 1, then another device saved v2
      // before this app started again.
      await EntityRepository(repository, entities.send).retainDraft(
        api.server.id,
        seededExperience.copyWith('company', 'Local Co'),
      );
      bumpServerExperience('Other device Co');
      await pump(
        tester,
        state: StartupState.signedIn,
        size: const Size(402, 1100),
      );
      await route(
        tester,
        '/career/edit/experience/$experienceId?origin=review',
      );
      expect(find.byKey(const Key('draft-conflict')), findsOneWidget);
      // Save is blocked until the user chooses.
      await tester.tap(find.byKey(const Key('editor-save')));
      await tester.pumpAndSettle();
      expect(entities.requests, isEmpty);
      expect(currentPath(), '/career/edit/experience/$experienceId');
      if (choice == 'local') {
        await tester.tap(find.byKey(const Key('conflict-keep-local')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('draft-conflict')), findsNothing);
        await tester.tap(find.byKey(const Key('editor-save')));
        await tester.pumpAndSettle();
        expect(currentPath(), '/builder/6');
        final saved = api.server.of(EntitySection.experience).single;
        expect(saved.text('company'), 'Local Co');
        expect(saved.version, 3);
      } else {
        await tester.tap(find.byKey(const Key('conflict-keep-server')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('draft-conflict')), findsNothing);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byKey(const Key('field-company')),
                  matching: find.byType(EditableText),
                ),
              )
              .controller
              .text,
          'Other device Co',
        );
        expect(entities.requests, isEmpty);
        expect(
          await EntityRepository(
            repository,
            entities.send,
          ).draft(api.server.id, EntitySection.experience, experienceId),
          isNull,
        );
      }
    });
  }

  testWidgets('Reload after a conflict asks when the item itself changed', (
    tester,
  ) async {
    seedProfile();
    await pump(
      tester,
      state: StartupState.signedIn,
      size: const Size(402, 1100),
    );
    await route(tester, '/career/edit/experience/$experienceId?origin=review');
    await tester.enterText(find.byKey(const Key('field-company')), 'Mine Co');
    await tester.pumpAndSettle();
    bumpServerExperience('Theirs Co');
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    final copy = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(copy.saveConflict), findsOneWidget);
    expect(
      api.server.of(EntitySection.experience).single.text('company'),
      'Theirs Co',
    );
    await tester.tap(find.text(copy.reloadAction));
    await tester.pumpAndSettle();
    // Not silently rebased: the user must pick a version.
    expect(find.byKey(const Key('draft-conflict')), findsOneWidget);
    expect(find.text(copy.itemChangedElsewhere), findsOneWidget);
  });

  testWidgets('every Review section Edit returns to Review', (tester) async {
    seedProfile();
    await pump(
      tester,
      state: StartupState.signedIn,
      size: const Size(402, 1100),
    );
    for (final section in EntitySection.values) {
      await route(tester, '/builder/6');
      final edit = find.byKey(Key('review-edit-${section.key}'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(currentLocation(), contains('origin=review'), reason: section.key);
      final copy = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      expect(find.text(copy.backToReview), findsOneWidget);
      await tester.tap(find.byKey(const Key('builder-continue')));
      await tester.pumpAndSettle();
      expect(currentPath(), '/builder/6', reason: section.key);
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('builder-back')));
      await tester.pumpAndSettle();
      expect(currentPath(), '/builder/6', reason: '${section.key} back');
    }
    // Section Edit -> item editor -> Save -> Review.
    await tester.tap(find.byKey(const Key('review-edit-experience')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-experience-$experienceId')));
    await tester.pumpAndSettle();
    final copy = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    await tester.tap(find.text(copy.editAction).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('field-company')),
      'Via Section',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    expect(currentPath(), '/builder/6');
    expect(find.textContaining('Via Section'), findsWidgets);
    // Inline skills from Review: add, then return to Review showing it.
    final skills = find.byKey(const Key('review-edit-skill'));
    await tester.ensureVisible(skills);
    await tester.tap(skills);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('skill-input')), 'Kotlin');
    await tester.tap(find.byKey(const Key('skill-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('builder-continue')));
    await tester.pumpAndSettle();
    expect(currentPath(), '/builder/6');
    expect(find.text('Kotlin'), findsOneWidget);
  });

  testWidgets('an offline editor save keeps the draft and says so', (
    tester,
  ) async {
    seedProfile();
    await pump(
      tester,
      state: StartupState.signedIn,
      size: const Size(402, 1100),
    );
    await route(tester, '/career/edit/experience/$experienceId?origin=review');
    await tester.enterText(
      find.byKey(const Key('field-company')),
      'Offline Co',
    );
    await tester.pumpAndSettle();
    entities.offline = true;
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    expect(currentPath(), '/career/edit/experience/$experienceId');
    expect(find.byKey(const Key('save-issue')), findsOneWidget);
    expect(
      api.server.of(EntitySection.experience).single.text('company'),
      'First Co',
    );
    entities.offline = false;
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('save-issue')),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      api.server.of(EntitySection.experience).single.text('company'),
      'Offline Co',
    );
    // Retried with the original command key; never duplicated.
    expect(entities.requests.map((r) => r.key).toSet(), hasLength(1));
  });

  testWidgets('skills are added once; normalized duplicates are refused', (
    tester,
  ) async {
    seedProfile();
    await pump(
      tester,
      state: StartupState.signedIn,
      size: const Size(402, 1100),
    );
    await route(tester, '/builder/5');
    await tester.enterText(find.byKey(const Key('skill-input')), 'Flutter');
    await tester.tap(find.byKey(const Key('skill-add')));
    await tester.pumpAndSettle();
    expect(api.server.of(EntitySection.skill).map((s) => s.text('name')), [
      'Dart',
      'Flutter',
    ]);
    await tester.enterText(find.byKey(const Key('skill-input')), '  dart ');
    await tester.tap(find.byKey(const Key('skill-add')));
    await tester.pumpAndSettle();
    final copy = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(copy.duplicateItem), findsOneWidget);
    expect(entities.requests, hasLength(1));
    // Steps 3-5 Continue only navigates.
    await tester.tap(find.byKey(const Key('builder-continue')));
    await tester.pumpAndSettle();
    expect(currentPath(), '/builder/6');
    expect(entities.requests, hasLength(1));
  });

  testWidgets(
    'Career add returns to Career without a redundant Review action',
    (tester) async {
      seedProfile();
      await pump(
        tester,
        state: StartupState.signedIn,
        size: const Size(402, 1400),
      );
      await route(tester, '/career');
      final add = find.byKey(const Key('career-add-experience'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(currentPath(), startsWith('/career/edit/experience/'));
      await tester.tap(find.byKey(const Key('editor-back')));
      await tester.pumpAndSettle();
      expect(currentPath(), '/career');
      expect(find.byKey(const Key('career-review')), findsNothing);
      expect(currentPath(), '/career');
    },
  );
}

class _CoreFixture implements CoreApi {
  bool bootstrapFails = false;
  bool historyFails = false;
  int historyCalls = 0;

  @override
  Future<CoreSummary> bootstrap(String locale) async {
    if (bootstrapFails) throw StateError('Test transport failure');
    return const CoreSummary(
      balance: CreditBalance(
        finalized: 5,
        reserved: 0,
        available: 5,
        version: 1,
      ),
      profiles: [
        {
          'id': 'profile-one',
          'slot_number': 1,
          'name': null,
          'profile_version': 1,
        },
      ],
      slots: [
        {'slot_number': 1, 'unlocked': true},
      ],
    );
  }

  @override
  Future<CreditHistory> transactions({String? cursor}) async {
    historyCalls++;
    if (historyFails) throw StateError('Test history transport failure');
    return const CreditHistory(items: []);
  }
}
