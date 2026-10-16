import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/navigation/router.dart';
import 'package:jobix/features/boot/startup.dart';
import 'package:jobix/features/onboarding/research_context.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/resume/resume_render.dart';
import 'package:jobix/features/resume/resume_preview_page.dart';

void main() {
  test('completed first launch without retained answers routes to Auth', () {
    final progress = ResearchProgress.decode(
      const ResearchProgress(
        onboardingDone: true,
        firstLaunchComplete: true,
      ).encode(),
    );
    expect(progress.complete, isFalse);
    expect(progress.experienceComplete, isTrue);
    for (final route in ['/onboarding', '/research', '/home']) {
      expect(
        sliceRedirect(
          startup: StartupState.signedOut,
          firstEntry: false,
          entryLoading: false,
          recovery: false,
          path: route,
          progress: progress,
        ),
        '/auth',
      );
    }
  });
  test('fresh install still requires ordered research', () {
    expect(
      sliceRedirect(
        startup: StartupState.signedOut,
        firstEntry: false,
        entryLoading: false,
        recovery: false,
        path: '/auth',
        progress: const ResearchProgress(onboardingDone: true),
      ),
      '/research',
    );
  });
  for (final language in ['en', 'ar']) {
    test('canonical $language render preserves content and escapes HTML', () {
      final longText = List.filled(
        100,
        'Long authentic source text.',
      ).join('\n');
      final profile = CareerProfile(
        id: 'same-profile',
        version: 7,
        personal: const {
          'full_name': '<script>alert(1)</script>',
          'email': 'a@example.invalid',
        },
        summary: longText,
      );
      final result = ResumeRender.html(
        profile: profile,
        language: language,
        latinFontBase64: '',
        arabicFontBase64: '',
      );
      expect(result, contains(language == 'ar' ? 'dir="rtl"' : 'dir="ltr"'));
      expect(result, contains('resume_ats_${language}_v1'));
      expect(result, contains('&lt;script&gt;'));
      expect(result, isNot(contains('<script>')));
      expect(
        RegExp('Long authentic source text.').allMatches(result),
        hasLength(100),
      );
      expect(result, contains('size:A4'));
      expect(result, contains('break-after:avoid;page-break-after:avoid'));
      expect(result, contains('break-inside:avoid;page-break-inside:avoid'));
      expect(result, contains('margin:3mm 0 1mm;break-after:avoid'));
      expect(
        result,
        contains('section{break-inside:avoid;page-break-inside:avoid}'),
      );
      expect(
        result,
        contains('.resume-final-sections{display:inline-block;width:100%'),
      );
      expect(result, contains('article{margin-bottom:2.5mm}'));
      expect(result, contains('.entry-lead{display:inline-block;width:100%'));
      expect(
        result,
        isNot(contains('article{margin-bottom:4mm;break-inside:avoid')),
      );
      expect(ResumePreviewPage.paginationScript, contains('column-fill:auto'));
      expect(ResumePreviewPage.paginationScript, contains('Math.ceil'));
      expect(ResumePreviewPage.paginationScript, isNot(contains('Math.round')));
      expect(
        ResumePreviewPage.paginationScript,
        contains('li{break-inside:avoid;page-break-inside:avoid}'),
      );
      expect(result, contains('jobix-profile-version" content="7'));
      expect(result, isNot(contains('overflow:hidden')));
      expect(profile.id, 'same-profile');
    });
  }
}
