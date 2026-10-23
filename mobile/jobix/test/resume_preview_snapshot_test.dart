import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:jobix/core/database/database.dart';
import 'package:jobix/core/database/encryption.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/career_profile/text_section_repository.dart';
import 'package:jobix/features/onboarding/research_context.dart';
import 'package:jobix/features/personal_information/profile_extras_repository.dart';
import 'package:jobix/features/resume/resume_document.dart';
import 'package:jobix/features/resume/resume_preview_snapshot.dart';

import '../tool/local_resume_preview_poc.dart';

class _ProfileApi implements ProfileApi {
  @override
  Future<bool> claimRegistrationEntry() async => true;
  @override
  Future<CareerProfile> firstProfile() async => _profile(1);
  @override
  Future<CareerProfile> save(PersonalDraft draft) async => _profile(2);
  @override
  Future<void> saveContext(ResearchProgress progress) async {}
}

class _ProfileExtrasApi implements ProfileExtrasApi {
  @override
  Future<ProfileExtras> read(String profile) async => const ProfileExtras();
  @override
  Future<CareerProfile> save(Map<String, dynamic> request) async => _profile(2);
}

CareerProfile _profile(int version) {
  final source = LocalPreviewFixture.all.first.source();
  final value = Map<String, dynamic>.from(source['profile'] as Map)
    ..['profile_version'] = version;
  return CareerProfile.fromJson(value);
}

Map<String, dynamic> _configuration({
  int version = 4,
  String language = 'en',
}) => {
  'language': language,
  'template_id': 'resume_ats_${language}_v1',
  'version': version,
  'section_visibility': <String, bool>{'education': false},
  'section_order': resumePreviewSectionOrder,
  'render_config_version': 'export-v1',
  'template_version': 2,
};

ResumePreviewSnapshotLoader _loader({
  required List<CareerProfile> profiles,
  Map<String, dynamic>? configuration,
  ResumePreviewDraftState drafts = const ResumePreviewDraftState(
    hasUnsentEdits: false,
    hasUnresolvedSave: false,
    fingerprint: 'clean',
  ),
  ProfileExtras extras = const ProfileExtras(),
}) {
  var profileIndex = 0;
  return ResumePreviewSnapshotLoader(
    loadFreshProfile: () async {
      final index = profileIndex++;
      return profiles[index.clamp(0, profiles.length - 1).toInt()];
    },
    readFreshExtras: (_) async => extras,
    readConfiguration: (_) async => configuration,
    inspectDrafts: (_, __) async => drafts,
    latinFontBase64: 'bGF0aW4=',
    arabicFontBase64: 'YXJhYmlj',
  );
}

void main() {
  test(
    'assembles saved profile, links, visibility, and versions locally',
    () async {
      final link = const CustomProfileLink(
        id: 'portfolio-1',
        label: 'Portfolio',
        url: 'https://example.com/portfolio',
      );
      final loader = _loader(
        profiles: [_profile(7), _profile(7)],
        configuration: _configuration(),
        extras: ProfileExtras(links: [link]),
      );

      final snapshot = await loader.load();

      expect(snapshot.document['profile_version'], 7);
      expect(snapshot.document['configuration_version'], 4);
      expect(snapshot.document['language'], 'en');
      expect(snapshot.document['bundle'], ResumeDocument.bundle);
      expect(snapshot.document['html'], contains('Portfolio'));
      expect(snapshot.document['html'], contains('example.com&#47;portfolio'));
      expect(snapshot.configuration['section_visibility'], {
        'education': false,
      });
      expect(snapshot.profile.items.length, 8);
      expect(snapshot.hasUnsentEdits, isFalse);
    },
  );

  test(
    'uses the renderer-supported default when no saved configuration exists',
    () async {
      final profile = _profile(7);
      final snapshot = await _loader(profiles: [profile, profile]).load();

      expect(
        snapshot.configuration['language'],
        profile.resumeLanguage ?? 'en',
      );
      expect(snapshot.configuration['version'], 0);
      expect(snapshot.configuration['section_visibility'], isEmpty);
      expect(
        snapshot.configuration['section_order'],
        resumePreviewSectionOrder,
      );
    },
  );

  test(
    'retries a mixed profile/configuration read before returning a snapshot',
    () async {
      var profileReads = 0;
      var configurationReads = 0;
      final loader = ResumePreviewSnapshotLoader(
        loadFreshProfile: () async => _profile(profileReads++ == 0 ? 1 : 2),
        readFreshExtras: (_) async => const ProfileExtras(),
        readConfiguration: (_) async {
          configurationReads++;
          return _configuration(version: configurationReads < 3 ? 1 : 2);
        },
        inspectDrafts: (_, __) async => const ResumePreviewDraftState(
          hasUnsentEdits: false,
          hasUnresolvedSave: false,
          fingerprint: 'clean',
        ),
        latinFontBase64: 'bGF0aW4=',
        arabicFontBase64: 'YXJhYmlj',
      );

      final snapshot = await loader.load();

      expect(snapshot.profile.version, 2);
      expect(snapshot.configuration['version'], 2);
      expect(profileReads, 4);
      expect(configurationReads, 4);
    },
  );

  test(
    'retries if saved custom links change while Preview is loading',
    () async {
      var extrasReads = 0;
      final loader = ResumePreviewSnapshotLoader(
        loadFreshProfile: () async => _profile(7),
        readFreshExtras: (_) async {
          extrasReads++;
          final label = extrasReads < 2 ? 'Old link' : 'Current link';
          return ProfileExtras(
            links: [
              CustomProfileLink(
                id: 'portfolio',
                label: label,
                url: 'https://example.com/portfolio',
              ),
            ],
          );
        },
        readConfiguration: (_) async => _configuration(),
        inspectDrafts: (_, __) async => const ResumePreviewDraftState(
          hasUnsentEdits: false,
          hasUnresolvedSave: false,
          fingerprint: 'clean',
        ),
        latinFontBase64: 'bGF0aW4=',
        arabicFontBase64: 'YXJhYmlj',
      );

      final snapshot = await loader.load();

      expect(extrasReads, 4);
      expect(snapshot.document['html'], contains('Current link'));
      expect(snapshot.document['html'], isNot(contains('Old link')));
    },
  );

  test(
    'does not return a snapshot if the saved source keeps changing',
    () async {
      var version = 0;
      final loader = ResumePreviewSnapshotLoader(
        loadFreshProfile: () async => _profile(version++),
        readFreshExtras: (_) async => const ProfileExtras(),
        readConfiguration: (_) async => _configuration(),
        inspectDrafts: (_, __) async => const ResumePreviewDraftState(
          hasUnsentEdits: false,
          hasUnresolvedSave: false,
          fingerprint: 'clean',
        ),
        latinFontBase64: 'bGF0aW4=',
        arabicFontBase64: 'YXJhYmlj',
      );

      await expectLater(
        loader.load(),
        throwsA(
          isA<ResumePreviewBlocked>().having(
            (error) => error.code,
            'code',
            'SAVED_RESUME_CHANGED',
          ),
        ),
      );
    },
  );

  test(
    'local unsent edits preview the saved snapshot while uncertain saves stay guarded',
    () async {
      const draftState = ResumePreviewDraftState(
        hasUnsentEdits: true,
        hasUnresolvedSave: false,
        fingerprint: 'draft-fingerprint',
      );
      final loader = _loader(
        profiles: [_profile(3), _profile(3)],
        configuration: _configuration(),
        drafts: draftState,
      );
      final preview = await loader.load();
      expect(preview.hasUnsentEdits, isTrue);
      expect(preview.document['profile_version'], 3);

      final unresolved = _loader(
        profiles: [_profile(3), _profile(3)],
        configuration: _configuration(),
        drafts: const ResumePreviewDraftState(
          hasUnsentEdits: false,
          hasUnresolvedSave: true,
          fingerprint: 'pending-save',
        ),
      );
      await expectLater(
        unresolved.load(),
        throwsA(
          isA<ResumePreviewNeedsConfirmation>().having(
            (error) => error.fingerprint,
            'fingerprint',
            'pending-save',
          ),
        ),
      );
      final savedSnapshot = await unresolved.load(
        confirmedDraftFingerprint: 'pending-save',
      );
      expect(savedSnapshot.hasUnsentEdits, isFalse);
      expect(savedSnapshot.document['profile_version'], 3);
    },
  );

  test('fails closed for unsupported saved presentation settings', () async {
    final loader = _loader(
      profiles: [_profile(3), _profile(3)],
      configuration: {
        ..._configuration(),
        'section_order': ['experience', 'summary'],
      },
    );
    final missingLanguage = _loader(
      profiles: [_profile(3), _profile(3)],
      configuration: {..._configuration()}..remove('language'),
    );

    await expectLater(
      loader.load(),
      throwsA(
        isA<ResumePreviewBlocked>().having(
          (error) => error.code,
          'code',
          'UNSUPPORTED_SAVED_CONFIGURATION',
        ),
      ),
    );
    await expectLater(
      missingLanguage.load(),
      throwsA(
        isA<ResumePreviewBlocked>().having(
          (error) => error.code,
          'code',
          'UNSUPPORTED_SAVED_CONFIGURATION',
        ),
      ),
    );
  });

  test(
    'draft inspection sees legacy edits and unresolved saves but not new local drafts',
    () async {
      configureSqlCipher(
        testLibrary: Platform.environment['JOBIX_SQLCIPHER_LIBRARY']!,
      );
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DraftRepository(
        database,
        _ProfileApi(),
        'synthetic-user',
        () => true,
      );
      final extrasRepository = ProfileExtrasRepository(
        repository,
        _ProfileExtrasApi(),
      );
      final profile = _profile(7);

      Future<ResumePreviewDraftState> inspect() => inspectResumePreviewDrafts(
        profileRepository: repository,
        extrasRepository: extrasRepository,
        profile: profile,
        savedExtras: const ProfileExtras(),
      );

      expect((await inspect()).hasUnsentEdits, isFalse);

      await database.saveDraft(
        repository.user,
        profile.id,
        PersonalDraft(
          profileId: profile.id,
          baseVersion: profile.version,
          personal: profile.personal,
        ).encode(),
      );
      expect((await inspect()).hasUnsentEdits, isTrue);

      await database.discardDraft(repository.user, profile.id);
      await database.retainSection(
        repository.user,
        profile.id,
        'entity:experience:unsaved',
        '{"id":"unsaved"}',
      );
      expect((await inspect()).hasUnsentEdits, isTrue);
      await database.discardSection(
        repository.user,
        profile.id,
        'entity:experience:unsaved',
      );
      await database.retainSection(
        repository.user,
        profile.id,
        'summary',
        TextSectionDraft(
          profileId: profile.id,
          section: 'summary',
          version: profile.version,
          text: 'Unsaved synthetic summary',
        ).encode(),
      );
      expect((await inspect()).hasUnsentEdits, isTrue);

      await database.retainSection(
        repository.user,
        profile.id,
        'summary',
        TextSectionDraft(
          profileId: profile.id,
          section: 'summary',
          version: profile.version,
          text: 'Pending synthetic summary',
          key: 'original-key',
          request: {
            'version': profile.version,
            'text': 'Pending synthetic summary',
          },
        ).encode(),
      );
      expect((await inspect()).hasUnresolvedSave, isTrue);

      await database.discardSection(repository.user, profile.id, 'summary');
      await database.retainPendingMutation(
        repository.user,
        profile.id,
        '{"key":"synthetic-pending"}',
      );
      expect((await inspect()).hasUnresolvedSave, isTrue);

      await database.discardPendingMutation(repository.user, profile.id);
      await extrasRepository.retain(
        ExtrasDraft(
          profileId: profile.id,
          version: profile.version,
          value: ProfileExtras(
            links: const [
              CustomProfileLink(
                id: 'local-link',
                label: 'Local draft',
                url: 'https://example.com/draft',
              ),
            ],
          ),
        ),
      );
      expect(await extrasRepository.local(profile.id), isNull);
      expect((await inspect()).hasUnsentEdits, isFalse);

      await database.setSetting(
        'resume:${repository.user}:${profile.id}',
        '{}',
      );
      expect((await inspect()).hasUnresolvedSave, isTrue);
      await database.removeSetting('resume:${repository.user}:${profile.id}');
      await database.setSetting(
        'resume:${repository.user}:export:${profile.id}',
        '{}',
      );
      expect((await inspect()).hasUnresolvedSave, isTrue);
    },
  );

  test('export review compares saved identity, not renderer serialization', () {
    final reviewed = {
      'profile_version': 7,
      'configuration_version': 4,
      'source_sha256': 'c' * 64,
      'language': 'en',
      'bundle': ResumeDocument.bundle,
      'html': '<html>reviewed</html>',
      'issues': <String>[],
      'configuration': _configuration(),
    };
    final authoritative = {...reviewed, 'document_sha256': 'a' * 64};

    expect(sameReviewedResume(reviewed, authoritative), isTrue);
    final localWithoutServerHash = Map<String, dynamic>.from(reviewed)
      ..remove('source_sha256');
    expect(sameReviewedResume(localWithoutServerHash, authoritative), isTrue);
    expect(
      sameReviewedResume(reviewed, {...authoritative, 'profile_version': 8}),
      isFalse,
    );
    expect(
      sameReviewedResume(reviewed, {
        ...authoritative,
        'source_sha256': 'd' * 64,
      }),
      isFalse,
    );
    expect(
      sameReviewedResume(reviewed, {
        ...authoritative,
        'html': '<html>new</html>',
      }),
      isTrue,
    );
    expect(
      reviewedResumeDifferences(reviewed, {
        ...authoritative,
        'html': '<html>new</html>',
      }),
      isEmpty,
    );
    expect(
      sameReviewedResume(reviewed, {
        ...authoritative,
        'configuration': _configuration(language: 'ar'),
      }),
      isFalse,
    );
  });
}
