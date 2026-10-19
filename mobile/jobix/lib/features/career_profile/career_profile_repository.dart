import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database.dart';
import 'career_profile.dart';
import '../onboarding/research_context.dart';

abstract interface class ProfileApi {
  Future<bool> claimRegistrationEntry();
  Future<CareerProfile> firstProfile();
  Future<CareerProfile> save(PersonalDraft draft);
  Future<void> saveContext(ResearchProgress progress);
}

class SupabaseProfileApi implements ProfileApi {
  SupabaseProfileApi(this.client);
  final SupabaseClient client;
  @override
  Future<bool> claimRegistrationEntry() async =>
      await client
              .rpc('claim_registration_entry')
              .timeout(const Duration(seconds: 15))
          as bool;
  @override
  Future<CareerProfile> firstProfile() async {
    final row = await client
        .rpc('first_career_profile')
        .timeout(const Duration(seconds: 15));
    return CareerProfile.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<CareerProfile> save(PersonalDraft draft) async {
    final frozen = draft.frozen!;
    final row = await client
        .rpc(
          'profile_mutate',
          params: {
            'command_key': draft.commandKey,
            'requested_profile': draft.profileId,
            'expected_profile_version': frozen['version'],
            'mutation': {
              'type': 'upsert_item',
              'section': 'personal',
              'value': {
                'personal': frozen['personal'],
                'resume_language': frozen['language'],
              },
            },
          },
        )
        .timeout(const Duration(seconds: 15));
    return acknowledgedProfile(row);
  }

  @override
  Future<void> saveContext(ResearchProgress progress) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw StateError('AUTH_REQUIRED');
    final existing = await client
        .from('onboarding_context')
        .select('version')
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    // Do not silently overwrite returning-account context.
    if (client.auth.currentUser?.id != owner) throw StateError('AUTH_REQUIRED');
    if (existing != null) return;
    await client
        .rpc(
          'save_onboarding',
          params: {
            'command_key': progress.commandKey,
            'expected_version': 0,
            'answers': progress.answers,
          },
        )
        .timeout(const Duration(seconds: 15));
  }
}

/// Reads a profile_mutate acknowledgement; anything but SUCCEEDED is unconfirmed.
CareerProfile acknowledgedProfile(Object? response) {
  final envelope = Map<String, dynamic>.from(response as Map);
  if (envelope['state'] != 'SUCCEEDED' || envelope['data'] is! Map) {
    throw StateError('SAVE_NOT_CONFIRMED');
  }
  return CareerProfile.fromJson(
    Map<String, dynamic>.from(envelope['data'] as Map),
  );
}

class DraftRepository {
  DraftRepository(this.database, this.api, this.user, this.isCurrentUser);
  final AppDatabase database;
  final ProfileApi api;
  final String user;
  final bool Function() isCurrentUser;
  Future<void> _check() async {
    if (!isCurrentUser()) throw StateError('AUTH_REQUIRED');
  }

  Future<CareerProfile> load({bool freshOnly = false}) async {
    await _check();
    try {
      final profile = await api.firstProfile();
      await _check();
      await database.cacheProfile(user, profile.id, profile.encode());
      if (!isCurrentUser()) {
        await database.clearAccount(user);
        throw StateError('AUTH_REQUIRED');
      }
      return profile;
    } catch (error) {
      await _check();
      // Only network failures may use an acknowledged cache; never suppress
      // authorization/lifecycle/provisioning failures.
      if (freshOnly ||
          (error is! SocketException && error is! TimeoutException)) {
        rethrow;
      }
      final cache = await database.firstCachedProfile(user);
      if (cache == null) rethrow;
      return CareerProfile.fromJson(jsonDecode(cache) as Map<String, dynamic>);
    }
  }

  Future<PersonalDraft?> draft(CareerProfile profile) async {
    await _check();
    final raw = await database.draftFor(user, profile.id);
    await _check();
    if (raw == null) return null;
    final saved = PersonalDraft.decode(raw);
    if (saved.frozen != null) return saved;

    // Older app versions stored every keystroke as a local draft. Those
    // values are not authoritative and must not reappear when an editor opens.
    await database.discardDraft(user, profile.id);
    await _check();
    return null;
  }

  Future<void> retain(PersonalDraft draft) async {
    await _check();
    if (draft.frozen == null) {
      final existing = await database.draftFor(user, draft.profileId);
      if (existing != null && PersonalDraft.decode(existing).frozen != null) {
        // Never replace an unresolved, exact request with editable input.
        return;
      }
      await database.discardDraft(user, draft.profileId);
      await _check();
      return;
    }
    final existing = await database.draftFor(user, draft.profileId);
    if (existing != null && PersonalDraft.decode(existing).frozen != null) {
      // The original complete request wins. Never rewrite even its editable
      // wrapper fields while reconciling an uncertain outcome.
      return;
    }
    await database.saveDraft(user, draft.profileId, draft.encode());
    if (!isCurrentUser()) {
      await database.clearAccount(user);
      throw StateError('AUTH_REQUIRED');
    }
  }

  Future<CareerProfile> save(PersonalDraft draft) async {
    await _check();
    final pending = await database.draftFor(user, draft.profileId);
    if (pending != null && PersonalDraft.decode(pending).frozen != null) {
      final previous = PersonalDraft.decode(pending);
      draft = previous;
    }
    final request = draft.frozen == null
        ? PersonalDraft(
            profileId: draft.profileId,
            baseVersion: draft.baseVersion,
            personal: draft.personal,
            resumeLanguage: draft.resumeLanguage,
            commandKey: newCommandKey(),
            frozen: {
              'version': draft.baseVersion,
              'personal': draft.personal,
              'language': draft.resumeLanguage,
            },
          )
        : draft;
    // Durable request identity is part of the draft, not an outbox/worker.
    await retain(request);
    await _check();
    CareerProfile profile;
    try {
      profile = await api.save(request);
    } on PostgrestException catch (error) {
      if ([
        'VERSION_CONFLICT',
        'VALIDATION_FAILED',
        'FORBIDDEN',
        'ACCOUNT_DELETING',
        'AUTH_REQUIRED',
      ].any(error.message.contains)) {
        // These transactional rejections are known not to have applied.
        // Keep the user's edits only in the open editor; a later open must
        // start from the current server version.
        await _check();
        await database.discardDraft(user, request.profileId);
        await _check();
      }
      rethrow;
    }
    await _check();
    await database.cacheProfile(user, profile.id, profile.encode());
    if (!isCurrentUser()) {
      await database.clearAccount(user);
      throw StateError('AUTH_REQUIRED');
    }
    final latest = await database.draftFor(user, draft.profileId);
    if (latest == request.encode()) {
      await database.discardDraft(user, draft.profileId);
    }
    return profile;
  }

  Future<void> discard(String profile) async {
    await _check();
    final raw = await database.draftFor(user, profile);
    if (raw != null && PersonalDraft.decode(raw).frozen != null) {
      // Unknown outcomes must be reconciled, not silently discarded and replayed.
      throw StateError('SAVE_OUTCOME_UNKNOWN');
    }
    await database.discardDraft(user, profile);
  }
}
