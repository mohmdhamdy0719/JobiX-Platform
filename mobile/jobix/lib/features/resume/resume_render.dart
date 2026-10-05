import 'dart:convert';
import '../career_profile/career_profile.dart';
import '../career_profile/profile_sections.dart';

/// Immutable render-package contract. Preview and the future Chromium worker
/// consume this same HTML, not a second PDF-specific layout or screenshot.
class ResumeRender {
  static const modelVersion = 1;
  static const templateVersion = 1;
  static String html({
    required CareerProfile profile,
    required String language,
    required String latinFontBase64,
    required String arabicFontBase64,
    List<Map<String, dynamic>> additionalLinks = const [],
  }) {
    if (!['en', 'ar'].contains(language)) {
      throw ArgumentError('Unsupported language');
    }
    if (utf8.encode(profile.encode()).length > 200000) {
      throw StateError('RESUME_SOURCE_TOO_LARGE');
    }
    final ar = language == 'ar';
    String e(String? text) => const HtmlEscape().convert(text ?? '');
    String bi(String? text) => '<bdi>${e(text)}</bdi>';
    String label(String en, String arabic) => ar ? arabic : en;
    String lines(String text) => text
        .split('\n')
        .map(
          (line) => line.trim().startsWith(RegExp(r'[-•]'))
              ? '<li>${bi(line.trim().substring(1).trim())}</li>'
              : '<p>${bi(line)}</p>',
        )
        .join();
    final sections = <String>[];
    void section(String title, String body) {
      if (body.trim().isNotEmpty) {
        sections.add('<section><h2>${e(title)}</h2>$body</section>');
      }
    }

    section(
      label('Professional Summary', 'الملخص المهني'),
      profile.summary.trim().isEmpty ? '' : lines(profile.summary),
    );
    final labels = {
      EntitySection.experience: label('Work Experience', 'الخبرة المهنية'),
      EntitySection.education: label('Education', 'التعليم'),
      EntitySection.certification: label('Certifications', 'الشهادات'),
      EntitySection.achievement: label('Achievements', 'الإنجازات'),
      EntitySection.project: label('Projects', 'المشروعات'),
      EntitySection.skill: label('Skills', 'المهارات'),
      EntitySection.language: label('Languages', 'اللغات'),
    };
    for (final type in EntitySection.values) {
      final content = StringBuffer();
      for (final item in profile.of(type)) {
        final title = switch (type) {
          EntitySection.experience => item.text('job_title'),
          EntitySection.education => item.text('degree'),
          EntitySection.achievement => item.text('title'),
          _ => item.text('name'),
        };
        final metadata = [
          for (final field in [
            'company',
            'institution',
            'field_of_study',
            'issuer',
            'role',
            'location',
          ])
            if (item.text(field).isNotEmpty) bi(item.text(field)),
        ];
        final dates = [
          for (final field in [
            'start_month',
            'issue_month',
            'achieved_month',
            'project_month',
          ])
            if (item.text(field).isNotEmpty) bi(item.text(field)),
          if (item.flag('is_current'))
            e(label('Present', 'حتى الآن'))
          else if (item.text('end_month').isNotEmpty)
            bi(item.text('end_month')),
          if (item.text('expiry_month').isNotEmpty)
            '${e(label('Expires', 'تاريخ الانتهاء'))}: ${bi(item.text('expiry_month'))}',
        ].join(' — ');
        if (type == EntitySection.language) {
          const english = [
            'Basic',
            'Conversational',
            'Professional',
            'Fluent',
            'Native',
          ];
          const arabic = ['مبتدئ', 'محادثة', 'مهني', 'بطلاقة', 'اللغة الأم'];
          final index = proficiencies.indexOf(item.text('proficiency'));
          if (index >= 0) metadata.add(e((ar ? arabic : english)[index]));
        }
        final url = normalizeUrl(item.text('url'));
        content.write(
          '<article><header><h3>${bi(title)}</h3>'
          '${dates.isEmpty ? '' : '<span class="dates">$dates</span>'}</header>'
          '${metadata.isEmpty ? '' : '<p class="meta">${metadata.join(' · ')}</p>'}'
          '${lines(item.text('description'))}'
          '${item.text('credential_id').isEmpty ? '' : '<p>${bi(item.text('credential_id'))}</p>'}'
          '${item.list('technologies').isEmpty ? '' : '<p>${item.list('technologies').map(bi).join(' · ')}</p>'}'
          '${url == null || url.isEmpty ? '' : '<p><a href="${e(url)}">${bi(url)}</a></p>'}</article>',
        );
      }
      section(labels[type]!, content.toString());
    }
    final contacts = [
      for (final key in [
        'email',
        'phone',
        'city',
        'country',
        'linkedin_url',
        'github_url',
        'portfolio_url',
      ])
        if ((profile.personal[key] ?? '').trim().isNotEmpty)
          bi(profile.personal[key]),
      for (final link in additionalLinks)
        if (normalizeUrl(link['url'] as String? ?? '') case final String url)
          if (url.isNotEmpty)
            '<a href="${e(url)}">${bi(link['label'] as String?)}: ${bi(url)}</a>',
    ];
    return '''<!doctype html><html lang="$language" dir="${ar ? 'rtl' : 'ltr'}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; font-src data:; img-src data:">
<meta name="jobix-render-version" content="$modelVersion">
<meta name="jobix-template" content="resume_ats_${language}_v1">
<meta name="jobix-profile-version" content="${profile.version}">
<style>
@font-face{font-family:Inter;src:url(data:font/ttf;base64,$latinFontBase64)}
@font-face{font-family:Plex;src:url(data:font/ttf;base64,$arabicFontBase64)}
@page{size:A4;margin:18mm}
*{box-sizing:border-box}html{background:#e8edf4}body{background:white;color:#152237;
font-family:${ar ? 'Plex,Inter' : 'Inter,Plex'},sans-serif;font-size:11pt;line-height:${ar ? '1.8' : '1.55'};
width:210mm;min-height:297mm;margin:16px auto;padding:18mm;overflow-wrap:anywhere}
h1{font-size:24pt;margin:0 0 5mm;font-weight:700}h2{font-size:13pt;border-bottom:1pt solid #334155;
padding-bottom:2mm;margin:7mm 0 3mm;break-after:avoid}h3{font-size:11.5pt;margin:0}
article{margin-bottom:4mm}article header{display:flex;flex-wrap:wrap;justify-content:space-between;gap:2mm}
p{margin:1mm 0;white-space:pre-wrap}.contact{font-size:9.5pt}.meta,.dates{color:#43516a}
.dates{font-size:9.5pt}a{color:inherit;text-decoration:none}bdi{unicode-bidi:plaintext}
li{margin-inline-start:5mm;padding-inline-start:1mm;list-style-position:outside}
@media print{html{background:white}body{width:auto;min-height:0;margin:0;padding:0}
p,li{orphans:3;widows:3}h1,h2,h3,article header{break-after:avoid}}
</style></head><body>
<h1>${bi(profile.personal['full_name'])}</h1><div class="contact">${contacts.join(' · ')}</div>
${profile.targetRole.trim().isEmpty ? '' : '<p>${bi(profile.targetRole)}</p>'}
${sections.join('\n')}</body></html>''';
  }
}
