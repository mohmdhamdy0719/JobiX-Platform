import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import 'career_profile.dart';
import 'career_profile_repository.dart';

const textSections = ['summary', 'target_role'];

class TextSectionDraft {
  const TextSectionDraft({
    required this.profileId,
    required this.section,
    required this.version,
    required this.text,
    this.key,
    this.request,
  });
  final String profileId, section, text;
  final int version;
  final String? key;
  final Map<String, dynamic>? request;
  TextSectionDraft edit(String value) => TextSectionDraft(
    profileId: profileId,
    section: section,
    version: version,
    text: value,
    key: key,
    request: request,
  );
  Map<String, dynamic> toJson() => {
    'profile': profileId,
    'section': section,
    'version': version,
    'text': text,
    'key': key,
    'request': request,
  };
  String encode() => jsonEncode(toJson());
  factory TextSectionDraft.decode(String raw) {
    final v = jsonDecode(raw) as Map<String, dynamic>;
    return TextSectionDraft(
      profileId: v['profile'] as String,
      section: v['section'] as String,
      version: v['version'] as int,
      text: v['text'] as String,
      key: v['key'] as String?,
      request: v['request'] == null
          ? null
          : Map<String, dynamic>.from(v['request'] as Map),
    );
  }
}

typedef TextSectionSave =
    Future<CareerProfile> Function(TextSectionDraft draft);

class TextSectionRepository {
  TextSectionRepository(this.parent, this.send);
  final DraftRepository parent;
  final TextSectionSave send;
  void check() {
    if (!parent.isCurrentUser()) throw StateError('AUTH_REQUIRED');
  }

  Future<TextSectionDraft?> load(CareerProfile profile, String section) async {
    check();
    final raw = await parent.database.sectionDraft(
      parent.user,
      profile.id,
      section,
    );
    check();
    if (raw == null) return null;
    final saved = TextSectionDraft.decode(raw);
    if (saved.request != null) return saved;

    // Discard legacy keystroke drafts. The editable value is now held only by
    // the open screen; only an exact submitted request survives a restart.
    await parent.database.discardSection(parent.user, profile.id, section);
    check();
    return null;
  }

  Future<void> retain(TextSectionDraft draft) async {
    check();
    if (!textSections.contains(draft.section)) {
      throw ArgumentError('Unknown section');
    }
    if (draft.request == null) {
      final existing = await parent.database.sectionDraft(
        parent.user,
        draft.profileId,
        draft.section,
      );
      if (existing != null &&
          TextSectionDraft.decode(existing).request != null) {
        return;
      }
      await parent.database.discardSection(
        parent.user,
        draft.profileId,
        draft.section,
      );
      check();
      return;
    }
    await parent.database.retainSection(
      parent.user,
      draft.profileId,
      draft.section,
      draft.encode(),
    );
    if (!parent.isCurrentUser()) {
      await parent.database.clearAccount(parent.user);
      check();
    }
  }

  Future<CareerProfile> save(TextSectionDraft draft) async {
    check();
    final existing = await parent.database.sectionDraft(
      parent.user,
      draft.profileId,
      draft.section,
    );
    final previous = existing == null
        ? null
        : TextSectionDraft.decode(existing);
    final pending = previous?.request;
    final request = TextSectionDraft(
      profileId: draft.profileId,
      section: draft.section,
      version: draft.version,
      text: draft.text,
      key: pending != null ? previous!.key : draft.key ?? newCommandKey(),
      request:
          pending ??
          draft.request ??
          {'version': draft.version, 'text': draft.text},
    );
    await retain(request);
    check();
    CareerProfile result;
    try {
      result = await send(request);
    } on PostgrestException catch (e) {
      if ([
        'VERSION_CONFLICT',
        'VALIDATION_FAILED',
        'ACCOUNT_DELETING',
        'FORBIDDEN',
        'AUTH_REQUIRED',
      ].contains(e.message)) {
        // A confirmed rejection did not apply. Keep the current text in the
        // open editor only; reopening will load the authoritative profile.
        check();
        await parent.database.discardSection(
          parent.user,
          request.profileId,
          request.section,
        );
        check();
      }
      rethrow;
    }
    check();
    await parent.database.cacheProfile(parent.user, result.id, result.encode());
    if (!parent.isCurrentUser()) {
      await parent.database.clearAccount(parent.user);
      check();
    }
    final latest = await parent.database.sectionDraft(
      parent.user,
      draft.profileId,
      draft.section,
    );
    if (latest == request.encode()) {
      check();
      await parent.database.discardSection(
        parent.user,
        draft.profileId,
        draft.section,
      );
      check();
    }
    check();
    return result;
  }

  Future<void> discard(CareerProfile profile, String section) async {
    final local = await load(profile, section);
    if (local?.request != null) throw StateError('SAVE_OUTCOME_UNKNOWN');
    await parent.database.discardSection(parent.user, profile.id, section);
    check();
  }
}

final textSectionRepositoryProvider = FutureProvider<TextSectionRepository>((
  ref,
) async {
  final parent = await ref.watch(draftRepositoryProvider.future);
  final client = await ref.watch(supabaseClientProvider.future);
  return TextSectionRepository(parent, (draft) async {
    final response = await client
        .rpc(
          'profile_mutate',
          params: {
            'command_key': draft.key,
            'requested_profile': draft.profileId,
            'expected_profile_version': draft.request!['version'],
            'mutation': {
              'type': 'upsert_item',
              'section': draft.section,
              'value': {'text': draft.request!['text']},
            },
          },
        )
        .timeout(const Duration(seconds: 15));
    final envelope = Map<String, dynamic>.from(response as Map);
    if (envelope['state'] != 'SUCCEEDED') {
      throw StateError('SAVE_NOT_CONFIRMED');
    }
    return CareerProfile.fromJson(
      Map<String, dynamic>.from(envelope['data'] as Map),
    );
  });
});
