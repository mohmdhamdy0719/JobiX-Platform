import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/features/resume/resume_document.dart';
import 'package:jobix/features/resume/resume_layout.dart';
import 'package:jobix/features/resume/resume_layout_page.dart';
import 'package:jobix/features/resume/resume_layout_repository.dart';
import 'package:jobix/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tool/local_resume_preview_poc.dart';
import 'support/production_fonts.dart';

void main() {
  setUpAll(loadProductionFonts);
  test(
    'stable layout permutation, toggle, legacy mapping, and reset defaults',
    () {
      final original = ResumeLayout();
      final changed = original.reorder(9, 0).toggle('summary', false);
      expect(changed.order.first, 'language');
      expect(changed.hidden, {'summary'});
      expect(original.hidden, isEmpty);
      expect(ResumeLayout().fingerprint, original.fingerprint);
      expect(() => ResumeLayout(order: ['summary']), throwsArgumentError);
      expect(
        () => ResumeLayout(order: List.filled(10, 'summary')),
        throwsArgumentError,
      );
      expect(
        ResumeLayout.fromConfiguration({
          'section_order': [...ResumeLayout.sectionKeys]..remove('target_role'),
        }).order,
        ResumeLayout.sectionKeys,
      );
    },
  );

  test(
    'frozen layout save retries same key; unknown outcomes and accounts stay isolated',
    () async {
      configureSqlCipher(
        testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var actor = 'one';
      var timeout = true;
      final commands = <Map<String, dynamic>>[];
      final layout = ResumeLayout().reorder(8, 0).toggle('education', false);
      ResumeLayoutRepository store(String user) => ResumeLayoutRepository(
        database: db,
        user: user,
        profileId: 'profile',
        isCurrentUser: () => actor == user,
        saveRemote: (request) async {
          commands.add(request);
          if (timeout) {
            throw const SocketException('synthetic timeout after ACK');
          }
          return {
            'profile_id': 'profile',
            'version': 2,
            'language': 'en',
            'section_order': request['section_order'],
            'section_visibility': layout.visibility,
            'render_config_version': ResumeLayout.renderVersion,
            'template_version': ResumeLayout.templateVersion,
          };
        },
      );
      final one = store('one');
      await expectLater(
        one.save(
          layout: layout,
          profileVersion: 7,
          configurationVersion: 1,
          language: 'en',
        ),
        throwsA(isA<SocketException>()),
      );
      final frozen = await one.pending();
      expect(frozen, isNotNull);
      actor = 'two';
      expect(await store('two').pending(), isNull);
      await expectLater(one.pending(), throwsA(isA<ResumeLayoutSaveFailure>()));
      actor = 'one';
      timeout = false;
      await one.save(
        layout: layout,
        profileVersion: 8,
        configurationVersion: 2,
        language: 'ar',
      );
      expect(commands.last, commands.first);
      expect(await one.pending(), isNull);
      // Account cleanup removes this namespace without affecting the other user.
      await db.setSetting(one.key, jsonEncode(frozen));
      await db.setSetting('resume:two:layout:profile', '{}');
      await db.clearAccount('one');
      expect(await db.setting(one.key), isNull);
      expect(await db.setting('resume:two:layout:profile'), '{}');
    },
  );

  test(
    'missing RPC and definite conflicts do not leave an unrecoverable save',
    () async {
      configureSqlCipher(
        testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      for (final (failure, keepRequest) in <(PostgrestException, bool)>[
        (
          const PostgrestException(message: 'RPC absent', code: 'PGRST202'),
          true,
        ),
        (
          const PostgrestException(
            message: 'VERSION_CONFLICT',
            code: 'P0001',
          ),
          false,
        ),
      ]) {
        final store = ResumeLayoutRepository(
          database: db,
          user: 'one',
          profileId: 'profile',
          isCurrentUser: () => true,
          saveRemote: (_) async => throw failure,
        );
        await expectLater(
          store.save(
            layout: ResumeLayout(),
            profileVersion: 1,
            configurationVersion: 0,
            language: 'en',
          ),
          throwsA(isA<ResumeLayoutSaveFailure>()),
        );
        expect(await store.pending() != null, keepRequest);
      }
    },
  );

  for (final locale in ['en', 'ar']) {
    testWidgets(
      '$locale layout editor stages switches/reorder, Reset, Done and Back',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final saved = <ResumeLayout>[];
        final nav = GlobalKey<NavigatorState>();
        final screen = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: screen,
            child: MaterialApp(
              navigatorKey: nav,
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: foundationTheme(),
              home: const Scaffold(body: Text('export')),
            ),
          ),
        );
        void open() => nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => ResumeLayoutPage(
              initial: ResumeLayout(),
              onSave: (layout) async => saved.add(layout),
              onReload: () async => ResumeLayout(),
              hasPending: () async => false,
            ),
          ),
        );
        open();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('visible-summary')));
        await tester.pumpAndSettle();
        expect(saved, isEmpty);
        await tester.drag(
          find.descendant(
            of: find.byKey(const ValueKey('layout-summary')),
            matching: find.byIcon(Icons.drag_indicator),
          ),
          const Offset(0, 155),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('layout-summary'))).dy,
          greaterThan(
            tester
                .getTopLeft(find.byKey(const ValueKey('layout-target_role')))
                .dy,
          ),
        );
        await tester.runAsync(() async {
          final image =
              await (screen.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/native-checks/resume-layout-$locale.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.text(locale == 'ar' ? 'إعادة ضبط' : 'Reset'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Switch>(find.byKey(const ValueKey('visible-summary')))
              .value,
          isTrue,
        );
        await tester.tap(find.byKey(const ValueKey('visible-target_role')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'ar' ? 'تم' : 'Done'));
        await tester.pumpAndSettle();
        expect(saved.single.hidden, {'target_role'});
        expect(saved.single.order, ResumeLayout.sectionKeys);
        expect(find.text('export'), findsOneWidget);
        open();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('visible-summary')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButtonIcon));
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'ar' ? 'البقاء' : 'Stay'));
        await tester.pumpAndSettle();
        expect(find.byType(ResumeLayoutPage), findsOneWidget);
        await tester.tap(find.byType(BackButtonIcon));
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'ar' ? 'تجاهل' : 'Discard'));
        await tester.pumpAndSettle();
        expect(find.text('export'), findsOneWidget);
        expect(saved, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    test(
      '$locale native renderer matches actual server canonicalizer for reordered/hidden layout',
      () async {
        final source = LocalPreviewFixture.all.first.source();
        final profile = source['profile'] as Map;
        profile['summary'] = 'SUMMARY_LAYOUT_MARKER';
        profile['target_role'] = 'TARGET_HIDDEN_MARKER';
        profile['skills'] = [
          {'id': 'synthetic-skill', 'name': 'SKILL_LAYOUT_MARKER'},
        ];
        final config = Map<String, dynamic>.from(
          source['configuration'] as Map,
        );
        final layout = ResumeLayout()
            .reorder(8, 0)
            .toggle('education', false)
            .toggle('target_role', false);
        source['configuration'] = {
          ...config,
          'language': locale,
          'section_order': layout.order,
          'section_visibility': layout.visibility,
          'render_config_version': ResumeLayout.renderVersion,
          'template_version': ResumeLayout.templateVersion,
        };
        final latin = base64Encode(
          await File('assets/fonts/Inter.ttf').readAsBytes(),
        );
        final arabic = base64Encode(
          await File(
            'assets/fonts/IBMPlexSansArabic-Regular.ttf',
          ).readAsBytes(),
        );
        final local = ResumeDocument.prepare(source, latin, arabic);
        // This launches the real Node canonicalizer and its real standalone Dart
        // CLI. No mocks, networking, exports, database, or user data.
        final child = await Process.start(
          Platform.environment['JOBIX_TEST_NODE'] ?? 'node',
          [
            '--input-type=module',
            '-e',
            "import {Canonicalizer,sha256} from './backend/pdf/document.mjs';"
                "let text='';for await(const chunk of process.stdin)text+=chunk;"
                "const source=JSON.parse(text);"
                "const doc=await new Canonicalizer().prepare({source,source_sha256:sha256(text)});"
                "process.stdout.write(JSON.stringify(doc));",
          ],
        );
        child.stdin.write(jsonEncode(source));
        await child.stdin.close();
        final out = child.stdout.transform(utf8.decoder).join();
        final err = child.stderr.transform(utf8.decoder).join();
        final code = await child.exitCode;
        expect(code, 0, reason: await err);
        final server = jsonDecode(await out) as Map;
        expect(server['html'], local['html']);
        expect(server['issues'], local['issues']);
        expect(server['document_sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
        expect((server['asset_manifest'] as Map)['template_version'], 3);
        final html = local['html'] as String;
        expect(html, contains('dir="${locale == 'ar' ? 'rtl' : 'ltr'}"'));
        expect(html, contains('jobix-layout-version'));
        expect(
          html.indexOf('<h2>${locale == 'ar' ? 'المهارات' : 'Skills'}'),
          lessThan(
            html.indexOf(
              '<h2>${locale == 'ar' ? 'الملخص المهني' : 'Professional Summary'}',
            ),
          ),
        );
        expect(
          html,
          isNot(contains('<h2>${locale == 'ar' ? 'التعليم' : 'Education'}')),
        );
        expect(
          html,
          isNot(
            contains(
              '<h2>${locale == 'ar' ? 'الوظيفة المستهدفة' : 'Target Role'}',
            ),
          ),
        );
        // Real local Chromium output, not a PDF mock or screenshot.
        final print = await Process.start('python3', [
          'backend/pdf/test/print_fixture.py',
        ]);
        print.stdin.write(html);
        await print.stdin.close();
        final printed = print.stdout.transform(utf8.decoder).join();
        final printError = print.stderr.transform(utf8.decoder).join();
        expect(await print.exitCode, 0, reason: await printError);
        final result = jsonDecode(await printed) as Map;
        final temporary = await Directory.systemTemp.createTemp(
          'jobix-layout-print-',
        );
        try {
          final pdf = File('${temporary.path}/layout.pdf');
          await pdf.writeAsBytes(base64Decode(result['pdf'] as String));
          final info = await Process.run('pdfinfo', [pdf.path]);
          expect(info.exitCode, 0);
          expect(info.stdout.toString(), contains('Pages:'));
          final text = await Process.run('pdftotext', ['-raw', pdf.path, '-']);
          expect(text.exitCode, 0);
          final visible = text.stdout.toString();
          expect(visible, contains('SKILL_LAYOUT_MARKER'));
          expect(visible, contains('SUMMARY_LAYOUT_MARKER'));
          expect(
            visible.indexOf('SKILL_LAYOUT_MARKER'),
            lessThan(visible.indexOf('SUMMARY_LAYOUT_MARKER')),
          );
          expect(visible, isNot(contains('TARGET_HIDDEN_MARKER')));
        } finally {
          await temporary.delete(recursive: true);
        }
      },
    );
  }
}
