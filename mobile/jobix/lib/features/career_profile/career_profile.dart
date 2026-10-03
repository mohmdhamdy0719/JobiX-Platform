import 'dart:convert';
import 'dart:math';

const personalFields = [
  'full_name',
  'email',
  'phone',
  'country',
  'city',
  'linkedin_url',
  'github_url',
  'portfolio_url',
];

String newCommandKey() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

class CareerProfile {
  const CareerProfile({
    required this.id,
    required this.version,
    this.resumeLanguage,
    this.personal = const {},
  });
  final String id;
  final int version;
  final String? resumeLanguage;
  final Map<String, String> personal;
  factory CareerProfile.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['personal'] as Map? ?? {});
    return CareerProfile(
      id: (json['profile_id'] ?? json['id']) as String,
      version: (json['profile_version'] as num).toInt(),
      resumeLanguage: json['cv_language'] as String?,
      personal: {
        for (final field in personalFields) field: data[field] as String? ?? '',
      },
    );
  }
  Map<String, dynamic> toJson() => {
    'profile_id': id,
    'profile_version': version,
    'cv_language': resumeLanguage,
    'personal': personal,
  };
  String encode() => jsonEncode(toJson());
}

class PersonalDraft {
  const PersonalDraft({
    required this.profileId,
    required this.baseVersion,
    required this.personal,
    this.resumeLanguage,
    this.commandKey,
    this.frozen,
  });
  final String profileId;
  final int baseVersion;
  final Map<String, String> personal;
  final String? resumeLanguage, commandKey;
  // Only an explicit in-flight save snapshot, not a background outbox.
  final Map<String, dynamic>? frozen;
  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'version': baseVersion,
    'personal': personal,
    'language': resumeLanguage,
    'key': commandKey,
    'frozen': frozen,
  };
  String encode() => jsonEncode(toJson());
  factory PersonalDraft.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    return PersonalDraft(
      profileId: json['profile_id'] as String,
      baseVersion: json['version'] as int,
      personal: Map<String, String>.from(json['personal'] as Map),
      resumeLanguage: json['language'] as String?,
      commandKey: json['key'] as String?,
      frozen: json['frozen'] == null
          ? null
          : Map<String, dynamic>.from(json['frozen'] as Map),
    );
  }
  PersonalDraft edit(String field, String value) => PersonalDraft(
    profileId: profileId,
    baseVersion: baseVersion,
    personal: {...personal, field: value},
    resumeLanguage: resumeLanguage,
    commandKey: commandKey,
    frozen: frozen,
  );
  PersonalDraft language(String value) => PersonalDraft(
    profileId: profileId,
    baseVersion: baseVersion,
    personal: personal,
    resumeLanguage: value,
    commandKey: commandKey,
    frozen: frozen,
  );
}
