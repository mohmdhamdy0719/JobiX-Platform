/// Repeatable Career Profile sections. Field names, limits and completeness
/// mirror the server contract; the server remains authoritative.
enum FieldKind { text, multiline, month, url, toggle, list }

class SectionField {
  const SectionField(
    this.name,
    this.kind, {
    this.max = 200,
    this.required = false,
    this.minimum = 1,
  });
  final String name;
  final FieldKind kind;
  final int max, minimum;
  final bool required;
}

enum EntitySection {
  experience('experience', 'experiences', [
    SectionField('job_title', FieldKind.text, required: true),
    SectionField('company', FieldKind.text, required: true),
    SectionField('location', FieldKind.text),
    SectionField('start_month', FieldKind.month, required: true),
    SectionField('end_month', FieldKind.month),
    SectionField('is_current', FieldKind.toggle),
    SectionField(
      'description',
      FieldKind.multiline,
      max: 1500,
      required: false,
      minimum: 20,
    ),
  ]),
  volunteer('volunteer', 'volunteer_experiences', [
    SectionField('organization', FieldKind.text, required: true),
    SectionField('role', FieldKind.text, required: true),
    SectionField('location', FieldKind.text),
    SectionField('start_month', FieldKind.month, required: true),
    SectionField('end_month', FieldKind.month),
    SectionField('is_current', FieldKind.toggle),
    SectionField('description', FieldKind.multiline, max: 1500, minimum: 20),
  ]),
  education('education', 'education', [
    SectionField('degree', FieldKind.text, required: true),
    SectionField('institution', FieldKind.text, required: true),
    SectionField('field_of_study', FieldKind.text, required: true),
    SectionField('start_month', FieldKind.month, required: true),
    SectionField('end_month', FieldKind.month),
    SectionField('is_current', FieldKind.toggle),
    SectionField('description', FieldKind.multiline, max: 1500),
  ]),
  certification('certification', 'certifications', [
    SectionField('name', FieldKind.text, required: true),
    SectionField('issuer', FieldKind.text, required: true),
    SectionField('issue_month', FieldKind.month, required: true),
    SectionField('expiry_month', FieldKind.month),
    SectionField('credential_id', FieldKind.text),
    SectionField('url', FieldKind.url, max: 2048),
    SectionField('description', FieldKind.multiline, max: 1500),
  ]),
  achievement('achievement', 'achievements', [
    SectionField('title', FieldKind.text, required: true),
    SectionField('issuer', FieldKind.text, required: true),
    SectionField('achieved_month', FieldKind.month, required: true),
    SectionField('url', FieldKind.url, max: 2048),
    SectionField(
      'description',
      FieldKind.multiline,
      max: 1500,
      required: false,
      minimum: 20,
    ),
  ]),
  project('project', 'projects', [
    SectionField('name', FieldKind.text, required: true),
    SectionField('role', FieldKind.text, required: true),
    SectionField('project_month', FieldKind.month, required: true),
    SectionField('url', FieldKind.url, max: 2048),
    SectionField('technologies', FieldKind.list, max: 100),
    SectionField(
      'description',
      FieldKind.multiline,
      max: 1500,
      required: false,
      minimum: 20,
    ),
  ]),
  skill('skill', 'skills', [
    SectionField('name', FieldKind.text, max: 100, required: true),
  ]),
  language('language', 'languages', [
    SectionField('name', FieldKind.text, max: 100, required: true),
    SectionField('proficiency', FieldKind.text, required: true),
  ]);

  const EntitySection(this.key, this.listKey, this.fields);
  final String key, listKey;
  final List<SectionField> fields;

  String get tableName => switch (this) {
    EntitySection.experience => 'profile_experiences',
    EntitySection.volunteer => 'profile_volunteer_experiences',
    EntitySection.education => 'profile_education',
    EntitySection.certification => 'profile_certifications',
    EntitySection.achievement => 'profile_achievements',
    EntitySection.project => 'profile_projects',
    EntitySection.skill => 'profile_skills',
    EntitySection.language => 'profile_languages',
  };
  static EntitySection parse(String key) =>
      values.firstWhere((s) => s.key == key);

  /// Which pair of month fields form a range, if any.
  (String, String)? get range => switch (this) {
    experience || volunteer || education => ('start_month', 'end_month'),
    certification => ('issue_month', 'expiry_month'),
    _ => null,
  };
  bool get hasCurrent =>
      this == experience || this == volunteer || this == education;
}

const proficiencies = [
  'BASIC',
  'CONVERSATIONAL',
  'PROFESSIONAL',
  'FLUENT',
  'NATIVE',
];

final _month = RegExp(r'^(?!0000)\d{4}-(0[1-9]|1[0-2])$');
final _scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:');
final _url = RegExp(r'^https://[^\s/?#@]+\.[^\s/?#@]+([/?#]\S*)?$');

String nameKey(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Mirrors server URL normalization (https only; bare domains get https).
String? normalizeUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final full = value.toLowerCase().startsWith('https://')
      ? value
      : _scheme.hasMatch(value)
      ? null
      : 'https://$value';
  return full != null && full.length <= 2048 && _url.hasMatch(full)
      ? full
      : null;
}

/// Blocking structural/format problems. Descriptive quality is a separate,
/// non-blocking concern; local drafts retain every incomplete edit.
enum FieldProblem {
  tooLong,
  invalidMonth,
  invalidUrl,
  endBeforeStart,
  required,
}

class ProfileItem {
  const ProfileItem({
    required this.id,
    required this.section,
    this.version = 0,
    this.complete = false,
    this.isDraft = false,
    this.values = const {},
  });
  final String id;
  final EntitySection section;
  final int version;
  final bool complete, isDraft;
  final Map<String, Object?> values;

  String text(String field) => (values[field] as String?) ?? '';
  bool flag(String field) => values[field] == true;
  List<String> list(String field) =>
      ((values[field] as List?) ?? const []).cast<String>();

  factory ProfileItem.fromJson(EntitySection section, Map json) => ProfileItem(
    id: json['id'] as String,
    section: section,
    version: (json['version'] as num? ?? 0).toInt(),
    complete: section == EntitySection.volunteer
        ? false // Saved unpaid evidence, never percentage qualification.
        : section == EntitySection.skill || section == EntitySection.language
        ? true
        : json['complete'] == true,
    isDraft: json['is_draft'] == true,
    values: {
      for (final field in section.fields)
        if (json[field.name] != null)
          field.name:
              field.kind == FieldKind.month &&
                  json[field.name] is String &&
                  RegExp(
                    r'^\d{4}-\d{2}-\d{2}$',
                  ).hasMatch(json[field.name] as String)
              ? (json[field.name] as String).substring(0, 7)
              : json[field.name],
    },
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'complete': complete,
    'is_draft': isDraft,
    ...values,
  };

  ProfileItem copyWith(String field, Object? value) => ProfileItem(
    id: id,
    section: section,
    version: version,
    complete: complete,
    isDraft: isDraft,
    values: {...values, field: value},
  );

  /// The same values on a different item-version baseline. Only used when
  /// the user explicitly chooses to reapply local changes, or after the
  /// server acknowledged this device's own earlier write.
  ProfileItem rebased(int baseVersion) => ProfileItem(
    id: id,
    section: section,
    version: baseVersion,
    complete: complete,
    isDraft: isDraft,
    values: values,
  );

  /// The exact request value sent to the server.
  Map<String, Object?> payload() {
    final out = <String, Object?>{'id': id};
    for (final field in section.fields) {
      final value = values[field.name];
      switch (field.kind) {
        case FieldKind.toggle:
          out[field.name] = value == true;
        case FieldKind.list:
          out[field.name] = [
            for (final v in (value as List? ?? const []))
              if ((v as String).trim().isNotEmpty) v.trim(),
          ];
        case FieldKind.url:
          final s = (value as String? ?? '').trim();
          out[field.name] = s.isEmpty ? null : normalizeUrl(s) ?? s;
        default:
          final s = (value as String? ?? '').trim();
          out[field.name] = s.isEmpty ? null : s;
      }
    }
    if (section.hasCurrent && out['is_current'] == true) {
      out['end_month'] = null;
    }
    return out;
  }

  Map<String, FieldProblem> problems() {
    final result = <String, FieldProblem>{};
    for (final field in section.fields) {
      final value = values[field.name];
      if (field.kind == FieldKind.toggle) continue;
      if (field.name == 'end_month' &&
          section.hasCurrent &&
          flag('is_current')) {
        continue;
      }
      if (field.kind == FieldKind.list) {
        if (list(field.name).any((v) => v.trim().runes.length > field.max)) {
          result[field.name] = FieldProblem.tooLong;
        }
        continue;
      }
      final s = (value as String? ?? '').trim();
      if (section == EntitySection.education &&
          field.name == 'degree' &&
          s.startsWith('other:') &&
          s.substring(6).trim().isEmpty) {
        result[field.name] = FieldProblem.required;
      }
      if (s.runes.length > field.max) result[field.name] = FieldProblem.tooLong;
      if (s.isEmpty) {
        if (field.required ||
            (field.name == 'end_month' &&
                section.hasCurrent &&
                !flag('is_current'))) {
          result[field.name] = FieldProblem.required;
        }
        continue;
      }
      if (field.kind == FieldKind.month && !_month.hasMatch(s)) {
        result[field.name] = FieldProblem.invalidMonth;
      }
      if (field.kind == FieldKind.url && normalizeUrl(s) == null) {
        result[field.name] = FieldProblem.invalidUrl;
      }
    }
    final range = section.range;
    if (range != null) {
      final start = text(range.$1), end = text(range.$2);
      final ignoreEnd = section.hasCurrent && flag('is_current');
      if (!ignoreEnd &&
          _month.hasMatch(start) &&
          _month.hasMatch(end) &&
          end.compareTo(start) < 0) {
        result[range.$2] = FieldProblem.endBeforeStart;
      }
    }
    if ((section == EntitySection.skill || section == EntitySection.language) &&
        text('name').trim().isEmpty) {
      result['name'] = FieldProblem.required;
    }
    if (section == EntitySection.language &&
        !proficiencies.contains(text('proficiency'))) {
      result['proficiency'] = FieldProblem.required;
    }
    return result;
  }

  /// Local estimate used only before the server acknowledges a save.
  bool get locallyComplete {
    if (section == EntitySection.volunteer) return false;
    // Completeness is unchanged. Empty optional prose no longer produces a
    // quality warning, but that does not award its existing completeness.
    if (problems().isNotEmpty ||
        section.fields.any(
          (f) =>
              f.kind == FieldKind.multiline &&
              f.minimum > 1 &&
              text(f.name).trim().runes.length < f.minimum,
        )) {
      return false;
    }
    for (final field in section.fields) {
      if (!field.required) continue;
      if (text(field.name).trim().length < field.minimum) return false;
    }
    if (section.hasCurrent &&
        !flag('is_current') &&
        text('end_month').isEmpty) {
      return false;
    }
    return true;
  }

  /// Descriptive attention never blocks structurally valid saves.
  bool get needsAttention => section.fields.any(
    (field) =>
        field.kind == FieldKind.multiline &&
        field.minimum > 1 &&
        text(field.name).trim().isNotEmpty &&
        text(field.name).trim().runes.length < field.minimum,
  );
}
