import 'dart:convert';
import '../career_profile/career_profile.dart';
import '../career_profile/profile_sections.dart';
import 'resume_render.dart';

/// Presentation only; source facts and completeness remain untouched.
class ResumePresentation {
  ResumePresentation({required this.language, this.version = 0,
    Set<String> hidden = const {}}) : hidden = Set.unmodifiable(hidden) {
    if (!['en', 'ar'].contains(language) ||
        !hidden.every(sectionKeys.contains)) {
      throw ArgumentError('VALIDATION_FAILED');
    }
  }
  static const sectionKeys = [
    'summary', 'target_role', 'experience', 'volunteer', 'education',
    'certification', 'achievement', 'project', 'skill', 'language',
  ];
  final String language;
  final int version;
  final Set<String> hidden;
  factory ResumePresentation.fromJson(Map<String, dynamic> json) {
    final visibility = Map<String, dynamic>.from(
      json['section_visibility'] as Map? ?? {});
    return ResumePresentation(language: json['language'] as String,
      version: (json['version'] as num? ?? 0).toInt(),
      hidden: {for (final key in visibility.keys)
        if (visibility[key] == false) key});
  }
}

class ResumeDocument {
  static const bundle = 'jobix-resume-export-1';

  /// Structural validity, never descriptive minima or scored evidence flags.
  static List<String> issues(CareerProfile p, ResumePresentation config) {
    final errors = <String>[];
    final name = p.personal['full_name']?.trim() ?? '';
    final email = p.personal['email']?.trim() ?? '';
    final phone = p.personal['phone']?.trim() ?? '';
    if (name.isEmpty || name.runes.length > 120) errors.add('personal.full_name');
    if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      errors.add('personal.email');
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length > 32 || digits.length < 7 || digits.length > 15 ||
        !RegExp(r'^\+?[0-9 ()-]+$').hasMatch(phone)) {
      errors.add('personal.phone');
    }
    if (!config.hidden.contains('summary') && p.summary.runes.length > 1000) {
      errors.add('summary');
    }
    var evidence = false;
    for (final section in EntitySection.values) {
      if (config.hidden.contains(section.key)) continue;
      for (final item in p.of(section)) {
        final problems = item.problems();
        if (problems.isNotEmpty) {
          errors.add('${section.key}:${item.id}');
        } else if ([
          EntitySection.experience, EntitySection.volunteer,
          EntitySection.education, EntitySection.project, EntitySection.skill,
          EntitySection.certification, EntitySection.achievement,
        ].contains(section)) {
          evidence = true;
        }
      }
    }
    if (!evidence) errors.add('career_content');
    return errors;
  }

  /// Raw text for server-side NFC byte measurement, not translated/rewritten.
  static String sourceText(CareerProfile p, ResumePresentation config,
      List<Map<String, dynamic>> links) {
    final values = <String>[
      ...p.personal.values,
      if (!config.hidden.contains('summary')) p.summary,
      if (!config.hidden.contains('target_role')) p.targetRole,
      for (final section in EntitySection.values)
        if (!config.hidden.contains(section.key))
          for (final item in p.of(section))
            for (final value in item.values.values)
              if (value is String) value
              else if (value is List) ...value.cast<String>(),
      for (final link in links) ...[
        link['label'] as String? ?? '', link['url'] as String? ?? '',
      ],
    ];
    return values.join('\n');
  }

  static Map<String, dynamic> prepare(Map<String, dynamic> source,
      String latinFont, String arabicFont) {
    final profile = CareerProfile.fromJson(
      Map<String, dynamic>.from(source['profile'] as Map));
    final config = ResumePresentation.fromJson(
      Map<String, dynamic>.from(source['configuration'] as Map));
    final links = List<Map<String, dynamic>>.from(
      source['links'] as List? ?? const []);
    if (links.any((link) => normalizeUrl(link['url'] as String? ?? '') == null)) {
      throw ArgumentError('VALIDATION_FAILED');
    }
    final text = sourceText(profile, config, links);
    // The gateway also measures NFC; no normalization rewrites user facts.
    if (utf8.encode(text).length > 200000) {
      throw StateError('RESUME_SOURCE_TOO_LARGE');
    }
    return {
      'bundle': bundle, 'issues': issues(profile, config),
      'source_text': text,
      'html': ResumeRender.html(profile: profile, language: config.language,
        latinFontBase64: latinFont, arabicFontBase64: arabicFont,
        additionalLinks: links, hiddenSections: config.hidden),
    };
  }
}
