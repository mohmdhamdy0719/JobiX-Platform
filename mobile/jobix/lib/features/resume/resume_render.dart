import 'dart:convert';
import '../career_profile/career_profile.dart';
import '../career_profile/profile_sections.dart';

/// Immutable render-package contract. Preview and the future Chromium worker
/// consume this same HTML, not a second PDF-specific layout or screenshot.
class ResumeRender {
  static const modelVersion = 2;
  static const templateVersion = 2;
  static String html({
    required CareerProfile profile,
    required String language,
    required String latinFontBase64,
    required String arabicFontBase64,
    List<Map<String, dynamic>> additionalLinks = const [],
    Set<String> hiddenSections = const {},
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
    List<String> blocks(String text) {
      if (text.isEmpty) return [];
      final out = <String>[];
      var list = StringBuffer();
      final marker = RegExp(r'^\s*[-•]\s+(.+)$');
      for (final line in text.split('\n')) {
        final bullet = marker.firstMatch(line);
        if (bullet != null) {
          if (list.isEmpty) list.write('<ul>');
          list.write('<li>${bi(bullet.group(1))}</li>');
        } else {
          if (list.isNotEmpty) {
            list.write('</ul>');
            out.add(list.toString());
            list = StringBuffer();
          }
          out.add(
            line.trim().isEmpty
                ? '<p class="blank"><br></p>'
                : '<p>${bi(line)}</p>',
          );
        }
      }
      if (list.isNotEmpty) {
        list.write('</ul>');
        out.add(list.toString());
      }
      return out;
    }

    String lines(String text) => blocks(text).join();

    final sections = <String>[];
    final finalSections = <String>[];
    void section(String title, String body, {bool keepAtEnd = false}) {
      if (body.trim().isNotEmpty) {
        final markup = '<section><h2>${e(title)}</h2>$body</section>';
        (keepAtEnd ? finalSections : sections).add(markup);
      }
    }

    section(
      label('Professional Summary', 'الملخص المهني'),
      hiddenSections.contains('summary') || profile.summary.trim().isEmpty
          ? ''
          : lines(profile.summary),
    );
    final labels = {
      EntitySection.experience: label('Work Experience', 'الخبرة المهنية'),
      EntitySection.volunteer: label(
        'Volunteer Experience',
        'الخبرات التطوعية',
      ),
      EntitySection.education: label('Education', 'التعليم'),
      EntitySection.certification: label('Certifications', 'الشهادات'),
      EntitySection.achievement: label('Achievements', 'الإنجازات'),
      EntitySection.project: label('Projects', 'المشروعات'),
      EntitySection.skill: label('Skills', 'المهارات'),
      EntitySection.language: label('Languages', 'اللغات'),
    };
    for (final type in EntitySection.values) {
      if (hiddenSections.contains(type.key)) continue;
      if (type == EntitySection.skill) {
        section(
          labels[type]!,
          profile.of(type).isEmpty
              ? ''
              : '<p class="skills">${profile.of(type).map((i) => bi(i.text('name'))).join(' · ')}</p>',
          keepAtEnd: true,
        );
        continue;
      }
      final content = StringBuffer();
      for (final item in profile.of(type)) {
        final title = switch (type) {
          EntitySection.experience => item.text('job_title'),
          EntitySection.volunteer => item.text('role'),
          EntitySection.education => item.text('degree'),
          EntitySection.achievement => item.text('title'),
          _ => item.text('name'),
        };
        final metadata = [
          for (final field in [
            'company',
            'organization',
            'institution',
            'field_of_study',
            'issuer',
            if (type != EntitySection.volunteer) 'role',
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
        final linkLabel = title.trim().isNotEmpty
            ? title.trim()
            : item.text('name').trim().isNotEmpty
            ? item.text('name').trim()
            : 'View details';
        final descriptionBlocks = blocks(item.text('description'));
        final leadIncludesParagraph =
            descriptionBlocks.isNotEmpty &&
            descriptionBlocks.first.startsWith('<p');
        final entryLead = StringBuffer();
        if (leadIncludesParagraph) {
          entryLead.write('<div class="entry-lead">');
        }
        entryLead.write(
          '<header><h3>${bi(title)}</h3>'
          '${dates.isEmpty ? '' : '<span class="dates">$dates</span>'}</header>'
          '${metadata.isEmpty ? '' : '<p class="meta">${metadata.join(' · ')}</p>'}',
        );
        if (leadIncludesParagraph) {
          entryLead.write(descriptionBlocks.first);
          entryLead.write('</div>');
        }
        content.write(
          '<article>$entryLead'
          '${descriptionBlocks.skip(leadIncludesParagraph ? 1 : 0).join()}'
          '${item.text('credential_id').isEmpty ? '' : '<p>${bi(item.text('credential_id'))}</p>'}'
          '${item.list('technologies').isEmpty ? '' : '<p>${item.list('technologies').map(bi).join(' · ')}</p>'}'
          '${url == null || url.isEmpty ? '' : '<p><a href="${e(url)}">${bi(linkLabel)}</a></p>'}</article>',
        );
      }
      section(
        labels[type]!,
        content.toString(),
        keepAtEnd: type == EntitySection.language,
      );
    }
    final renderedSections = [
      ...sections,
      if (finalSections.isNotEmpty)
        '<div class="resume-final-sections">${finalSections.join('\n')}</div>',
    ].join('\n');
    final contacts = <String>[];
    for (final key in [
      'email',
      'phone',
      'city',
      'country',
      'linkedin_url',
      'github_url',
      'portfolio_url',
    ]) {
      final value = (profile.personal[key] ?? '').trim();
      if (value.isEmpty) continue;
      if (key.endsWith('_url')) {
        final url = normalizeUrl(value);
        if (url == null || url.isEmpty) continue;
        final label = switch (key) {
          'linkedin_url' => 'LinkedIn',
          'github_url' => 'GitHub',
          _ => 'Portfolio',
        };
        contacts.add('<a href="${e(url)}">${bi(label)}</a>');
      } else {
        contacts.add(bi(value));
      }
    }
    for (final link in additionalLinks) {
      final url = normalizeUrl(link['url'] as String? ?? '');
      final label = (link['label'] as String? ?? '').trim();
      if (url == null || url.isEmpty || label.isEmpty) continue;
      contacts.add('<a href="${e(url)}">${bi(label)}</a>');
    }
    return '''<!doctype html><html lang="$language" dir="${ar ? 'rtl' : 'ltr'}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; font-src data:; img-src data:">
<meta name="jobix-render-version" content="$modelVersion">
<meta name="jobix-template-revision" content="$templateVersion">
<meta name="jobix-template" content="resume_ats_${language}_v1">
<meta name="jobix-profile-version" content="${profile.version}">
<style>
@font-face{font-family:Inter;src:url(data:font/ttf;base64,$latinFontBase64)}
@font-face{font-family:Plex;src:url(data:font/ttf;base64,$arabicFontBase64)}
@page{size:A4;margin:18mm}
*{box-sizing:border-box}html{background:#e8edf4}body{background:white;color:#152237;
 font-family:${ar ? 'Plex,Inter' : 'Inter,Plex'},sans-serif;font-size:11pt;line-height:${ar ? '1.65' : '1.55'};
width:210mm;min-height:297mm;margin:16px auto;padding:18mm;overflow-wrap:anywhere}
section{break-inside:avoid;page-break-inside:avoid}
.resume-final-sections{display:inline-block;width:100%;break-inside:avoid;page-break-inside:avoid}
h1{font-size:24pt;margin:0 0 4mm;font-weight:700}
h2{font-size:13pt;border-bottom:1pt solid #334155;padding-bottom:1.5mm;
margin:3mm 0 1mm;break-after:avoid;page-break-after:avoid}
h3{font-size:11.5pt;margin:0}
.entry-lead{display:inline-block;width:100%;break-inside:avoid;page-break-inside:avoid;
break-after:avoid;page-break-after:avoid}
article{margin-bottom:2.5mm}article header{display:flex;flex-wrap:wrap;justify-content:space-between;gap:2mm;
break-after:avoid;break-inside:avoid;page-break-inside:avoid}
p{margin:1mm 0;white-space:pre-wrap}.contact{font-size:9.5pt}.meta,.dates{color:#43516a}
.personal-header{text-align:center;break-inside:avoid;page-break-inside:avoid}.skills{line-height:1.55}
ul{margin:1mm 0;padding-inline-start:6mm}li{margin:1mm 0;padding-inline-start:1mm}
article .meta{break-after:avoid}p.blank{margin:0;height:2mm}
.dates{font-size:9.5pt}a{color:inherit;text-decoration:none}bdi{unicode-bidi:plaintext}
li{list-style-position:outside;break-inside:avoid;page-break-inside:avoid}
@media print{html{background:white}body{width:auto;min-height:0;margin:0;padding:0}
p,li{orphans:3;widows:3}h1,h2,h3,article header{break-after:avoid}}
</style></head><body>
<header class="personal-header"><h1>${bi(profile.personal['full_name'])}</h1><div class="contact">${contacts.join(' · ')}</div>
${hiddenSections.contains('target_role') || profile.targetRole.trim().isEmpty ? '' : '<p>${bi(profile.targetRole)}</p>'}
</header>$renderedSections</body></html>''';
  }
}
