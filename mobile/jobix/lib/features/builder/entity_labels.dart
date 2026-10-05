import '../../l10n/app_localizations.dart';
import '../career_profile/profile_sections.dart';

String sectionTitle(AppLocalizations copy, EntitySection section) =>
    switch (section) {
      EntitySection.experience => copy.stepExperience,
      EntitySection.education => copy.sectionEducation,
      EntitySection.certification => copy.sectionCertifications,
      EntitySection.achievement => copy.sectionAchievements,
      EntitySection.project => copy.sectionProjects,
      EntitySection.skill => copy.sectionSkills,
      EntitySection.language => copy.sectionLanguages,
    };

String addLabel(AppLocalizations copy, EntitySection section) =>
    switch (section) {
      EntitySection.experience => copy.addRole,
      EntitySection.education => copy.addEducation,
      EntitySection.certification => copy.addCertification,
      EntitySection.achievement => copy.addAchievement,
      EntitySection.project => copy.addProject,
      EntitySection.skill => copy.addAction,
      EntitySection.language => copy.addLanguage,
    };

String fieldLabel(
  AppLocalizations copy,
  EntitySection section,
  String field,
) => switch (field) {
  'job_title' => copy.fieldJobTitle,
  'company' => copy.fieldCompany,
  'location' => copy.fieldLocation,
  'start_month' => copy.fieldStartMonth,
  'end_month' => copy.fieldEndMonth,
  'is_current' =>
    section == EntitySection.education ? copy.currentStudy : copy.currentRole,
  'description' =>
    section == EntitySection.education || section == EntitySection.certification
        ? copy.fieldDescriptionOptional
        : copy.fieldDescription,
  'degree' => copy.fieldDegree,
  'institution' => copy.fieldInstitution,
  'field_of_study' => copy.fieldStudy,
  'name' =>
    section == EntitySection.language ? copy.fieldLanguage : copy.fieldName,
  'issuer' => copy.fieldIssuer,
  'issue_month' => copy.fieldIssueMonth,
  'expiry_month' => copy.fieldExpiryMonth,
  'credential_id' => copy.fieldCredential,
  'url' => copy.fieldUrl,
  'title' => copy.fieldTitle,
  'achieved_month' || 'project_month' => copy.fieldMonth,
  'role' => copy.fieldRole,
  'technologies' => copy.fieldTechnologies,
  'proficiency' => copy.fieldProficiency,
  _ => field,
};

String problemText(AppLocalizations copy, FieldProblem problem) =>
    switch (problem) {
      FieldProblem.tooLong => copy.problemTooLong,
      FieldProblem.invalidMonth => copy.problemMonth,
      FieldProblem.invalidUrl => copy.problemUrl,
      FieldProblem.endBeforeStart => copy.problemEndBeforeStart,
      FieldProblem.required => copy.problemRequired,
    };

String proficiencyLabel(AppLocalizations copy, String code) => switch (code) {
  'BASIC' => copy.profBasic,
  'CONVERSATIONAL' => copy.profConversational,
  'PROFESSIONAL' => copy.profProfessional,
  'FLUENT' => copy.profFluent,
  'NATIVE' => copy.profNative,
  _ => code,
};

/// Builder step that owns each section's list.
int stepFor(EntitySection section) => switch (section) {
  EntitySection.experience => 3,
  EntitySection.education ||
  EntitySection.certification ||
  EntitySection.achievement => 4,
  _ => 5,
};

/// Locale-aware "Mar 2021" from a stored YYYY-MM month.
String monthLabel(String value, String locale) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  if (match == null) return value;
  // Unsaved drafts may contain incomplete or invalid input. Keep that input
  // visible and editable instead of indexing outside the month-name list.
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return value;
  const en = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const ar = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', //
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  return '${(locale == 'ar' ? ar : en)[month - 1]} ${match.group(1)}';
}

String itemTitle(ProfileItem item) => switch (item.section) {
  EntitySection.experience => item.text('job_title'),
  EntitySection.education => item.text('degree'),
  EntitySection.achievement => item.text('title'),
  _ => item.text('name'),
};

String itemSubtitle(AppLocalizations copy, ProfileItem item, String locale) {
  String month(String field) => monthLabel(item.text(field), locale);
  String range(String start, String end) {
    final from = item.text(start).isEmpty ? '' : month(start);
    final to = item.section.hasCurrent && item.flag('is_current')
        ? copy.presentLabel
        : item.text(end).isEmpty
        ? ''
        : month(end);
    return [from, to].where((v) => v.isNotEmpty).join(' – ');
  }

  final parts = switch (item.section) {
    EntitySection.experience => [
      item.text('company'),
      range('start_month', 'end_month'),
    ],
    EntitySection.education => [
      item.text('institution'),
      range('start_month', 'end_month'),
    ],
    EntitySection.certification => [
      item.text('issuer'),
      item.text('issue_month').isEmpty ? '' : month('issue_month'),
    ],
    EntitySection.achievement => [
      item.text('issuer'),
      item.text('achieved_month').isEmpty ? '' : month('achieved_month'),
    ],
    EntitySection.project => [
      item.text('role'),
      item.text('project_month').isEmpty ? '' : month('project_month'),
    ],
    EntitySection.language => [
      proficiencyLabel(copy, item.text('proficiency')),
    ],
    EntitySection.skill => <String>[],
  };
  return parts.where((p) => p.trim().isNotEmpty).join(' • ');
}

String initials(String value) {
  final words = value.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
