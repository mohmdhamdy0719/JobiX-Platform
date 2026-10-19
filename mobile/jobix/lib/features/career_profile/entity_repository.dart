import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import 'career_profile.dart';
import 'career_profile_repository.dart';
import 'profile_sections.dart';

/// Server rejections that are known not to have applied the command.
const knownRejections = [
  'VERSION_CONFLICT',
  'VALIDATION_FAILED',
  'DUPLICATE_ITEM',
  'ITEM_NOT_FOUND',
  'FORBIDDEN',
  'ACCOUNT_DELETING',
  'AUTH_REQUIRED',
  'IDEMPOTENCY_KEY_REUSE',
];

String? rejectionCode(Object error) {
  if (error is! PostgrestException) return null;
  for (final code in knownRejections) {
    if (error.message.contains(code)) return code;
  }
  return null;
}

/// How a local draft relates to the server copy of the same item. A draft
/// keeps the item version it started from; any difference means the item
/// changed elsewhere and the user must choose, never a silent overwrite.
enum DraftConflict { none, changed, removed }

DraftConflict draftConflict(ProfileItem local, ProfileItem? server) {
  if (server == null) {
    return local.version > 0 ? DraftConflict.removed : DraftConflict.none;
  }
  return server.version == local.version
      ? DraftConflict.none
      : DraftConflict.changed;
}

/// One unacknowledged section command. It is persisted before sending and
/// retried with the same key after a restart until the server answers.
class PendingMutation {
  const PendingMutation({
    required this.profileId,
    required this.key,
    required this.version,
    required this.type,
    required this.section,
    required this.value,
  });
  final String profileId, key, type, section;
  final int version;
  final Map<String, Object?> value;
  String get itemId => value['id'] as String;
  Map<String, Object?> toJson() => {
    'profile': profileId,
    'key': key,
    'version': version,
    'type': type,
    'section': section,
    'value': value,
  };
  String encode() => jsonEncode(toJson());
  factory PendingMutation.decode(String raw) {
    final v = jsonDecode(raw) as Map<String, dynamic>;
    return PendingMutation(
      profileId: v['profile'] as String,
      key: v['key'] as String,
      version: v['version'] as int,
      type: v['type'] as String,
      section: v['section'] as String,
      value: Map<String, Object?>.from(v['value'] as Map),
    );
  }
}

typedef MutationSend = Future<CareerProfile> Function(PendingMutation request);

class PendingSaveException implements Exception {
  const PendingSaveException();
  @override
  String toString() => 'SAVE_PENDING';
}

class EntityRepository {
  EntityRepository(this.parent, this.send);
  final DraftRepository parent;
  final MutationSend send;

  String _draftKey(EntitySection section, String id) =>
      'entity:${section.key}:$id';
  void _check() {
    if (!parent.isCurrentUser()) throw StateError('AUTH_REQUIRED');
  }

  Future<void> _guard() async {
    if (!parent.isCurrentUser()) {
      await parent.database.clearAccount(parent.user);
      throw StateError('AUTH_REQUIRED');
    }
  }

  Future<ProfileItem?> draft(
    String profile,
    EntitySection section,
    String id,
  ) async {
    _check();
    final unresolved = await pending(profile);
    if (unresolved?.type == 'upsert_item' &&
        unresolved?.section == section.key &&
        unresolved?.itemId == id) {
      return ProfileItem.fromJson(section, unresolved!.value);
    }
    final raw = await parent.database.sectionDraft(
      parent.user,
      profile,
      _draftKey(section, id),
    );
    _check();
    if (raw == null) return null;
    // Legacy entity edits were persisted on each keystroke. They are not
    // server-confirmed and must not be restored in a newly opened editor.
    await parent.database.discardSection(
      parent.user,
      profile,
      _draftKey(section, id),
    );
    _check();
    return null;
  }

  /// An unresolved explicit save is recoverable; ordinary unsaved items are
  /// intentionally held only in the editor's in-memory state.
  Future<List<ProfileItem>> unsavedNew(
    CareerProfile profile,
    EntitySection section,
  ) async {
    final unresolved = await pending(profile.id);
    if (unresolved?.type == 'upsert_item' &&
        unresolved?.section == section.key &&
        !profile.of(section).any((item) => item.id == unresolved!.itemId)) {
      return [ProfileItem.fromJson(section, unresolved!.value)];
    }
    final keys = await parent.database.sectionDraftKeys(
      parent.user,
      profile.id,
      'entity:${section.key}:',
    );
    for (final key in keys) {
      await parent.database.discardSection(parent.user, profile.id, key);
    }
    _check();
    return const [];
  }

  Future<void> retainDraft(String profile, ProfileItem item) async {
    _check();
    // An unresolved request is immutable and must not be replaced by later
    // keystrokes. Otherwise there is no durable unsaved draft to retain.
    if (await pending(profile) == null) {
      await parent.database.discardSection(
        parent.user,
        profile,
        _draftKey(item.section, item.id),
      );
    }
    await _guard();
  }

  Future<void> discardDraft(
    String profile,
    EntitySection section,
    String id,
  ) async {
    _check();
    await parent.database.discardSection(
      parent.user,
      profile,
      _draftKey(section, id),
    );
  }

  Future<PendingMutation?> pending(String profile) async {
    _check();
    final raw = await parent.database.pendingMutation(parent.user, profile);
    return raw == null ? null : PendingMutation.decode(raw);
  }

  /// Retries an interrupted command with its original key. Returns the
  /// acknowledged profile, or null when nothing was pending.
  Future<CareerProfile?> resume(String profile) async {
    final request = await pending(profile);
    if (request == null) return null;
    return _deliver(request);
  }

  Future<CareerProfile> upsert(CareerProfile profile, ProfileItem item) =>
      _start(profile, 'upsert_item', item.section, item.payload());

  Future<CareerProfile> delete(
    CareerProfile profile,
    EntitySection section,
    String id,
  ) => _start(profile, 'delete_item', section, {'id': id});

  Future<CareerProfile> _start(
    CareerProfile profile,
    String type,
    EntitySection section,
    Map<String, Object?> value,
  ) async {
    _check();
    // Never queue behind an unknown outcome: it must be reconciled first.
    if (await pending(profile.id) != null) throw const PendingSaveException();
    final request = PendingMutation(
      profileId: profile.id,
      key: newCommandKey(),
      version: profile.version,
      type: type,
      section: section.key,
      value: value,
    );
    await parent.database.retainPendingMutation(
      parent.user,
      profile.id,
      request.encode(),
    );
    await _guard();
    return _deliver(request);
  }

  Future<CareerProfile> _deliver(PendingMutation request) async {
    _check();
    final CareerProfile result;
    try {
      result = await send(request);
    } catch (error) {
      if (rejectionCode(error) != null) {
        // Not applied; the editor keeps its current value in memory only.
        await _guard();
        await parent.database.discardPendingMutation(
          parent.user,
          request.profileId,
        );
        await _guard();
      }
      rethrow;
    }
    _check();
    await parent.database.discardPendingMutation(
      parent.user,
      request.profileId,
    );
    await parent.database.cacheProfile(parent.user, result.id, result.encode());
    await _guard();
    final section = EntitySection.parse(request.section);
    await discardDraft(request.profileId, section, request.itemId);
    return result;
  }
}

final entityRepositoryProvider = FutureProvider<EntityRepository>((ref) async {
  final parent = await ref.watch(draftRepositoryProvider.future);
  final client = await ref.watch(supabaseClientProvider.future);
  return EntityRepository(parent, (request) async {
    final response = await client
        .rpc(
          'profile_mutate',
          params: {
            'command_key': request.key,
            'requested_profile': request.profileId,
            'expected_profile_version': request.version,
            'mutation': {
              'type': request.type,
              'section': request.section,
              'value': request.value,
            },
          },
        )
        .timeout(const Duration(seconds: 15));
    return acknowledgedProfile(response);
  });
});
