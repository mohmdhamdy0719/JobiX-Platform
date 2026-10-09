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
import 'package:jobix/features/resume/resume_document.dart';
import 'package:jobix/features/resume/resume_export_panel.dart';
import 'package:jobix/features/resume/resume_render.dart';
import 'package:jobix/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/production_fonts.dart';

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
        '$language default-off panel acquires no client or database',
        (tester) async {
          await tester.pumpWidget(
            app(
              ResumeExportPanel(
                profileId: profileId,
                canPrepare: true,
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
          expect(find.byType(TextButton), findsNothing);
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
  bool paginate = false;
  bool expiredDownload = true;
  bool loseResponse = false;
  String workerState = 'QUEUED';
  String? rejected;
  int accepted = 0;
  Map<String, dynamic>? observedDocument;

  Future<void> mount(
    WidgetTester tester, {
    String language = 'en',
    bool initial = false,
    bool includeCompleted = false,
  }) async {
    await tester.pumpWidget(
      app(
        ResumeExportPanel(
          profileId: profileId,
          canPrepare: true,
          initialDocument: initial ? document : null,
          showDocument: (value) async {
            observedDocument = value;
          },
        ),
        language: language,
        overrides: [
          supabaseClientProvider.overrideWith((_) async => client),
          databaseProvider.overrideWith((_) async => db),
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
    paginate = false;
    expiredDownload = true;
    prepared = {
      ...document,
      'configuration': {'section_visibility': <String, dynamic>{}},
    };
    client = SupabaseClient(
      'https://synthetic.example.invalid',
      'synthetic-publishable',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
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
                'error': {'code': rejected},
              }),
              503,
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
          result = {'state': workerState};
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
      await mount(tester, initial: true);
      await tap(tester, 'Create PDF — 2 Credits');
      await tap(tester, 'Cancel');
      expect(accepted, 0);
      expect(await db.setting('resume:$actor:export:$profileId'), isNull);
      expect(commands.where((c) => c['action'] == 'create'), isEmpty);
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
    await tap(tester, 'Reconcile saved export request');
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
        await mount(tester, initial: true);
        await tap(tester, 'Download — free');
        expect(saved!['bytes'], fixture.bytes);
        expect(saved!['name'], '$jobId.pdf');
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
  testWidgets('worker retry progress reaches completion on the same operation', (
    tester,
  ) async {
    await mount(tester, initial: true);
    await tap(tester, 'Create PDF — 2 Credits');
    await tap(tester, 'Create — 2 Credits');
    workerState = 'RETRYABLE_FAILURE';
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('RETRYABLE_FAILURE'), findsWidgets);
    workerState = 'COMPLETED';
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('COMPLETED'), findsWidgets);
    expect(accepted, 1);
    final states = commands.where((c) => c['action'] == 'status');
    expect(states.length, greaterThanOrEqualTo(2));
    expect(states.every((c) => (c['command'] as Map)['export_id'] == jobId), true);
    expect(await db.setting('resume:$actor:export:$profileId'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('terminal worker failure is visible without automatic new export', (
    tester,
  ) async {
    await mount(tester, initial: true);
    await tap(tester, 'Create PDF — 2 Credits');
    await tap(tester, 'Create — 2 Credits');
    workerState = 'FAILED';
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('FAILED'), findsWidgets);
    final count = commands.where((c) => c['action'] == 'status').length;
    await tester.pump(const Duration(seconds: 9));
    expect(commands.where((c) => c['action'] == 'status').length, count);
    expect(accepted, 1);
    expect(commands.where((c) => c['action'] == 'again'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'confirmed conflict requires explicit current Preview before a new intent',
    (tester) async {
      rejected = 'VERSION_CONFLICT';
      await mount(tester, initial: true);
      await tap(tester, 'Create PDF — 2 Credits');
      await tap(tester, 'Create — 2 Credits');
      expect(await db.setting('resume:$actor:export:$profileId'), isNotNull);
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
      await mount(tester, initial: true);
      await tap(tester, 'Create PDF — 2 Credits');
      await tap(tester, 'Create — 2 Credits');
      final initial =
          jsonDecode((await db.setting('resume:$actor:export:$profileId'))!)
              as Map;
      rejected = null;
      await tap(tester, 'Reconcile saved export request');
      final attempts = commands.where((c) => c['action'] == 'create').toList();
      expect(
        (attempts.last['command'] as Map)['idempotency_key'],
        (initial['command'] as Map)['idempotency_key'],
      );
      expect(accepted, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
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
}
