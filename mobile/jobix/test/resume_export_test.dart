import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/core/providers.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/core_mvp/core_api.dart';
import 'package:jobix/features/resume/resume_document.dart';
import 'package:jobix/features/resume/resume_export_panel.dart';
import 'package:jobix/features/resume/resume_render.dart';
import 'package:jobix/features/resume/resume_operation_page.dart';
import 'package:jobix/features/resume/resume_page.dart';
import 'package:jobix/features/resume/resume_experience_shared.dart';
import 'package:jobix/features/auth/auth_controller.dart';
import 'package:jobix/features/builder/resume_journey.dart';
import 'package:jobix/features/resume/resume_export_service.dart';
import 'package:jobix/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/production_fonts.dart';
import 'support/slice_fakes.dart';

class _PdfOverrides extends HttpOverrides {
  final bytes = Uint8List.fromList(utf8.encode('%PDF-synthetic fixture'));
  bool closed = false;
  @override
  HttpClient createHttpClient(SecurityContext? context) => _PdfClient(this);
}

class _PdfClient implements HttpClient {
  _PdfClient(this.fixture);
  final _PdfOverrides fixture;
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    expect(uri.host, 'storage.googleapis.com');
    expect(uri.queryParameters['generation'], '7');
    return _PdfRequest(fixture.bytes);
  }

  @override
  void close({bool force = false}) {
    fixture.closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PdfRequest implements HttpClientRequest {
  _PdfRequest(this.bytes);
  final Uint8List bytes;
  @override
  set followRedirects(bool value) {
    expect(value, false);
  }

  @override
  Future<HttpClientResponse> close() async => _PdfResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PdfResponse extends Stream<List<int>> implements HttpClientResponse {
  _PdfResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const enabled = bool.fromEnvironment('JOBIX_ENABLE_PDF_EXPORT');
const actor = '70000000-0000-4000-8000-000000000001';
const profileId = '70000000-0000-4000-8000-000000000002';
const jobId = '70000000-0000-4000-8000-000000000003';
const documentHtml =
    '<html><body>Authoritative synthetic document العربية</body></html>';
final document = <String, dynamic>{
  'html': documentHtml,
  'profile_version': 4,
  'configuration_version': 3,
  'document_sha256': 'a' * 64,
  'bundle': ResumeDocument.bundle,
  'language': 'en',
  'issues': <String>[],
  'configuration': {'section_visibility': <String, dynamic>{}},
};
final savedProfile = <String, dynamic>{
  'profile_id': profileId,
  'profile_version': 4,
  'completeness_percent': 15,
  'personal': {
    'full_name': 'Fixture',
    'email': 'fixture@example.invalid',
    'phone': '+20 100 000 0000',
  },
  'volunteer_experiences': [
    {
      'id': 'volunteer-one',
      'organization': 'Community',
      'role': 'Helper',
      'start_month': '2025-01',
      'is_current': true,
      'description': '',
      'complete': false,
    },
  ],
};

Widget app(
  Widget child, {
  String language = 'en',
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: foundationTheme(languageCode: language),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  if (enabled) {
    // Real SQLCipher isolate I/O and SDK streams must not race a fake clock.
    // All HTTP is still a synthetic MockClient; this never contacts live services.
    LiveTestWidgetsFlutterBinding.ensureInitialized();
  }
  setUpAll(loadProductionFonts);
  test(
    'shared prepared default is byte-identical to the canonical renderer',
    () {
      final prepared = ResumeDocument.prepare(
        {
          'profile': savedProfile,
          'configuration': {'language': 'en'},
        },
        'font',
        'font',
      );
      expect(
        prepared['html'],
        ResumeRender.html(
          profile: CareerProfile.fromJson(savedProfile),
          language: 'en',
          latinFontBase64: 'font',
          arabicFontBase64: 'font',
          additionalLinks: [],
        ),
      );
      expect(prepared['issues'], isEmpty);
    },
  );
  test('resume contact links use readable labels rather than raw URLs', () {
    final linkedProfile = CareerProfile.fromJson({
      ...savedProfile,
      'personal': {
        ...(savedProfile['personal'] as Map),
        'linkedin_url': 'https://www.linkedin.com/in/example',
        'github_url': 'https://github.com/example',
      },
    });
    final html = ResumeRender.html(
      profile: linkedProfile,
      language: 'en',
      latinFontBase64: 'font',
      arabicFontBase64: 'font',
      additionalLinks: const [
        {'label': 'Research publication', 'url': 'https://example.test/paper'},
      ],
    );
    expect(html, contains('>LinkedIn</bdi></a>'));
    expect(html, contains('>GitHub</bdi></a>'));
    expect(html, contains('>Research publication</bdi></a>'));
    expect(html, isNot(contains('Research publication: https://')));
  });
  test(
    'hiding invalid Volunteer is explicit and cannot silently leave empty evidence',
    () {
      final bad = CareerProfile.fromJson({
        ...savedProfile,
        'volunteer_experiences': [
          {
            'id': 'bad',
            'role': '',
            'organization': 'Community',
            'start_month': '2025-01',
            'is_current': true,
          },
        ],
      });
      expect(
        ResumeDocument.issues(bad, ResumePresentation(language: 'en')),
        contains('volunteer:bad'),
      );
      expect(
        ResumeDocument.issues(
          bad,
          ResumePresentation(language: 'en', hidden: {'volunteer'}),
        ),
        ['career_content'],
      );
      expect(bad.completeness, 15);
    },
  );
  if (!enabled) {
    for (final language in ['en', 'ar']) {
      testWidgets(
        '$language default-off admissions retain history and reconnect controls',
        (tester) async {
          await tester.pumpWidget(
            app(
              ResumeExportPanel(
                profileId: profileId,
                canPrepare: true,
                historyOnly: true,
                showDocument: (_) async {},
              ),
              language: language,
              overrides: [
                supabaseClientProvider.overrideWith(
                  (_) async => throw StateError('Must not read client'),
                ),
                databaseProvider.overrideWith(
                  (_) async => throw StateError('Must not read database'),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TextButton), findsWidgets);
          expect(find.text('Refresh history'), findsNothing);
          expect(
            find.text(
              language == 'en' ? 'Retry history' : 'إعادة محاولة تحميل السجل',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    return;
  }

  configureSqlCipher(
    testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
  );
  late Directory directory;
  late AppDatabase db;
  late SupabaseClient client;
  late List<Map<String, dynamic>> commands;
  Map<String, dynamic>? acknowledgement;
  late Map<String, dynamic> prepared;
  late Map<String, dynamic> resumeConfiguration;
  late Map<String, Map<String, dynamic>> configurationAcknowledgements;
  late List<Map<String, dynamic>> configurationSaveCommands;
  bool paginate = false;
  int creditBalance = 8;
  bool creditBalanceUnavailable = false;
  int creditBalanceReads = 0;
  bool expiredDownload = true;
  bool loseResponse = false;
  bool loseConfigurationResponse = false;
  String workerState = 'QUEUED';
  String? rejected;
  int? rejectedRetryAfter;
  int accepted = 0;
  Map<String, dynamic>? observedDocument;

  Future<void> mount(
    WidgetTester tester, {
    String language = 'en',
    bool initial = false,
    bool includeCompleted = false,
    bool historyOnly = false,
    ValueChanged<String>? onOperation,
    GlobalKey<ResumeExportPanelState>? panelKey,
  }) async {
    await tester.pumpWidget(
      app(
        ResumeExportPanel(
          key: panelKey,
          profileId: profileId,
          canPrepare: true,
          historyOnly: historyOnly,
          initialDocument: initial ? document : null,
          showDocument: (value) async {
            observedDocument = value;
          },
          onOperation: onOperation ?? (_) {},
        ),
        language: language,
        overrides: [
          supabaseClientProvider.overrideWith((_) async => client),
          databaseProvider.overrideWith((_) async => db),
          coreSummaryProvider.overrideWith((_) async {
            creditBalanceReads++;
            if (creditBalanceUnavailable) {
              throw StateError('synthetic balance failure');
            }
            return CoreSummary(
              balance: CreditBalance(
                finalized: creditBalance,
                reserved: 0,
                available: creditBalance,
                version: 1,
              ),
              profiles: const [],
              slots: const [],
            );
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump(const Duration(milliseconds: 350));
    // Busy remains true while confirmation awaits a user choice.
    if (find.byType(AlertDialog).evaluate().isEmpty) {
      await tester.pumpAndSettle();
    }
  }

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('jobix-export-widget-');
    db = AppDatabase(
      encryptedDatabase(File('${directory.path}/cache'), generateDatabaseKey()),
    );
    commands = [];
    acknowledgement = null;
    observedDocument = null;
    accepted = 0;
    loseResponse = false;
    workerState = 'QUEUED';
    rejected = null;
    rejectedRetryAfter = null;
    paginate = false;
    creditBalance = 8;
    creditBalanceUnavailable = false;
    creditBalanceReads = 0;
    expiredDownload = true;
    prepared = {
      ...document,
      'configuration': {'section_visibility': <String, dynamic>{}},
    };
    resumeConfiguration = {
      'profile_id': profileId,
      'language': 'en',
      'template_id': 'resume_ats_en_v1',
      'section_visibility': <String, dynamic>{},
      'version': 1,
    };
    configurationAcknowledgements = {};
    configurationSaveCommands = [];
    loseConfigurationResponse = false;
    client = SupabaseClient(
      'https://synthetic.example.invalid',
      'synthetic-publishable',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (request.url.path.endsWith('/read_resume_configuration')) {
          return http.Response(
            jsonEncode(resumeConfiguration),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/save_resume_configuration')) {
          final command = Map<String, dynamic>.from(body);
          final commandKey = command['command_key'] as String;
          configurationSaveCommands.add(command);
          final saved = configurationAcknowledgements.putIfAbsent(
            commandKey,
            () {
              resumeConfiguration = {
                ...resumeConfiguration,
                'language': command['language'],
                'template_id': command['template_id'],
                'version': (resumeConfiguration['version'] as int) + 1,
              };
              return Map<String, dynamic>.from(resumeConfiguration);
            },
          );
          if (loseConfigurationResponse) {
            loseConfigurationResponse = false;
            return http.Response(
              '{"message":"synthetic response lost after commit"}',
              503,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(saved),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/save_resume_presentation')) {
          commands.add({
            'action': 'presentation',
            'command': Map<String, dynamic>.from(body),
          });
          prepared = {
            ...prepared,
            'profile_version': (prepared['profile_version'] as int) + 1,
            'configuration_version':
                (prepared['configuration_version'] as int) + 1,
            'configuration': {
              'section_visibility': {
                for (final key in body['hidden_sections'] as List) key: false,
              },
            },
          };
          return http.Response(
            jsonEncode(prepared['configuration']),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        final action = body['action'];
        final command = Map<String, dynamic>.from(body['command'] as Map);
        commands.add({'action': action, 'command': command});
        dynamic result;
        if (action == 'history') {
          result = {
            'jobs': [
              {
                'id': jobId,
                'profile_id': profileId,
                'state': acknowledgement == null ? 'COMPLETED' : workerState,
                'created_at': '2026-10-08T12:00:00Z',
              },
            ],
            'next_cursor': paginate && command['cursor'] == null ? jobId : null,
          };
        } else if (action == 'document') {
          result = prepared;
        } else if (action == 'create' || action == 'again') {
          if (rejected != null) {
            return http.Response(
              jsonEncode({
                'data': null,
                'error': {
                  'code': rejected,
                  if (rejectedRetryAfter != null)
                    'retry_after_seconds': rejectedRetryAfter,
                },
              }),
              rejected == 'RATE_LIMITED'
                  ? 429
                  : rejected == 'EXPORT_IN_PROGRESS'
                  ? 409
                  : 503,
              headers: {'content-type': 'application/json'},
            );
          }
          if (acknowledgement == null) {
            accepted++;
            acknowledgement = {
              'operation_id': jobId,
              'data': {
                'balance': {
                  'finalized': 5,
                  'reserved': 2,
                  'available': 3,
                  'version': 1,
                },
              },
            };
          }
          if (loseResponse) {
            loseResponse = false;
            throw const SocketException('Synthetic response loss');
          }
          result = acknowledgement;
        } else if (action == 'status') {
          result = {
            'id': jobId,
            'profile_id': profileId,
            'state': workerState,
            'page_count': 1,
            'object_size': 2048,
            'download_eligible': workerState == 'COMPLETED',
            'expires_at': DateTime.now()
                .add(const Duration(days: 7))
                .toIso8601String(),
          };
        } else if (action == 'download') {
          if (!expiredDownload) {
            return http.Response(
              jsonEncode({
                'data': {
                  'url':
                      'https://storage.googleapis.com/synthetic.pdf?generation=7&token=synthetic-only',
                },
                'error': null,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'data': null,
              'error': {'code': 'EXPORT_EXPIRED'},
            }),
            503,
            headers: {'content-type': 'application/json'},
          );
        } else {
          throw StateError('Unexpected synthetic request');
        }
        return http.Response(
          jsonEncode({'data': result, 'error': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    String segment(Map<String, Object> payload) =>
        base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
    final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final token =
        '${segment({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${segment({'sub': actor, 'exp': expiry, 'role': 'authenticated'})}.synthetic-signature';
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'synthetic-only',
        'expires_in': 3600,
        'expires_at': expiry,
        'token_type': 'bearer',
        'user': {
          'id': actor,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'fixture@example.invalid',
          'created_at': '2026-10-01T00:00:00Z',
        },
      }),
    );
    expect(client.auth.currentUser?.id, actor);
    await db.setting('resume:$actor:export:$profileId');
  });
  testWidgets(
    'language selection saves immediately and retries the same request after a lost acknowledgement',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profileApi = FakeProfileApi()
        ..server = CareerProfile.fromJson(savedProfile);
      final repository = DraftRepository(
        db,
        profileApi,
        actor,
        () => client.auth.currentUser?.id == actor,
      );
      loseConfigurationResponse = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWith((_) async => client),
            databaseProvider.overrideWith((_) async => db),
            draftRepositoryProvider.overrideWith((_) async => repository),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: foundationTheme(languageCode: 'en'),
            home: const ResumePage(),
          ),
        ),
      );
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final englishSelector = find.widgetWithText(ChoiceChip, 'English (LTR)');
      final arabicSelector = find.widgetWithText(ChoiceChip, 'العربية (RTL)');
      expect(
        tester.getSize(englishSelector).width,
        closeTo(tester.getSize(arabicSelector).width, 0.5),
      );
      final arabicChoice = find.text('العربية (RTL)');
      await tester.ensureVisible(arabicChoice);
      await tester.tap(arabicChoice);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Retry saving this language'), findsOneWidget);
      final outboxKey = 'resume:$actor:$profileId';
      final frozen = jsonDecode((await db.setting(outboxKey))!) as Map;
      final commandKey = frozen['command_key'];
      expect(configurationSaveCommands, hasLength(1));
      expect(resumeConfiguration['language'], 'ar');
      expect(resumeConfiguration['version'], 2);

      await tester.tap(find.text('Retry saving this language'));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Resume language saved.'), findsOneWidget);
      expect(await db.setting(outboxKey), isNull);
      expect(configurationSaveCommands, hasLength(2));
      expect(
        configurationSaveCommands.map((command) => command['command_key']),
        everyElement(commandKey),
      );
      expect(resumeConfiguration['version'], 2);
      expect(accepted, 0);
      expect(
        commands.where(
          (command) =>
              ['document', 'create', 'again'].contains(command['action']),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'local Preview installs its document without preparing online and rejects stale export review',
    (tester) async {
      final panelKey = GlobalKey<ResumeExportPanelState>();
      await mount(tester, panelKey: panelKey);
      commands.clear();
      final local = {
        ...document,
        'document_sha256': null,
        'profile_version': 4,
      };

      await panelKey.currentState!.showLocalDocument(local);

      expect(observedDocument, same(local));
      expect(commands, isEmpty);
      expect(accepted, 0);

      final createFuture = panelKey.currentState!.createPdf({
        ...local,
        'profile_version': 5,
      });
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(commands.map((item) => item['action']), ['document']);
      expect(panelKey.currentState!.reviewRequired, isTrue);
      expect(accepted, 0);
      expect(creditBalanceReads, 1);
      expect(await db.setting('resume:$actor:export:$profileId'), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await createFuture;

      final currentDocument = panelKey.currentState!.document!;
      expect(find.byKey(const Key('review-updated-preview')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('review-updated-preview')),
      );
      await tester.tap(find.byKey(const Key('review-updated-preview')));
      await tester.pumpAndSettle();
      expect(observedDocument, same(currentDocument));

      final reviewedAgain = panelKey.currentState!.createPdf(currentDocument);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(commands.map((item) => item['action']), ['document', 'document']);
      expect(accepted, 0);
      expect(await db.setting('resume:$actor:export:$profileId'), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await reviewedAgain;
    },
  );
  tearDown(() async {
    await client.dispose();
    await db.close();
    directory.deleteSync(recursive: true);
  });
  for (final language in ['en', 'ar']) {
    testWidgets('$language phone-width controls/history do not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, language: language, initial: true);
      expect(find.byType(CheckboxListTile), findsNWidgets(10));
      expect(find.text('Refresh history'), findsNothing);
      expect(find.text('Retry history'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'free preparation displays exact server bytes without creating a job',
    (tester) async {
      await mount(tester);
      await tap(tester, 'Prepare online Preview — free');
      expect(observedDocument!['html'], documentHtml);
      expect(
        commands.where(
          (c) => c['action'] == 'create' || c['action'] == 'again',
        ),
        isEmpty,
      );
      expect(accepted, 0);
    },
  );
  testWidgets(
    'cost confirmation can decline without a request or saved outbox',
    (tester) async {
      creditBalance = 2;
      await mount(tester, initial: true);
      await tap(tester, 'Create PDF — 2 Credits');
      await tap(tester, 'Cancel');
      expect(accepted, 0);
      expect(await db.setting('resume:$actor:export:$profileId'), isNull);
      expect(commands.where((c) => c['action'] == 'create'), isEmpty);
    },
  );
  for (final language in ['en', 'ar']) {
    for (final balance in [0, 1]) {
      testWidgets(
        '$language verified balance $balance shows the compact Credit dialog before any export request',
        (tester) async {
          creditBalance = balance;
          await mount(tester, language: language, initial: true);
          await tap(
            tester,
            language == 'en' ? 'Create PDF — 2 Credits' : 'إنشاء PDF — رصيدان',
          );
          expect(
            find.text(
              language == 'en' ? 'Not enough Credits' : 'الرصيد غير كافٍ',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              language == 'en'
                  ? 'A new PDF export costs 2 Credits. You currently have $balance Credits.'
                  : 'يكلف تصدير PDF جديد رصيدين. رصيدك الحالي $balance.',
            ),
            findsOneWidget,
          );
          expect(
            commands.where(
              (command) =>
                  ['document', 'create', 'again'].contains(command['action']),
            ),
            isEmpty,
          );
          expect(accepted, 0);
          expect(await db.setting('resume:$actor:export:$profileId'), isNull);
          await tap(tester, language == 'en' ? 'Cancel' : 'إلغاء');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'unknown balance is not described as insufficient and sends no export request',
    (tester) async {
      creditBalanceUnavailable = true;
      await mount(tester, initial: true);
      await tap(tester, 'Create PDF — 2 Credits');
      expect(find.text('Credit balance unavailable'), findsOneWidget);
      expect(find.text('Not enough Credits'), findsNothing);
      expect(
        commands.where(
          (command) =>
              ['document', 'create', 'again'].contains(command['action']),
        ),
        isEmpty,
      );
      expect(accepted, 0);
      await tap(tester, 'Cancel');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'low-balance local Preview checks Credits before server document action',
    (tester) async {
      creditBalance = 1;
      final panelKey = GlobalKey<ResumeExportPanelState>();
      await mount(tester, panelKey: panelKey);
      commands.clear();
      final local = {...document, 'document_sha256': null};
      await panelKey.currentState!.showLocalDocument(local);
      final export = panelKey.currentState!.createPdf(local);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Not enough Credits'), findsOneWidget);
      expect(commands, isEmpty);
      expect(accepted, 0);
      expect(await db.setting('resume:$actor:export:$profileId'), isNull);
      await tap(tester, 'Cancel');
      await export;
      expect(creditBalanceReads, 1);
    },
  );
  testWidgets('ambiguous acceptance freezes key/payload and reconciles once', (
    tester,
  ) async {
    loseResponse = true;
    await mount(tester, initial: true);
    await tap(tester, 'Create PDF — 2 Credits');
    await tap(tester, 'Create — 2 Credits');
    final raw = await db.setting('resume:$actor:export:$profileId');
    expect(raw, isNotNull);
    final frozen = (jsonDecode(raw!) as Map)['command'] as Map;
    expect(frozen['payload'], {
      'profile_id': profileId,
      'expected_configuration_version': 3,
      'expected_document_sha256': 'a' * 64,
      'renderer_bundle_version': ResumeDocument.bundle,
    });
    expect(raw, isNot(contains(documentHtml)));
    expect(raw, isNot(contains('url')));
    // Reopen the controls as after navigation/restart, using the encrypted outbox.
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester);
    await tap(tester, 'Retry the saved request');
    final attempts = commands
        .where((c) => c['action'] == 'create')
        .map((c) => c['command'] as Map)
        .toList();
    expect(attempts, hasLength(2));
    expect(attempts[0]['idempotency_key'], attempts[1]['idempotency_key']);
    expect(attempts[0]['payload'], attempts[1]['payload']);
    expect(attempts[0]['request_id'], isNot(attempts[1]['request_id']));
    expect(accepted, 1);
    expect(await db.setting('resume:$actor:export:$profileId'), isNull);
    expect(find.text('Server balance: 3 available.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink()); // Disposes polling timer.
  });
  testWidgets(
    'valid free download saves bytes without persisting URL or creating another job',
    (tester) async {
      expiredDownload = false;
      final fixture = _PdfOverrides();
      Map? saved;
      const channel = MethodChannel('jobix/pdf_save');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'save');
        saved = call.arguments as Map;
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await HttpOverrides.runWithHttpOverrides(() async {
        creditBalance = 0;
        await mount(tester, initial: true);
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Download — free'),
              )
              .onPressed,
          isNotNull,
        );
        await tap(tester, 'Download — free');
        expect(saved!['bytes'], fixture.bytes);
        expect(saved!['name'], 'Resume.pdf');
        expect(saved!.containsKey('url'), false);
        expect(await db.setting('resume:$actor:export:$profileId'), isNull);
        expect(accepted, 0);
        expect(fixture.closed, true);
        expect(find.text('PDF saved. No Credits charged.'), findsOneWidget);
      }, fixture);
    },
  );
  testWidgets('expired download neither creates nor charges a replacement', (
    tester,
  ) async {
    await mount(tester, initial: true);
    await tap(tester, 'Download — free');
    expect(
      find.text('The file expired. No automatic regeneration or charge.'),
      findsOneWidget,
    );
    expect(accepted, 0);
    expect(
      commands.where((c) => c['action'] == 'create' || c['action'] == 'again'),
      isEmpty,
    );
  });
  testWidgets(
    'worker retry progress reaches completion on the same operation',
    (tester) async {
      await mount(
        tester,
        initial: true,
        onOperation: (id) {
          final context = tester.element(find.byType(ResumeExportPanel));
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ResumeOperationPage(exportId: id, waiting: true),
            ),
          );
        },
      );
      await tap(tester, 'Create PDF — 2 Credits');
      await tester.ensureVisible(find.text('Create — 2 Credits'));
      await tester.tap(find.text('Create — 2 Credits'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      Future<void> waitForStatusCount(int expected) async {
        for (
          var frame = 0;
          frame < 20 &&
              commands
                      .where((command) => command['action'] == 'status')
                      .length <
                  expected;
          frame++
        ) {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        }
        expect(
          commands.where((command) => command['action'] == 'status').length,
          greaterThanOrEqualTo(expected),
        );
      }

      await waitForStatusCount(1);
      workerState = 'RETRYABLE_FAILURE';
      await waitForStatusCount(2);
      final copy = ResumeCopy.of(tester.element(find.byType(Scaffold).last));
      expect(find.text(resumeStatusTitle(copy, 'processing')), findsOneWidget);
      workerState = 'COMPLETED';
      await waitForStatusCount(3);
      expect(find.text(resumeStatusLabel(copy, 'completed')), findsWidgets);
      expect(accepted, 1);
      final states = commands.where((c) => c['action'] == 'status');
      expect(states.length, greaterThanOrEqualTo(2));
      expect(
        states.every((c) => (c['command'] as Map)['export_id'] == jobId),
        true,
      );
      expect(await db.setting('resume:$actor:export:$profileId'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'terminal worker failure is visible without automatic new export',
    (tester) async {
      await mount(
        tester,
        initial: true,
        onOperation: (id) {
          final context = tester.element(find.byType(ResumeExportPanel));
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ResumeOperationPage(exportId: id, waiting: true),
            ),
          );
        },
      );
      workerState = 'FAILED';
      await tap(tester, 'Create PDF — 2 Credits');
      await tester.ensureVisible(find.text('Create — 2 Credits'));
      await tester.tap(find.text('Create — 2 Credits'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      for (
        var frame = 0;
        frame < 20 &&
            commands.where((command) => command['action'] == 'status').isEmpty;
        frame++
      ) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      final copy = ResumeCopy.of(tester.element(find.byType(Scaffold).last));
      expect(find.text(resumeStatusLabel(copy, 'failed')), findsWidgets);
      final count = commands.where((c) => c['action'] == 'status').length;
      await tester.pump(const Duration(seconds: 9));
      expect(commands.where((c) => c['action'] == 'status').length, count);
      expect(accepted, 1);
      expect(commands.where((c) => c['action'] == 'again'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'confirmed conflict requires explicit current Preview before a new intent',
    (tester) async {
      rejected = 'VERSION_CONFLICT';
      await mount(tester, initial: true);
      await tap(tester, 'Create PDF — 2 Credits');
      await tap(tester, 'Create — 2 Credits');
      expect(await db.setting('resume:$actor:export:$profileId'), isNotNull);
      await tap(tester, 'Close');
      await tap(tester, 'Review rejected request with current Preview');
      expect(await db.setting('resume:$actor:export:$profileId'), isNull);
      expect(observedDocument!['html'], documentHtml);
      expect(accepted, 0);
    },
  );
  testWidgets(
    'Export Again is a new confirmed logical request for the selected historical PDF',
    (tester) async {
      await mount(tester, initial: true);
      await tap(tester, 'Export Again — 2');
      await tap(tester, 'Create — 2 Credits');
      final request =
          commands.singleWhere((c) => c['action'] == 'again')['command'] as Map;
      expect((request['payload'] as Map)['historical_export_id'], jobId);
      expect((request['payload'] as Map)['expected_document_sha256'], 'a' * 64);
      expect(accepted, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('presentation fixture returns a valid SDK RPC response', () async {
    final result = await client.rpc(
      'save_resume_presentation',
      params: {
        'hidden_sections': ['volunteer'],
      },
    );
    expect((result as Map)['section_visibility'], {'volunteer': false});
  });
  testWidgets(
    'history pagination uses only the supplied opaque cursor and creates no export',
    (tester) async {
      paginate = true;
      await mount(tester);
      await tap(tester, 'More exports');
      final history = commands.where((c) => c['action'] == 'history').toList();
      expect((history.last['command'] as Map)['cursor'], jobId);
      expect(accepted, 0);
    },
  );
  testWidgets(
    'explicit hide freezes config command and advances authoritative versions without export',
    (tester) async {
      await mount(tester, initial: true);
      await tester.ensureVisible(find.text('Volunteer Experience'));
      await tester.tap(find.text('Volunteer Experience'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final request =
          commands.singleWhere((c) => c['action'] == 'presentation')['command']
              as Map;
      expect(request['expected_profile_version'], 4);
      expect(request['expected_configuration_version'], 3);
      expect(request['hidden_sections'], ['volunteer']);
      expect(
        commands.map((c) => c['action']).toList(),
        contains('document'),
        reason:
            'Synthetic request sequence ${commands.map((c) => c['action']).toList()}',
      );
      expect(observedDocument!['profile_version'], 5);
      expect(observedDocument!['configuration_version'], 4);
      expect(await db.setting('resume:$actor:export:$profileId'), isNull);
      expect(accepted, 0);
    },
  );
  testWidgets(
    'insufficient Credits keeps frozen intent for retry without creating another key',
    (tester) async {
      rejected = 'CREDIT_INSUFFICIENT';
      creditBalance = 2;
      await mount(tester, initial: true);
      await tap(tester, 'Create PDF — 2 Credits');
      creditBalance = 1;
      await tap(tester, 'Create — 2 Credits');
      expect(find.text('Not enough Credits'), findsOneWidget);
      expect(find.textContaining('currently have 1'), findsOneWidget);
      await tap(tester, 'Cancel');
      final initial =
          jsonDecode((await db.setting('resume:$actor:export:$profileId'))!)
              as Map;
      rejected = null;
      creditBalance = 2;
      await tap(tester, 'Retry the saved request');
      final attempts = commands.where((c) => c['action'] == 'create').toList();
      expect(
        (attempts.last['command'] as Map)['idempotency_key'],
        (initial['command'] as Map)['idempotency_key'],
      );
      expect(accepted, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language quota response shows retry delay and preserves the exact request',
      (tester) async {
        rejected = 'RATE_LIMITED';
        rejectedRetryAfter = 37;
        await mount(tester, language: language, initial: true);
        await tap(
          tester,
          language == 'en' ? 'Create PDF — 2 Credits' : 'إنشاء PDF — رصيدان',
        );
        await tap(
          tester,
          language == 'en' ? 'Create — 2 Credits' : 'إنشاء — رصيدان',
        );
        final strings = AppLocalizations.of(
          tester.element(find.byType(ResumeExportPanel)),
        )!;
        expect(find.text(strings.exportRateLimitedRetry(37)), findsOneWidget);
        final saved =
            jsonDecode((await db.setting('resume:$actor:export:$profileId'))!)
                as Map;
        final attempt = commands.last['command'] as Map;
        expect(
          attempt['idempotency_key'],
          (saved['command'] as Map)['idempotency_key'],
        );
        expect(attempt['payload'], (saved['command'] as Map)['payload']);
        expect(accepted, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language cost-budget rejection uses the safe temporary-unavailable message',
      (tester) async {
        rejected = 'SERVICE_UNAVAILABLE';
        await mount(tester, language: language, initial: true);
        await tap(
          tester,
          language == 'en' ? 'Create PDF — 2 Credits' : 'إنشاء PDF — رصيدان',
        );
        await tap(
          tester,
          language == 'en' ? 'Create — 2 Credits' : 'إنشاء — رصيدان',
        );
        final strings = AppLocalizations.of(
          tester.element(find.byType(ResumeExportPanel)),
        )!;
        expect(find.text(strings.exportTemporarilyUnavailable), findsOneWidget);
        if (language == 'en') {
          expect(
            strings.exportTemporarilyUnavailable,
            'Service is temporarily unavailable. Please try again later.',
          );
        }
        expect(accepted, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language active profile intent explains status without inventing a wait time',
      (tester) async {
        rejected = 'EXPORT_IN_PROGRESS';
        await mount(tester, language: language, initial: true);
        await tap(
          tester,
          language == 'en' ? 'Create PDF — 2 Credits' : 'إنشاء PDF — رصيدان',
        );
        await tap(
          tester,
          language == 'en' ? 'Create — 2 Credits' : 'إنشاء — رصيدان',
        );
        final strings = AppLocalizations.of(
          tester.element(find.byType(ResumeExportPanel)),
        )!;
        expect(find.text(strings.exportInProgress), findsOneWidget);
        expect(accepted, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test(
    'invalid included personal URLs are reported rather than silently omitted',
    () {
      final invalid = CareerProfile.fromJson({
        ...savedProfile,
        'personal': {
          ...(savedProfile['personal'] as Map),
          'portfolio_url': 'javascript:alert(1)',
        },
      });
      expect(
        ResumeDocument.issues(invalid, ResumePresentation(language: 'en')),
        contains('personal.portfolio_url'),
      );
    },
  );
  testWidgets(
    'processing screen polls the same job and exposes the completed download without creating an intent',
    (tester) async {
      await db.setSetting(
        exportDisplayKey(actor, jobId),
        jsonEncode({
          'profile_id': profileId,
          'language': 'en',
          'template': 'resume_ats_en_v1',
        }),
      );
      await tester.pumpWidget(
        app(
          const SizedBox(
            width: 390,
            height: 780,
            child: ResumeOperationPage(exportId: jobId, waiting: true),
          ),
          overrides: [
            supabaseClientProvider.overrideWith((_) async => client),
            databaseProvider.overrideWith((_) async => db),
            firstProfileProvider.overrideWith(
              (_) async => CareerProfile.fromJson(savedProfile),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Your resume is being prepared'), findsOneWidget);
      expect(find.textContaining('English'), findsWidgets);
      expect(find.text('ATS Professional'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      workerState = 'COMPLETED';
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(
        commands.where((c) => c['action'] == 'status').length,
        greaterThanOrEqualTo(2),
      );
      expect(
        commands.where((c) => ['create', 'again'].contains(c['action'])),
        isEmpty,
      );
      final terminalStatusReads = commands
          .where((c) => c['action'] == 'status')
          .length;
      await tester.pump(const Duration(seconds: 30));
      expect(
        commands.where((c) => c['action'] == 'status').length,
        terminalStatusReads,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'account cleanup removes only its own resume journey completion',
    () async {
      const peer = '70000000-0000-4000-8000-000000000099';
      final value = const ResumeJourney(step: 6, complete: true).encode();
      await db.setSetting(journeyKey(actor, profileId), value);
      await db.setSetting(journeyKey(peer, profileId), value);
      await db.clearAccount(actor);
      expect(await db.setting(journeyKey(actor, profileId)), isNull);
      expect(await db.setting(journeyKey(peer, profileId)), value);
    },
  );
  test(
    'frozen display metadata cannot grant entitlement or override job state',
    () async {
      final job = {
        'id': jobId,
        'profile_id': profileId,
        'state': 'QUEUED',
        'download_eligible': false,
      };
      await db.setSetting(
        exportDisplayKey(actor, jobId),
        jsonEncode({
          'profile_id': profileId,
          'language': 'ar',
          'template': 'resume_ats_ar_v1',
          'state': 'COMPLETED',
          'download_eligible': true,
          'page_count': 20,
        }),
      );
      final shown = await ResumeExportService(
        client,
      ).withDisplay(job, db.setting);
      expect(shown['language'], 'ar');
      expect(shown['state'], 'QUEUED');
      expect(shown['download_eligible'], false);
      expect(shown['page_count'], isNull);
      await db.setSetting(
        exportDisplayKey(actor, jobId),
        jsonEncode({
          'profile_id': 'foreign',
          'language': 'ar',
          'template': 'resume_ats_ar_v1',
        }),
      );
      expect(
        (await ResumeExportService(
          client,
        ).withDisplay(job, db.setting))['language'],
        isNull,
      );
      await db.removeSetting(exportDisplayKey(actor, jobId));
      expect(
        await ResumeExportService(client).withDisplay(job, db.setting),
        job,
      );
      expect(accepted, 0);
    },
  );
}
