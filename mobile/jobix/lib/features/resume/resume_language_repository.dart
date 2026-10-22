import 'dart:convert';

import '../../core/database/database.dart';
import '../career_profile/career_profile.dart';

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
      language: language as String? ??
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
    _authorize();
    final pendingRaw = await database.setting(key);
    _authorize();
    final String raw;
    if (pendingRaw != null) {
      raw = pendingRaw;
      final request = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (request['requested_profile'] != profileId ||
          request['language'] != language ||
          request['expected_version'] is! int ||
          request['command_key'] is! String) {
        throw StateError('PENDING_RESUME_CONFIGURATION_REQUIRES_RECONCILIATION');
      }
    } else {
      raw = jsonEncode({
        'command_key': newCommandKey(),
        'requested_profile': profileId,
        'expected_version': expectedVersion,
        'language': language,
        'template_id': 'resume_ats_${language}_v1',
      });
      await database.setSetting(key, raw);
    }
    _authorize();
    final request = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final result = await saveRemote(request);
    _authorize();
    if (result['language'] != request['language'] ||
        result['version'] is! int) {
      throw StateError('SAVE_NOT_CONFIRMED');
    }
    await database.removeSetting(key);
    _authorize();
    return result['version'] as int;
  }
}
