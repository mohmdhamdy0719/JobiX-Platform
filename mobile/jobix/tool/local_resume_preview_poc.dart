// ignore_for_file: avoid_relative_lib_imports

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../lib/core/design/tokens.dart';
import '../lib/core/providers.dart';
import '../lib/features/resume/resume_document.dart';
import '../lib/features/resume/resume_preview_page.dart';
import '../lib/l10n/app_localizations.dart';

/// Separate entry point for an offline, synthetic-data-only Preview prototype.
/// This file is not registered by the normal app router.
void main() {
  if (!kDebugMode) {
    throw UnsupportedError(
      'Local Preview POC is available in debug builds only',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      // The reused Preview widget observes session changes. An empty local
      // stream keeps this prototype independent from Supabase and credentials.
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => const Stream<Session?>.empty(),
        ),
      ],
      child: const LocalResumePreviewPocApp(),
    ),
  );
}

class LocalPreviewFixture {
  const LocalPreviewFixture({
    required this.id,
    required this.label,
    required this.language,
    required this.name,
    required this.role,
    required this.summary,
    required this.experienceCount,
    required this.linesPerExperience,
    required this.mixed,
  });

  final String id;
  final String label;
  final String language;
  final String name;
  final String role;
  final String summary;
  final int experienceCount;
  final int linesPerExperience;
  final bool mixed;

  static const all = [
    LocalPreviewFixture(
      id: 'english',
      label: 'English · short · LTR',
      language: 'en',
      name: 'Alex Sample — Synthetic Profile',
      role: 'Project Coordinator',
      summary: 'Synthetic content for local Preview inspection.',
      experienceCount: 1,
      linesPerExperience: 3,
      mixed: false,
    ),
    LocalPreviewFixture(
      id: 'arabic',
      label: 'العربية · قصير · RTL',
      language: 'ar',
      name: 'أحمد مثال — ملف تجريبي',
      role: 'منسق مشروعات',
      summary: 'هذا محتوى اصطناعي لاختبار المعاينة محليًا.',
      experienceCount: 1,
      linesPerExperience: 3,
      mixed: false,
    ),
    LocalPreviewFixture(
      id: 'mixed',
      label: 'Mixed Arabic + English · LTR',
      language: 'en',
      name: 'Alex مثال — Synthetic Profile',
      role: 'Product Coordinator · منسق منتجات',
      summary:
          'Synthetic bilingual sample. تعاونت مع فرق التصميم والتحليل لإطلاق تحديثات المنتج.',
      experienceCount: 2,
      linesPerExperience: 4,
      mixed: true,
    ),
    LocalPreviewFixture(
      id: 'long-english',
      label: 'English · long · multiple pages',
      language: 'en',
      name: 'Alex Sample — Extended Synthetic Profile',
      role: 'Program Manager',
      summary:
          'A deliberately long synthetic summary for checking page breaks and readable text flow.',
      experienceCount: 8,
      linesPerExperience: 12,
      mixed: false,
    ),
    LocalPreviewFixture(
      id: 'long-arabic',
      label: 'العربية · طويل · صفحات متعددة',
      language: 'ar',
      name: 'أحمد مثال — ملف تجريبي موسع',
      role: 'مدير برامج',
      summary: 'ملخص اصطناعي طويل لاختبار تقسيم الصفحات ووضوح النصوص العربية.',
      experienceCount: 8,
      linesPerExperience: 12,
      mixed: false,
    ),
  ];

  Map<String, dynamic> source() {
    final ar = language == 'ar';
    return {
      'profile': {
        'profile_id': 'local-preview-poc-only',
        'profile_version': 1,
        'completeness_percent': 45,
        'completeness_algorithm_version': 'local-poc-fixture',
        'personal': {
          'full_name': name,
          'email': 'synthetic@example.invalid',
          'phone': '+20 100 000 0000',
          'city': ar ? 'مدينة تجريبية' : 'Sample City',
          'country': ar ? 'بلد تجريبي' : 'Sample Country',
        },
        'summary': summary,
        'target_role': role,
        'experiences': [
          for (var index = 0; index < experienceCount; index++)
            {
              'id': 'local-poc-experience-$index',
              'job_title': ar ? 'منسق فريق $index' : 'Team Coordinator $index',
              'company': ar ? 'مؤسسة تجريبية $index' : 'Sample Company $index',
              'location': ar ? 'مدينة تجريبية' : 'Sample City',
              'start_month': '2021-01',
              'end_month': '2024-12',
              'is_current': false,
              'description': List.generate(
                linesPerExperience,
                (line) => ar
                    ? '- سطر تجريبي $index.$line: تنسيق العمل وتوثيق النتائج ومراجعة التفاصيل.'
                    : '- Synthetic line $index.$line: coordinated work and documented outcomes for review.',
              ).join('\n'),
            },
        ],
        'volunteer_experiences': [],
        'education': [],
        'certifications': [],
        'achievements': [],
        'projects': [],
        'skills': [],
        'languages': [],
      },
      'configuration': {
        'language': language,
        'version': 0,
        'section_visibility': <String, bool>{},
      },
      'links': const <Map<String, dynamic>>[],
    };
  }
}

Map<String, dynamic> prepareLocalPreviewDocument(
  LocalPreviewFixture fixture, {
  required String latinFontBase64,
  required String arabicFontBase64,
}) {
  final source = fixture.source();
  final document = ResumeDocument.prepare(
    source,
    latinFontBase64,
    arabicFontBase64,
  );
  return {
    ...document,
    'language': fixture.language,
    'configuration': source['configuration'],
  };
}

class _LocalPreviewFonts {
  const _LocalPreviewFonts(this.latin, this.arabic);
  final String latin;
  final String arabic;

  static final Future<_LocalPreviewFonts> load = () async {
    final latin = await rootBundle.load('assets/fonts/Inter.ttf');
    final arabic = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    );
    return _LocalPreviewFonts(
      base64Encode(
        latin.buffer.asUint8List(latin.offsetInBytes, latin.lengthInBytes),
      ),
      base64Encode(
        arabic.buffer.asUint8List(arabic.offsetInBytes, arabic.lengthInBytes),
      ),
    );
  }();
}

class LocalResumePreviewPocApp extends StatefulWidget {
  const LocalResumePreviewPocApp({super.key});

  @override
  State<LocalResumePreviewPocApp> createState() =>
      _LocalResumePreviewPocAppState();
}

class _LocalResumePreviewPocAppState extends State<LocalResumePreviewPocApp> {
  String language = 'en';

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: foundationTheme(languageCode: language),
    home: _LocalPreviewPicker(
      onLanguageChanged: (value) => setState(() => language = value),
    ),
  );
}

class _LocalPreviewPicker extends StatefulWidget {
  const _LocalPreviewPicker({required this.onLanguageChanged});
  final ValueChanged<String> onLanguageChanged;

  @override
  State<_LocalPreviewPicker> createState() => _LocalPreviewPickerState();
}

class _LocalPreviewPickerState extends State<_LocalPreviewPicker> {
  String selected = LocalPreviewFixture.all.first.id;
  bool loading = false;
  String? error;

  LocalPreviewFixture get fixture =>
      LocalPreviewFixture.all.firstWhere((item) => item.id == selected);

  Future<void> openPreview() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final fonts = await _LocalPreviewFonts.load;
      final document = prepareLocalPreviewDocument(
        fixture,
        latinFontBase64: fonts.latin,
        arabicFontBase64: fonts.arabic,
      );
      if (!mounted) return;
      widget.onLanguageChanged(fixture.language);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ResumePreviewPage(
            document: document,
            onExport: (_) async => null,
            exportEnabled: false,
            ownerId: 'local-preview-poc',
            onEditProfile: () {},
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Local Preview could not be prepared.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'معاينة محلية تجريبية' : 'Local Preview POC'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Development-only • synthetic data • no backend, Credits, '
            'storage, or export calls',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: selected,
            decoration: InputDecoration(
              labelText: ar ? 'بيانات الاختبار' : 'Synthetic fixture',
            ),
            items: [
              for (final item in LocalPreviewFixture.all)
                DropdownMenuItem(value: item.id, child: Text(item.label)),
            ],
            onChanged: loading
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => selected = value);
                    widget.onLanguageChanged(
                      LocalPreviewFixture.all
                          .firstWhere((item) => item.id == value)
                          .language,
                    );
                  },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: loading ? null : openPreview,
            child: Text(
              loading
                  ? (ar ? 'جارٍ تجهيز المعاينة…' : 'Preparing Preview…')
                  : (ar ? 'فتح المعاينة المحلية' : 'Open local Preview'),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
