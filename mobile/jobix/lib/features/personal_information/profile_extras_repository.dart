import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/career_profile_repository.dart';
import '../career_profile/profile_sections.dart';

class CustomProfileLink {
  const CustomProfileLink({required this.id, this.label = '', this.url = ''});
  final String id, label, url;
  CustomProfileLink edit({String? label, String? url}) => CustomProfileLink(
    id: id,
    label: label ?? this.label,
    url: url ?? this.url,
  );
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'url': url};
  factory CustomProfileLink.fromJson(Map json) => CustomProfileLink(
    id: json['id'] as String,
    label: json['label'] as String,
    url: json['url'] as String,
  );
  bool get valid =>
      label.trim().isNotEmpty &&
      label.trim().runes.length <= 200 &&
      url.trim().isNotEmpty &&
      normalizeUrl(url) != null;
}

class ProfileExtras {
  const ProfileExtras({
    this.links = const [],
    this.photoBase64,
    this.photoMime,
  });
  final List<CustomProfileLink> links;
  final String? photoBase64, photoMime;
  Uint8List? get photoBytes =>
      photoBase64 == null ? null : base64Decode(photoBase64!);
  ProfileExtras withLinks(List<CustomProfileLink> value) => ProfileExtras(
    links: value,
    photoBase64: photoBase64,
    photoMime: photoMime,
  );
  ProfileExtras withPhoto(Uint8List? bytes, String? mime) => ProfileExtras(
    links: links,
    photoBase64: bytes == null ? null : base64Encode(bytes),
    photoMime: mime,
  );
  Map<String, dynamic> toJson() => {
    'links': [for (final link in links) link.toJson()],
    'photo_base64': photoBase64,
    'photo_mime': photoMime,
  };
  Map<String, dynamic> payload() => {
    ...toJson(),
    'links': [
      for (final link in links)
        {
          'id': link.id,
          'label': link.label.trim(),
          'url': normalizeUrl(link.url) ?? link.url,
        },
    ],
  };
  factory ProfileExtras.fromJson(Map json) => ProfileExtras(
    links: [
      for (final link in (json['links'] as List? ?? []))
        CustomProfileLink.fromJson(link as Map),
    ],
    photoBase64: json['photo_base64'] as String?,
    photoMime: json['photo_mime'] as String?,
  );
  static String? imageMime(Uint8List bytes) {
    if (bytes.length < 8 || bytes.length > 1048576) return null;
    if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) {
      return 'image/jpeg';
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
      return 'image/png';
    }
    return null;
  }

  bool get valid {
    if (links.any((link) => !link.valid)) return false;
    if (links.map((link) => link.id).toSet().length != links.length) {
      return false;
    }
    if (photoBase64 == null) return photoMime == null;
    try {
      return imageMime(photoBytes!) == photoMime;
    } catch (_) {
      return false;
    }
  }
}

class ExtrasDraft {
  const ExtrasDraft({
    required this.profileId,
    required this.version,
    required this.value,
    this.pending,
  });
  final String profileId;
  final int version;
  final ProfileExtras value;

  /// Exact durable request, including its original personal-draft baseline.
  /// Kept separately from editable input; never regenerated after uncertainty.
  final Map<String, dynamic>? pending;
  ExtrasDraft edit(ProfileExtras value) => ExtrasDraft(
    profileId: profileId,
    version: version,
    value: value,
    pending: pending,
  );
  String encode() => jsonEncode({
    'profile': profileId,
    'version': version,
    'value': value.toJson(),
    'pending': pending,
  });
  factory ExtrasDraft.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ExtrasDraft(
      profileId: json['profile'] as String,
      version: json['version'] as int,
      value: ProfileExtras.fromJson(json['value'] as Map),
      pending: json['pending'] == null
          ? null
          : Map<String, dynamic>.from(json['pending'] as Map),
    );
  }
}

abstract interface class ProfileExtrasApi {
  Future<ProfileExtras> read(String profile);
  Future<CareerProfile> save(Map<String, dynamic> request);
}

class SupabaseProfileExtrasApi implements ProfileExtrasApi {
  SupabaseProfileExtrasApi(this.client);
  final SupabaseClient client;
  @override
  Future<ProfileExtras> read(String profile) async {
    final result = await client
        .rpc('read_profile_extras', params: {'requested_profile': profile})
        .timeout(const Duration(seconds: 20));
    return ProfileExtras.fromJson(result as Map);
  }

  @override
  Future<CareerProfile> save(Map<String, dynamic> request) async =>
      acknowledgedProfile(
        await client
            .rpc(
              'save_profile_extras',
              params: {
                'command_key': request['command_key'],
                'requested_profile': request['requested_profile'],
                'expected_profile_version': request['expected_profile_version'],
                'extras': request['extras'],
              },
            )
            .timeout(const Duration(seconds: 25)),
      );
}

class ExtrasSaveResult {
  const ExtrasSaveResult(
    this.profile,
    this.draft,
    this.personalSafe,
    this.hasUnsentEdits,
  );
  final CareerProfile profile;
  final ExtrasDraft draft;
  final bool personalSafe;
  final bool hasUnsentEdits;
}

/// Isolated SQLCipher LocalSettings draft/request. This never writes or
/// consumes EntityRepository's outbox, and never silently rebases remote edits.
class ProfileExtrasRepository {
  ProfileExtrasRepository(this.parent, this.api);
  final DraftRepository parent;
  final ProfileExtrasApi api;
  String key(String profile) => 'extras:${parent.user}:$profile';
  void check() {
    if (!parent.isCurrentUser()) throw StateError('AUTH_REQUIRED');
  }

  Future<ExtrasDraft?> local(String profile) async {
    check();
    final raw = await parent.database.setting(key(profile));
    check();
    return raw == null ? null : ExtrasDraft.decode(raw);
  }

  Future<ExtrasDraft> open(CareerProfile profile) async {
    final saved = await local(profile.id);
    if (saved != null) return saved;
    final value = await api.read(profile.id);
    check();
    final draft = ExtrasDraft(
      profileId: profile.id,
      version: profile.version,
      value: value,
    );
    await retain(draft);
    return draft;
  }

  Future<void> retain(ExtrasDraft draft) async {
    check();
    await parent.database.transaction(() async {
      final current = await local(draft.profileId);
      final next = ExtrasDraft(
        profileId: draft.profileId,
        version: draft.version,
        value: draft.value,
        pending: current?.pending ?? draft.pending,
      );
      await parent.database.setSetting(key(draft.profileId), next.encode());
      check();
    });
  }

  void _personalGuard(String? raw, int version) {
    if (raw == null) return;
    final personal = PersonalDraft.decode(raw);
    if (personal.frozen != null) throw StateError('PERSONAL_SAVE_PENDING');
    if (personal.baseVersion != version) {
      throw StateError('PERSONAL_BASELINE_CONFLICT');
    }
  }

  Future<ExtrasSaveResult> save(ExtrasDraft input) async {
    check();
    late Map<String, dynamic> request;
    await parent.database.transaction(() async {
      final stored = await local(input.profileId) ?? input;
      if (stored.pending != null) {
        // Replay exact request even if local input changed during uncertainty.
        request = stored.pending!;
        return;
      }
      if (!input.value.valid) throw StateError('EXTRAS_INVALID');
      final raw = await parent.database.draftFor(parent.user, input.profileId);
      _personalGuard(raw, input.version);
      if (await parent.database.pendingMutation(parent.user, input.profileId) !=
          null) {
        throw StateError('OTHER_SAVE_PENDING');
      }
      request = {
        'command_key': newCommandKey(),
        'requested_profile': input.profileId,
        'expected_profile_version': input.version,
        'extras': input.value.payload(),
        'personal_baseline': raw,
        'input_baseline': input.encode(),
      };
      await parent.database.setSetting(
        key(input.profileId),
        ExtrasDraft(
          profileId: input.profileId,
          version: input.version,
          value: input.value,
          pending: request,
        ).encode(),
      );
      check();
    });
    CareerProfile acknowledged;
    try {
      acknowledged = await api.save(request);
      check();
    } on PostgrestException catch (error) {
      check();
      final known = [
        'VERSION_CONFLICT',
        'VALIDATION_FAILED',
        'FORBIDDEN',
        'ACCOUNT_DELETING',
        'AUTH_REQUIRED',
        'IDEMPOTENCY_KEY_REUSE',
      ].any(error.message.contains);
      if (known) {
        await parent.database.transaction(() async {
          final current = await local(input.profileId);
          if (current?.pending?['command_key'] == request['command_key']) {
            await parent.database.setSetting(
              key(input.profileId),
              ExtrasDraft(
                profileId: current!.profileId,
                version: current.version,
                value: current.value,
              ).encode(),
            );
          }
        });
      }
      rethrow;
    }
    if (acknowledged.id != input.profileId ||
        acknowledged.version !=
            (request['expected_profile_version'] as int) + 1) {
      throw StateError('SAVE_NOT_CONFIRMED');
    }
    late ExtrasDraft resulting;
    var safe = false;
    await parent.database.transaction(() async {
      check();
      final current = await local(input.profileId) ?? input;
      if (current.pending?['command_key'] != request['command_key']) {
        throw StateError('EXTRAS_BASELINE_CHANGED');
      }
      final personalRaw = await parent.database.draftFor(
        parent.user,
        input.profileId,
      );
      safe = personalRaw == request['personal_baseline'];
      if (safe && personalRaw != null) {
        final original = PersonalDraft.decode(personalRaw);
        _personalGuard(personalRaw, request['expected_profile_version'] as int);
        await parent.database.saveDraft(
          parent.user,
          input.profileId,
          PersonalDraft(
            profileId: original.profileId,
            baseVersion: acknowledged.version,
            personal: original.personal,
            resumeLanguage: original.resumeLanguage,
          ).encode(),
        );
      }
      resulting = ExtrasDraft(
        profileId: current.profileId,
        version: acknowledged.version,
        value: current.value,
      );
      await parent.database.setSetting(
        key(input.profileId),
        resulting.encode(),
      );
      final cache = await parent.database.firstCachedProfile(parent.user);
      final cacheVersion = cache == null
          ? -1
          : CareerProfile.fromJson(
              jsonDecode(cache) as Map<String, dynamic>,
            ).version;
      if (cacheVersion <= acknowledged.version) {
        await parent.database.cacheProfile(
          parent.user,
          acknowledged.id,
          acknowledged.encode(),
        );
      }
      check();
    });
    final unsent =
        jsonEncode(resulting.value.payload()) != jsonEncode(request['extras']);
    return ExtrasSaveResult(acknowledged, resulting, safe, unsent);
  }

  /// Only called after displaying latest server content and an explicit choice.
  /// Personal edits must already be reconciled; this cannot resolve them.
  Future<ExtrasDraft> reapply(ExtrasDraft draft, CareerProfile latest) async {
    check();
    return parent.database.transaction(() async {
      final existing = await local(draft.profileId);
      if (existing?.pending != null) throw StateError('SAVE_OUTCOME_UNKNOWN');
      _personalGuard(
        await parent.database.draftFor(parent.user, draft.profileId),
        latest.version,
      );
      final result = ExtrasDraft(
        profileId: draft.profileId,
        version: latest.version,
        value: draft.value,
      );
      await parent.database.setSetting(key(draft.profileId), result.encode());
      check();
      return result;
    });
  }
}

final profileExtrasRepositoryProvider = FutureProvider<ProfileExtrasRepository>(
  (ref) async => ProfileExtrasRepository(
    await ref.watch(draftRepositoryProvider.future),
    SupabaseProfileExtrasApi(await ref.watch(supabaseClientProvider.future)),
  ),
);
