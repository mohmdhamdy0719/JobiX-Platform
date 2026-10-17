import 'dart:convert';

import 'package:flutter/services.dart';

import '../career_profile/career_profile.dart';
import '../career_profile/career_profile_repository.dart';
import '../career_profile/profile_sections.dart';
import '../career_profile/text_section_repository.dart';
import '../personal_information/profile_extras_repository.dart';
import 'resume_document.dart';
import 'resume_layout.dart';

const resumePreviewSectionOrder = [
  'summary',
  'experience',
  'volunteer',
  'education',
  'certification',
  'achievement',
  'project',
  'skill',
  'language',
];

class ResumePreviewDraftState {
  const ResumePreviewDraftState({
    required this.hasUnsentEdits,
    required this.hasUnresolvedSave,
    required this.fingerprint,
  });

  final bool hasUnsentEdits;
  final bool hasUnresolvedSave;
  final String fingerprint;
}

class ResumePreviewNeedsConfirmation implements Exception {
  const ResumePreviewNeedsConfirmation(this.fingerprint);
  final String fingerprint;
}

class ResumePreviewBlocked implements Exception {
  const ResumePreviewBlocked(this.code);
  final String code;
}

class ResumePreviewSnapshot {
  const ResumePreviewSnapshot({
    required this.document,
    required this.profile,
    required this.configuration,
    required this.hasUnsentEdits,
    required this.draftFingerprint,
  });

  final Map<String, dynamic> document;
  final CareerProfile profile;
  final Map<String, dynamic> configuration;
  final bool hasUnsentEdits;
  final String draftFingerprint;
}

typedef ResumeProfileReader = Future<CareerProfile> Function();
typedef ResumeExtrasReader = Future<ProfileExtras> Function(String profileId);
typedef ResumeConfigurationReader =
    Future<Map<String, dynamic>?> Function(String profileId);
typedef ResumeDraftInspector =
    Future<ResumePreviewDraftState> Function(
      CareerProfile profile,
      ProfileExtras savedExtras,
    );

class ResumePreviewSnapshotLoader {
  ResumePreviewSnapshotLoader({
    required this.loadFreshProfile,
    required this.readFreshExtras,
    required this.readConfiguration,
    required this.inspectDrafts,
    required this.latinFontBase64,
    required this.arabicFontBase64,
  });

  final ResumeProfileReader loadFreshProfile;
  final ResumeExtrasReader readFreshExtras;
  final ResumeConfigurationReader readConfiguration;
  final ResumeDraftInspector inspectDrafts;
  final String latinFontBase64;
  final String arabicFontBase64;

  Future<ResumePreviewSnapshot> load({
    String? confirmedDraftFingerprint,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final beforeProfile = await loadFreshProfile();
      final beforeExtras = await readFreshExtras(beforeProfile.id);
      final beforeDrafts = await inspectDrafts(beforeProfile, beforeExtras);
      final beforeConfiguration = await readConfiguration(beforeProfile.id);
      final afterProfile = await loadFreshProfile();
      final afterExtras = await readFreshExtras(afterProfile.id);
      final afterConfiguration = await readConfiguration(afterProfile.id);
      final afterDrafts = await inspectDrafts(afterProfile, afterExtras);

      final stable =
          beforeProfile.id == afterProfile.id &&
          beforeProfile.version == afterProfile.version &&
          _canonicalJson(beforeProfile.toJson()) ==
              _canonicalJson(afterProfile.toJson()) &&
          _linksJson(beforeExtras.links) == _linksJson(afterExtras.links) &&
          _canonicalJson(beforeConfiguration) ==
              _canonicalJson(afterConfiguration) &&
          beforeDrafts.fingerprint == afterDrafts.fingerprint;
      if (!stable) continue;

      // Preview is a read-only view of the saved server snapshot. An
      // unacknowledged local write must not be silently discarded or replayed,
      // but it also must not prevent the user from reviewing what the server
      // currently has. Require the same explicit saved-version confirmation
      // used for ordinary local edits.
      if ((afterDrafts.hasUnsentEdits || afterDrafts.hasUnresolvedSave) &&
          confirmedDraftFingerprint != afterDrafts.fingerprint) {
        throw ResumePreviewNeedsConfirmation(afterDrafts.fingerprint);
      }

      final configuration = _configuration(afterConfiguration, afterProfile);
      if (afterExtras.links.any((link) => !link.valid)) {
        throw const ResumePreviewBlocked('INVALID_SAVED_LINK');
      }
      final source = {
        'profile': afterProfile.toJson(),
        'configuration': configuration,
        'links': [for (final link in afterExtras.links) link.toJson()],
      };
      final prepared = ResumeDocument.prepare(
        source,
        latinFontBase64,
        arabicFontBase64,
      );
      return ResumePreviewSnapshot(
        document: {
          ...prepared,
          'profile_version': afterProfile.version,
          'configuration_version': configuration['version'],
          'language': configuration['language'],
          'configuration': configuration,
        },
        profile: afterProfile,
        configuration: configuration,
        hasUnsentEdits: afterDrafts.hasUnsentEdits,
        draftFingerprint: afterDrafts.fingerprint,
      );
    }
    throw const ResumePreviewBlocked('SAVED_RESUME_CHANGED');
  }

  static Map<String, dynamic> _configuration(
    Map<String, dynamic>? stored,
    CareerProfile profile,
  ) {
    final language =
        stored?['language'] as String? ?? profile.resumeLanguage ?? 'en';
    final configuration = stored == null
        ? <String, dynamic>{
            'language': language,
            'template_id': 'resume_ats_${language}_v1',
            'version': 0,
            'section_visibility': <String, bool>{},
            'section_order': resumePreviewSectionOrder,
            'render_config_version': 'export-v1',
            'template_version': 2,
          }
        : Map<String, dynamic>.from(stored);

    final visibility = configuration['section_visibility'];
    final order = configuration['section_order'];
    final layoutV1 =
        configuration['render_config_version'] == ResumeLayout.renderVersion &&
        configuration['template_version'] == ResumeLayout.templateVersion;
    final supportedOrder =
        order is List &&
        (layoutV1
            ? order.length == ResumeLayout.sectionKeys.length &&
                  order.toSet().length == ResumeLayout.sectionKeys.length &&
                  order.every(ResumeLayout.sectionKeys.contains)
            : _canonicalJson(order) ==
                  _canonicalJson(resumePreviewSectionOrder));
    const supportedFields = {
      'profile_id',
      'language',
      'template_id',
      'version',
      'section_visibility',
      'section_order',
      'render_config_version',
      'template_version',
    };
    if (!['en', 'ar'].contains(language) ||
        configuration['language'] != language ||
        (configuration['profile_id'] != null &&
            configuration['profile_id'] != profile.id) ||
        configuration.keys.any((key) => !supportedFields.contains(key)) ||
        configuration['template_id'] != 'resume_ats_${language}_v1' ||
        (configuration['version'] is! num) ||
        visibility is! Map ||
        visibility.keys.any(
          (key) =>
              key is! String || !ResumePresentation.sectionKeys.contains(key),
        ) ||
        visibility.values.any((value) => value is! bool) ||
        !supportedOrder ||
        (!layoutV1 &&
            (configuration['render_config_version'] != 'export-v1' ||
                configuration['template_version'] != 2))) {
      throw const ResumePreviewBlocked('UNSUPPORTED_SAVED_CONFIGURATION');
    }
    configuration['version'] = (configuration['version'] as num).toInt();
    configuration['section_visibility'] = Map<String, dynamic>.from(visibility);
    configuration['section_order'] = List<String>.from(order);
    return configuration;
  }
}

Future<ResumePreviewDraftState> inspectResumePreviewDrafts({
  required DraftRepository profileRepository,
  required ProfileExtrasRepository extrasRepository,
  required CareerProfile profile,
  required ProfileExtras savedExtras,
}) async {
  final database = profileRepository.database;
  final user = profileRepository.user;
  final rawState = <String>[];
  var unsent = false;
  var unresolved = false;

  final personalRaw = await database.draftFor(user, profile.id);
  if (personalRaw != null) {
    rawState.add('personal:$personalRaw');
    unsent = true;
    try {
      if (PersonalDraft.decode(personalRaw).frozen != null) unresolved = true;
    } catch (_) {
      unresolved = true;
    }
  }

  final pendingMutation = await database.pendingMutation(user, profile.id);
  if (pendingMutation != null) {
    rawState.add('mutation:$pendingMutation');
    unresolved = true;
  }

  final sectionKeys = await database.sectionDraftKeys(user, profile.id, '');
  for (final section in sectionKeys..sort()) {
    final raw = await database.sectionDraft(user, profile.id, section);
    if (raw == null) continue;
    rawState.add('section:$section:$raw');
    unsent = true;
    if (section == 'summary' || section == 'target_role') {
      try {
        if (TextSectionDraft.decode(raw).request != null) unresolved = true;
      } catch (_) {
        unresolved = true;
      }
    }
  }

  final extrasDraft = await extrasRepository.local(profile.id);
  if (extrasDraft != null) {
    rawState.add('extras:${extrasDraft.encode()}');
    if (extrasDraft.profileId != profile.id || extrasDraft.pending != null) {
      unresolved = true;
    }
    if (_linksJson(extrasDraft.value.links) != _linksJson(savedExtras.links)) {
      unsent = true;
    }
  }

  for (final key in [
    'resume:$user:${profile.id}',
    'resume:$user:export:${profile.id}',
    'resume:$user:layout:${profile.id}',
  ]) {
    final raw = await database.setting(key);
    if (raw != null) {
      rawState.add('setting:$key:$raw');
      unresolved = true;
    }
  }

  if (!profileRepository.isCurrentUser()) {
    throw const ResumePreviewBlocked('AUTH_REQUIRED');
  }
  return ResumePreviewDraftState(
    hasUnsentEdits: unsent,
    hasUnresolvedSave: unresolved,
    fingerprint: jsonEncode(rawState),
  );
}

Future<(String latin, String arabic)>? _cachedPreviewFonts;

Future<(String latin, String arabic)> loadResumePreviewFonts() =>
    _cachedPreviewFonts ??= _readResumePreviewFonts();

Future<(String latin, String arabic)> _readResumePreviewFonts() async {
  final latin = await rootBundle.load('assets/fonts/Inter.ttf');
  final arabic = await rootBundle.load(
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
  );
  return (
    base64Encode(
      latin.buffer.asUint8List(latin.offsetInBytes, latin.lengthInBytes),
    ),
    base64Encode(
      arabic.buffer.asUint8List(arabic.offsetInBytes, arabic.lengthInBytes),
    ),
  );
}

bool sameReviewedResume(
  Map<String, dynamic> reviewed,
  Map<String, dynamic> authoritative,
) => reviewedResumeDifferences(reviewed, authoritative).isEmpty;

/// Allowlisted field names only, never content, hashes, IDs, or versions.
List<String> reviewedResumeDifferences(
  Map<String, dynamic> reviewed,
  Map<String, dynamic> authoritative,
) {
  final differences = <String>[];
  // HTML is a renderer output, not saved resume identity. The export panel
  // fetches the current server canonical document and submits its hash; saved
  // source hash, profile/configuration versions, and bundle remain strict
  // comparisons.
  for (final key in [
    'source_sha256',
    'profile_version',
    'configuration_version',
    'language',
    'bundle',
    'issues',
  ]) {
    // The local Preview deliberately has no server-only source hash. Saved
    // profile/configuration versions still guard its content; compare the
    // hash when a reviewed snapshot actually carries one.
    if (key == 'source_sha256' && reviewed[key] == null) continue;
    if (_canonicalJson(reviewed[key]) != _canonicalJson(authoritative[key])) {
      differences.add(key);
    }
  }
  final reviewedConfig = Map<String, dynamic>.from(
    reviewed['configuration'] as Map? ?? const {},
  );
  final authoritativeConfig = Map<String, dynamic>.from(
    authoritative['configuration'] as Map? ?? const {},
  );
  for (final key in [
    'language',
    'profile_id',
    'template_id',
    'version',
    'section_visibility',
    'section_order',
    'render_config_version',
    'template_version',
  ]) {
    final left =
        reviewedConfig[key] ??
        (key == 'section_order' ? resumePreviewSectionOrder : null);
    final right =
        authoritativeConfig[key] ??
        (key == 'section_order' ? resumePreviewSectionOrder : null);
    if (_canonicalJson(left) != _canonicalJson(right)) {
      differences.add('configuration.$key');
    }
  }
  return List.unmodifiable(differences);
}

String _linksJson(List<CustomProfileLink> links) => _canonicalJson([
  for (final link in links)
    {
      'id': link.id,
      'label': link.label.trim(),
      'url': normalizeUrl(link.url) ?? link.url,
    },
]);

String _canonicalJson(Object? value) => jsonEncode(_canonicalValue(value));

Object? _canonicalValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonicalValue(value[key])};
  }
  if (value is Iterable) return value.map(_canonicalValue).toList();
  return value;
}
