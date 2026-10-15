import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/resume/resume_document.dart';

import '../tool/local_resume_preview_poc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'synthetic local fixtures match the existing server preparation HTML',
    () async {
      final root = Directory.current.path;
      final latinFont = base64Encode(
        File('$root/assets/fonts/Inter.ttf').readAsBytesSync(),
      );
      final arabicFont = base64Encode(
        File(
          '$root/assets/fonts/IBMPlexSansArabic-Regular.ttf',
        ).readAsBytesSync(),
      );
      final outputPath =
          Platform.environment['JOBIX_LOCAL_PREVIEW_POC_ARTIFACT_DIR'];
      Directory? outputDirectory;
      if (outputPath != null) {
        outputDirectory = Directory(outputPath);
        outputDirectory.createSync(recursive: true);
      }

      for (final fixture in LocalPreviewFixture.all) {
        final source = fixture.source();
        final local = prepareLocalPreviewDocument(
          fixture,
          latinFontBase64: latinFont,
          arabicFontBase64: arabicFont,
        );
        expect(local['issues'], isEmpty, reason: fixture.id);
        final canonical = ResumeDocument.prepare(source, latinFont, arabicFont);
        expect(local['html'], canonical['html'], reason: fixture.id);
        expect(
          local['html'],
          contains(
            'lang="${fixture.language}" dir="${fixture.language == 'ar' ? 'rtl' : 'ltr'}"',
          ),
          reason: fixture.id,
        );
        expect(
          local['html'],
          contains("default-src 'none'"),
          reason: fixture.id,
        );
        expect(local['html'], isNot(contains('http://')), reason: fixture.id);
        expect(local['html'], isNot(contains('https://')), reason: fixture.id);
        if (outputDirectory != null) {
          File(
            '${outputDirectory.path}/${fixture.id}.json',
          ).writeAsStringSync(jsonEncode(source));
          File(
            '${outputDirectory.path}/${fixture.id}.html',
          ).writeAsStringSync(local['html'] as String);
        }
      }
    },
  );

  test('fixtures cover bilingual and multi-page synthetic content', () {
    final mixed = LocalPreviewFixture.all.firstWhere(
      (fixture) => fixture.id == 'mixed',
    );
    final longEnglish = LocalPreviewFixture.all.firstWhere(
      (fixture) => fixture.id == 'long-english',
    );
    final longArabic = LocalPreviewFixture.all.firstWhere(
      (fixture) => fixture.id == 'long-arabic',
    );

    final mixedProfile = mixed.source()['profile'] as Map;
    final mixedPersonal = mixedProfile['personal'] as Map;
    expect(mixedPersonal['full_name'], contains('مثال'));
    expect(mixedProfile['summary'], contains('تعاونت'));
    expect(longEnglish.experienceCount, greaterThan(1));
    expect(longArabic.experienceCount, greaterThan(1));
    expect(longEnglish.linesPerExperience, greaterThan(8));
    expect(longArabic.linesPerExperience, greaterThan(8));
  });

  test('the POC invokes the shared ResumeDocument preparation contract', () {
    expect(ResumeDocument.bundle, 'jobix-resume-export-1');
    expect(LocalPreviewFixture.all.map((fixture) => fixture.language).toSet(), {
      'en',
      'ar',
    });
  });

  test(
    'the existing packaged fonts are available to the local entry point',
    () async {
      final latin = await rootBundle.load('assets/fonts/Inter.ttf');
      final arabic = await rootBundle.load(
        'assets/fonts/IBMPlexSansArabic-Regular.ttf',
      );
      expect(latin.lengthInBytes, greaterThan(100000));
      expect(arabic.lengthInBytes, greaterThan(100000));
    },
  );
}
