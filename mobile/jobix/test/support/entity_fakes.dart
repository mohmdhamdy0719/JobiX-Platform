import 'dart:io';

import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/entity_repository.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'slice_fakes.dart';

/// In-memory stand-in for the `profile_mutate` RPC with the same contract
/// semantics: optimistic version check, idempotent command keys and typed
/// rejections. It edits the shared [FakeProfileApi.server] snapshot.
class FakeEntityServer {
  FakeEntityServer(this.api);
  final FakeProfileApi api;
  final List<PendingMutation> requests = [];
  final Map<String, CareerProfile> _byKey = {};
  final Map<String, String> _payloads = {};
  final Map<EntitySection, List<ProfileItem>> draftItems = {};
  bool offline = false, loseNextResponse = false;
  String? rejectNext;

  Future<List<ProfileItem>> loadDrafts(
    String profileId,
    EntitySection section,
  ) async {
    if (offline) throw const SocketException('Offline fixture');
    return profileId == api.server.id
        ? List.of(draftItems[section] ?? const [])
        : const [];
  }

  Future<CareerProfile> send(PendingMutation request) async {
    requests.add(request);
    if (offline) throw const SocketException('Offline fixture');
    final replay = _byKey[request.key];
    if (replay != null) {
      if (_payloads[request.key] != request.encode()) {
        throw const PostgrestException(message: 'IDEMPOTENCY_KEY_REUSE');
      }
      return replay;
    }
    if (rejectNext case final String code) {
      rejectNext = null;
      throw PostgrestException(message: code, code: 'P0001');
    }
    if (request.version != api.server.version) {
      throw const PostgrestException(
        message: 'VERSION_CONFLICT',
        code: 'P0001',
      );
    }
    final section = EntitySection.parse(request.section);
    final items = [...api.server.of(section)];
    final index = items.indexWhere((i) => i.id == request.itemId);
    final drafts = List<ProfileItem>.of(draftItems[section] ?? const []);
    final draftIndex = drafts.indexWhere((i) => i.id == request.itemId);
    if (request.type == 'delete_item') {
      if (request.isDraft && index >= 0) {
        throw const PostgrestException(message: 'VERSION_CONFLICT');
      }
      if (index < 0 && draftIndex < 0) {
        throw const PostgrestException(
          message: 'ITEM_NOT_FOUND',
          code: 'P0001',
        );
      }
      if (index >= 0) items.removeAt(index);
      if (draftIndex >= 0) drafts.removeAt(draftIndex);
    } else {
      final draft = ProfileItem.fromJson(section, request.value);
      final saved = ProfileItem(
        id: draft.id,
        section: section,
        version: index >= 0
            ? items[index].version + 1
            : draftIndex >= 0
            ? drafts[draftIndex].version + 1
            : 1,
        complete: !request.isDraft && draft.locallyComplete,
        isDraft: request.isDraft,
        values: draft.values,
      );
      if (index >= 0) items.removeAt(index);
      if (draftIndex >= 0) drafts.removeAt(draftIndex);
      if (request.isDraft) {
        drafts.add(saved);
      } else {
        items.add(saved);
      }
    }
    draftItems[section] = drafts;
    final current = api.server;
    api.server = CareerProfile(
      id: current.id,
      version: current.version + 1,
      resumeLanguage: current.resumeLanguage,
      personal: current.personal,
      summary: current.summary,
      targetRole: current.targetRole,
      completeness: current.completeness,
      algorithm: current.algorithm,
      summaryState: current.summaryState,
      targetRoleState: current.targetRoleState,
      slot: current.slot,
      items: {...current.items, section: items},
    );
    _byKey[request.key] = api.server;
    _payloads[request.key] = request.encode();
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const SocketException('Response lost fixture');
    }
    return api.server;
  }
}
