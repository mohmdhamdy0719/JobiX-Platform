import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../career_profile/career_profile.dart';

final savedResumeLanguageProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, profileId) async {
      ref.watch(authSessionProvider);
      final client = await ref.watch(supabaseClientProvider.future);
      final actor = client.auth.currentUser?.id;
      if (actor == null) throw StateError('AUTH_REQUIRED');
      final value = await client
          .rpc(
            'read_resume_configuration',
            params: {'requested_profile': profileId},
          )
          .timeout(const Duration(seconds: 15));
      if (client.auth.currentUser?.id != actor) {
        throw StateError('AUTH_REQUIRED');
      }
      if (value == null) return null;
      final language = (value as Map)['language'];
      if (!const ['en', 'ar'].contains(language)) {
        throw StateError('UNSUPPORTED_SAVED_CONFIGURATION');
      }
      return language as String;
    });

class ResumeLanguageState {
  const ResumeLanguageState({
    required this.language,
    required this.version,
    this.pending = false,
  });

  final String language;
  final int version;
  final bool pending;
}

class ResumeLanguageConflict implements Exception {
  const ResumeLanguageConflict(this.latest);
  final ResumeLanguageState latest;
}

typedef ReadResumeConfiguration =
    Future<Map<String, dynamic>?> Function(String profileId);
typedef SaveResumeConfiguration =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);

/// Persists language changes through the existing versioned configuration RPC.
/// Uncertain writes retain their exact request for same-key reconciliation.
class ResumeLanguageRepository {
  ResumeLanguageRepository({
    required this.database,
    required this.user,
    required this.profileId,
    required this.isCurrentUser,
    required this.readRemote,
    required this.saveRemote,
  });

  final AppDatabase database;
  final String user;
  final String profileId;
  final bool Function() isCurrentUser;
  final ReadResumeConfiguration readRemote;
  final SaveResumeConfiguration saveRemote;

  String get key => 'resume:$user:$profileId';

  void _authorize() {
    if (!isCurrentUser()) throw StateError('AUTH_REQUIRED');
  }

  Future<ResumeLanguageState> load({
    required String? profileLanguage,
    required String appLanguage,
  }) async {
    _authorize();
    final raw = await database.setting(key);
    _authorize();
    if (raw != null) {
      final request = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (request['requested_profile'] != profileId ||
          request['language'] is! String ||
          !const ['en', 'ar'].contains(request['language']) ||
          request['expected_version'] is! int ||
          request['command_key'] is! String) {
        throw StateError('INVALID_PENDING_RESUME_CONFIGURATION');
      }
      return ResumeLanguageState(
        language: request['language'] as String,
        version: request['expected_version'] as int,
        pending: true,
      );
    }

    final saved = await readRemote(profileId);
    _authorize();
    final language = saved?['language'];
    final version = saved?['version'];
    if (language != null &&
        (language is! String || !const ['en', 'ar'].contains(language))) {
      throw StateError('UNSUPPORTED_SAVED_CONFIGURATION');
    }
    if (version != null && version is! int) {
      throw StateError('INVALID_RESUME_CONFIGURATION_VERSION');
    }
    return ResumeLanguageState(
      language:
          language as String? ??
          (const ['en', 'ar'].contains(profileLanguage)
              ? profileLanguage!
              : appLanguage),
      version: version as int? ?? 0,
    );
  }

  Future<int> save(String language, int expectedVersion) async {
    if (!const ['en', 'ar'].contains(language)) {
      throw ArgumentError.value(language, 'language');
    }
    final raw = await database.transaction(() async {
      _authorize();
      final pendingRaw = await database.setting(key);
      _authorize();
      if (pendingRaw != null) {
        final request = Map<String, dynamic>.from(
          jsonDecode(pendingRaw) as Map,
        );
        if (request['requested_profile'] != profileId ||
            request['language'] != language ||
            request['expected_version'] is! int ||
            request['command_key'] is! String) {
          throw StateError(
            'PENDING_RESUME_CONFIGURATION_REQUIRES_RECONCILIATION',
          );
        }
        return pendingRaw;
      }
      final created = jsonEncode({
        'command_key': newCommandKey(),
        'requested_profile': profileId,
        'expected_version': expectedVersion,
        'language': language,
        'template_id': 'resume_ats_${language}_v1',
      });
      await database.setSetting(key, created);
      return created;
    });
    _authorize();
    final request = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final Map<String, dynamic> result;
    try {
      result = await saveRemote(request);
    } on PostgrestException catch (error) {
      // This RPC checks the original idempotency key before VERSION_CONFLICT.
      // An explicit conflict therefore rejects this request, unlike a timeout.
      if (!error.message.contains('VERSION_CONFLICT')) rethrow;
      _authorize();
      final latest = await readRemote(profileId);
      _authorize();
      if (latest == null ||
          !const ['en', 'ar'].contains(latest['language']) ||
          latest['version'] is! int ||
          latest['version'] == request['expected_version']) {
        rethrow;
      }
      await _clearExact(raw);
      throw ResumeLanguageConflict(
        ResumeLanguageState(
          language: latest['language'] as String,
          version: latest['version'] as int,
        ),
      );
    }
    _authorize();
    if (result['language'] != request['language'] ||
        result['version'] is! int ||
        (result['profile_id'] != null && result['profile_id'] != profileId)) {
      throw StateError('SAVE_NOT_CONFIRMED');
    }
    await _clearExact(raw);
    return result['version'] as int;
  }

  Future<void> _clearExact(String raw) => database.transaction(() async {
    _authorize();
    final current = await database.setting(key);
    if (current == null) return;
    if (current != raw) {
      throw StateError('PENDING_RESUME_CONFIGURATION_CHANGED');
    }
    await database.removeSetting(key);
    _authorize();
  });
}
