import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database.dart';
import '../career_profile/career_profile.dart';
import 'resume_layout.dart';

class ResumeLayoutSaveFailure implements Exception {
  const ResumeLayoutSaveFailure(this.code);
  final String code;
}

/// Uses the existing encrypted, account-cleaned resume settings namespace.
/// A timed-out save is frozen and retried, never silently replaced/discarded.
class ResumeLayoutRepository {
  ResumeLayoutRepository({
    required this.database,
    required this.user,
    required this.profileId,
    required this.isCurrentUser,
    required this.saveRemote,
  });
  final AppDatabase database;
  final String user, profileId;
  final bool Function() isCurrentUser;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) saveRemote;
  String get key => 'resume:$user:layout:$profileId';

  void _authorize() {
    if (!isCurrentUser()) throw const ResumeLayoutSaveFailure('AUTH_REQUIRED');
  }

  Future<Map<String, dynamic>?> pending() async {
    _authorize();
    final raw = await database.setting(key);
    _authorize();
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<Map<String, dynamic>> save({
    required ResumeLayout layout,
    required int profileVersion,
    required int configurationVersion,
    required String language,
  }) async {
    _authorize();
    final existing = await pending();
    final hadPending = existing != null;
    final request =
        existing ??
        {
          'command_key': newCommandKey(),
          'requested_profile': profileId,
          'expected_profile_version': profileVersion,
          'expected_configuration_version': configurationVersion,
          'language': language,
          'hidden_sections': [...layout.hidden]..sort(),
          'section_order': layout.order,
        };
    if (request['requested_profile'] != profileId ||
        ResumeLayout(
              order: List<String>.from(request['section_order'] as List),
              hidden: Set<String>.from(request['hidden_sections'] as List),
            ).fingerprint !=
            layout.fingerprint) {
      throw const ResumeLayoutSaveFailure('PENDING_SAVE');
    }
    await database.setSetting(key, jsonEncode(request));
    _authorize();
    Map<String, dynamic> result;
    try {
      result = await saveRemote(request);
    } on PostgrestException catch (error) {
      _authorize();
      final code = error.code == 'PGRST202'
          ? 'BACKEND_UPDATE_REQUIRED'
          : error.message == 'VERSION_CONFLICT'
          ? 'VERSION_CONFLICT'
          : null;
      if (code == null) rethrow;
      // A newly created request rejected because the RPC is absent was never
      // applied, so it is safe to discard on exit. An older unresolved request
      // may have succeeded before the backend became unavailable; retain that
      // exact identity until the same request can be reconciled.
      if (code != 'BACKEND_UPDATE_REQUIRED' || !hadPending) {
        await database.removeSetting(key);
      }
      throw ResumeLayoutSaveFailure(code);
    }
    _authorize();
    if (result['profile_id'] != profileId ||
        result['language'] != request['language'] ||
        result['version'] is! int ||
        (result['version'] as int) <=
            (request['expected_configuration_version'] as num) ||
        result['render_config_version'] != ResumeLayout.renderVersion ||
        result['template_version'] != ResumeLayout.templateVersion ||
        ResumeLayout.fromConfiguration(result).fingerprint !=
            layout.fingerprint) {
      throw const ResumeLayoutSaveFailure('SAVE_NOT_CONFIRMED');
    }
    await database.removeSetting(key);
    return result;
  }

  Future<Map<String, dynamic>> retryPending() async {
    _authorize();
    final request = await pending();
    if (request == null) {
      throw const ResumeLayoutSaveFailure('NO_PENDING_SAVE');
    }
    final layout = ResumeLayout(
      order: List<String>.from(request['section_order'] as List),
      hidden: Set<String>.from(request['hidden_sections'] as List),
    );
    return save(
      layout: layout,
      profileVersion: (request['expected_profile_version'] as num).toInt(),
      configurationVersion: (request['expected_configuration_version'] as num)
          .toInt(),
      language: request['language'] as String,
    );
  }
}
