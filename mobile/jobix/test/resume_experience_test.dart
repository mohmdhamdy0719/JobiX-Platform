import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/features/auth/auth_controller.dart';
import 'package:jobix/features/builder/resume_journey.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/core_mvp/core_api.dart';
import 'package:jobix/features/home/home_page.dart';
import 'package:jobix/features/resume/resume_document.dart';
import 'package:jobix/features/resume/resume_experience_shared.dart';
import 'package:jobix/features/resume/resume_experience_widgets.dart';
import 'package:jobix/l10n/app_localizations.dart';
import 'resume_export_test.dart' as fixtures;
import 'support/production_fonts.dart';

void main() {
  setUpAll(loadProductionFonts);
  final profile = CareerProfile.fromJson(fixtures.savedProfile);
  final job = <String, dynamic>{
    'id': fixtures.jobId,
    'profile_id': fixtures.profileId,
    'state': 'COMPLETED',
    'page_count': 2,
    'object_size': 24000,
    'download_eligible': true,
    'created_at': '2026-10-10T12:00:00Z',
    'expires_at': DateTime.now().add(const Duration(days: 6)).toIso8601String(),
  };
  test(
    'journey defaults to Personal, survives serialization, scopes actor/profile',
    () {
      expect(ResumeJourney.decode(null).step, 1);
      expect(ResumeJourney.decode(null).complete, isFalse);
      expect(
        ResumeJourney.decode(const ResumeJourney(step: 4).encode()).step,
        4,
      );
      expect(
        ResumeJourney.decode(
          const ResumeJourney(step: 6, complete: true).encode(),
        ).complete,
        isTrue,
      );
      expect(
        ResumeJourney.fromStorage(null, accountCompleted: true).complete,
        isTrue,
      );
      expect(
        ResumeJourney.fromStorage(
          const ResumeJourney(step: 3).encode(),
          accountCompleted: true,
        ).step,
        3,
      );
      expect(
        journeyKey('one', profile.id),
        isNot(journeyKey('two', profile.id)),
      );
      expect(
        journeyKey('one', profile.id),
        isNot(journeyKey('one', 'other-profile')),
      );
    },
  );
  test(
    'minimum content is structural: valid Volunteer at 15%, not Review or 50%',
    () {
      expect(minimumResumeContent(profile), isTrue);
      expect(
        minimumResumeContent(CareerProfile(id: profile.id, version: 1)),
        isFalse,
      );
      final invalid = CareerProfile.fromJson({
        ...fixtures.savedProfile,
        'personal': {
          ...fixtures.savedProfile['personal'] as Map,
          'email': 'invalid',
        },
      });
      expect(minimumResumeContent(invalid), isFalse);
      expect(
        minimumResumeContent(
          CareerProfile.fromJson({
            ...fixtures.savedProfile,
            'volunteer_experiences': <Map>[],
          }),
        ),
        isFalse,
      );
    },
  );
  test(
    'invalid optional sections still block export until explicitly hidden',
    () {
      final invalid = CareerProfile.fromJson({
        ...fixtures.savedProfile,
        'summary': 'x' * 1001,
      });
      expect(minimumResumeContent(invalid), isTrue);
      expect(
        ResumeDocument.issues(invalid, ResumePresentation(language: 'en')),
        contains('summary'),
      );
      expect(
        ResumeDocument.issues(
          invalid,
          ResumePresentation(language: 'en', hidden: const {'summary'}),
        ),
        isEmpty,
      );
    },
  );
  test('resume details use singular and plural page labels', () {
    expect(const ResumeCopy(false).pageCount(1), '1 page');
    expect(const ResumeCopy(false).pageCount(2), '2 pages');
    expect(const ResumeCopy(true).pageCount(1), 'صفحة واحدة');
    expect(const ResumeCopy(true).pageCount(2), 'صفحتان');
  });
  test('template display names never leak an internal identifier', () {
    const copy = ResumeCopy(false);
    expect(
      resumeTemplateDisplayName(copy, 'resume_ats_en_v1'),
      'ATS Professional',
    );
    expect(
      copy.atsSingleTemplate,
      'A clean, single-column resume designed for readability and ATS compatibility.',
    );
    expect(
      copy.templateSpecifications,
      'A4 page · Single column · Consistent spacing and typography.',
    );
    expect(
      resumeTemplateDisplayName(
        const ResumeCopy(false),
        '70000000-0000-4000-8000-000000000003',
      ),
      isNull,
    );
  });
  test(
    'expiry/eligibility never causes automatic regeneration or a second charge',
    () {
      expect(resumeIsDownloadAvailable(job, 'completed'), isTrue);
      expect(
        resumeIsDownloadAvailable({
          ...job,
          'download_eligible': false,
        }, 'completed'),
        isFalse,
      );
      expect(
        resumeIsDownloadAvailable({
          ...job,
          'expires_at': DateTime.now()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        }, 'completed'),
        isFalse,
      );
      expect(resumeIsDownloadAvailable(job, 'failed'), isFalse);
    },
  );
  test('all deployed job states map honestly, including expiry and retry', () {
    for (final state in [
      'CLAIMED',
      'GENERATING',
      'UPLOADING',
      'RETRYABLE_FAILURE',
    ]) {
      expect(resumeJobState({'state': state}), 'processing');
    }
    expect(resumeJobState({'state': 'EXPIRED'}), 'expired');
    expect(resumeJobState({'state': 'MISSING_OBJECT'}), 'missing');
    expect(resumeJobState({'state': 'FAILED'}), 'failed');
    expect(resumeJobState({'state': 'QUEUED'}), 'queued');
  });
  for (final complete in [false, true]) {
    testWidgets(
      'Home ${complete ? 'opens Career after completion' : 'resumes saved step instead of Review'}',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomePage()),
            GoRoute(
              path: '/career',
              builder: (_, __) => const Text('Career destination'),
            ),
            GoRoute(
              path: '/builder/4',
              builder: (_, __) => const Text('Education destination'),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firstProfileProvider.overrideWith((_) async => profile),
              resumeJourneyProvider(profile.id).overrideWith(
                (_) async => ResumeJourney(step: 4, complete: complete),
              ),
              unfinishedDraftProvider(
                profile.id,
              ).overrideWith((_) async => false),
              contextMergeProvider.overrideWith((_) async {}),
              coreSummaryProvider.overrideWith(
                (_) async => throw StateError('Offline fixture'),
              ),
              authSessionProvider.overrideWith((_) => const Stream.empty()),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: foundationTheme(languageCode: 'en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('continue-career')));
        await tester.tap(find.byKey(const Key('continue-career')));
        await tester.pumpAndSettle();
        expect(
          find.text(complete ? 'Career destination' : 'Education destination'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      },
    );
  }
  for (final language in ['en', 'ar']) {
    testWidgets(
      'native resume presentation $language at phone width has truthful states and working actions',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var inspected = false;
        await tester.pumpWidget(
          fixtures.app(
            ResumeTemplateCard(
              language: language,
              onInspect: () => inspected = true,
            ),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ResumeTemplateCard));
        expect(inspected, isTrue);
        expect(find.textContaining('98'), findsNothing);
        expect(tester.takeException(), isNull);
        var downloaded = false;
        final capture = GlobalKey();
        await tester.pumpWidget(
          fixtures.app(
            RepaintBoundary(
              key: capture,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ResumeDetailsBody(
                  job: job,
                  onDownload: () => downloaded = true,
                  downloading: true,
                ),
              ),
            ),
            language: language,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final downloadingLabel = language == 'en'
            ? 'Downloading'
            : 'جارٍ التنزيل';
        expect(find.text(downloadingLabel), findsOneWidget);
        expect(find.text('Refresh details'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is ElevatedButton && widget.onPressed == null,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final path = Directory('../../.local/jobix-native-verification');
          await path.create(recursive: true);
          await File(
            '${path.path}/resume-details-$language.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(
          fixtures.app(
            Padding(
              padding: const EdgeInsets.all(16),
              child: ResumeDetailsBody(
                job: job,
                onDownload: () => downloaded = true,
              ),
            ),
            language: language,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byIcon(Icons.download_outlined), findsOneWidget);
        final button = find.byIcon(Icons.download_outlined);
        await tester.ensureVisible(button);
        await tester.tap(button);
        expect(downloaded, isTrue);
        await tester.pumpWidget(
          fixtures.app(
            ResumeJobCard(job: job, onDetails: () {}, downloading: true),
            language: language,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(downloadingLabel), findsOneWidget);
        expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
        expect(find.textContaining(job['id'] as String), findsNothing);
        await tester.pumpWidget(
          fixtures.app(
            ResumeJobCard(job: {...job, 'state': 'FAILED'}, onDetails: () {}),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('−2 Credits'), findsNothing);
        expect(find.textContaining(job['id'] as String), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          fixtures.app(
            SizedBox(
              height: 730,
              child: ResumeProcessingView(
                job: {...job, 'state': 'QUEUED'},
                onHistory: () {},
                onDashboard: () {},
              ),
            ),
            language: language,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.textContaining('85%'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
