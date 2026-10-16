import '../../l10n/app_localizations.dart';
import '../career_profile/profile_sections.dart';

String sectionTitle(AppLocalizations copy, EntitySection section) =>
    switch (section) {
      EntitySection.experience => copy.stepExperience,
      EntitySection.volunteer => copy.sectionVolunteer,
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
      EntitySection.volunteer => copy.addVolunteer,
      EntitySection.education => copy.addEducation,
      EntitySection.certification => copy.addCertification,
      EntitySection.achievement => copy.addAchievement,
      EntitySection.project => copy.addProject,
      EntitySection.skill => copy.addAction,
      EntitySection.language => copy.addLanguage,
    };

String fieldLabel(AppLocalizations copy, EntitySection section, String field) =>
    switch (field) {
      'job_title' => copy.fieldJobTitle,
      'company' => copy.fieldCompany,
      'organization' => copy.fieldOrganization,
      'location' => copy.fieldLocation,
      'start_month' => copy.fieldStartMonth,
      'end_month' => copy.fieldEndMonth,
      'is_current' =>
        section == EntitySection.education
            ? copy.currentStudy
            : section == EntitySection.volunteer
            ? copy.currentVolunteer
            : copy.currentRole,
      'description' => copy.fieldDescription,
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

// Secondary certificates and high-school diplomas are distinct qualification
// systems; the existing high_school code remains stable as High School Diploma.
const degreeCodes = <String>[
  'degree:secondary_school_certificate',
  'degree:high_school',
  'degree:vocational_certificate',
  'degree:vocational_diploma',
  'degree:professional_certificate',
  'degree:certificate',
  'degree:diploma',
  'degree:associate',
  'degree:foundation',
  'degree:bachelor',
  'degree:graduate_certificate',
  'degree:postgraduate_diploma',
  'degree:master',
  'degree:professional_doctorate',
  'degree:doctorate_phd',
  'degree:other',
];

String degreeOption(String saved) {
  if (saved == 'degree:doctorate') return 'degree:doctorate_phd';
  if (degreeCodes.contains(saved)) return saved;
  if (saved.trim().isEmpty) return '';
  final value = saved.trim().toLowerCase();
  if (value.startsWith('other:')) return 'degree:other';
  if (value == 'secondary school certificate') {
    return 'degree:secondary_school_certificate';
  }
  if ([
    'high school',
    'high-school',
    'high school diploma',
    'secondary school',
  ].contains(value)) {
    return 'degree:high_school';
  }
  if (['associate', "associate's", 'associate degree'].contains(value)) {
    return 'degree:associate';
  }
  if ([
    'bachelor',
    "bachelor's",
    'bachelor degree',
    "bachelor's degree",
  ].contains(value)) {
    return 'degree:bachelor';
  }
  if ([
    'master',
    "master's",
    'master degree',
    "master's degree",
  ].contains(value)) {
    return 'degree:master';
  }
  if (['doctorate', 'doctoral', 'phd', 'ph.d.'].contains(value)) {
    return 'degree:doctorate_phd';
  }
  if (value == 'diploma') return 'degree:diploma';
  if (value == 'certificate') return 'degree:certificate';
  return 'degree:other';
}

String degreeLabel(String saved, String language) {
  final code = degreeOption(saved);
  if (code == 'degree:other') {
    if (saved.startsWith('other:')) return saved.substring(6);
    return saved;
  }
  return degreeChoiceLabel(code, language);
}

String degreeChoiceLabel(String code, String language) {
  const english = {
    'degree:secondary_school_certificate': 'Secondary School Certificate',
    'degree:high_school': 'High School Diploma',
    'degree:vocational_certificate': 'Vocational Certificate',
    'degree:vocational_diploma': 'Vocational Diploma',
    'degree:professional_certificate': 'Professional Certificate',
    'degree:certificate': 'Certificate',
    'degree:diploma': 'Diploma',
    'degree:associate': 'Associate Degree',
    'degree:foundation': 'Foundation Degree',
    'degree:bachelor': "Bachelor's Degree",
    'degree:graduate_certificate': 'Graduate Certificate',
    'degree:postgraduate_diploma': 'Postgraduate Diploma',
    'degree:master': "Master's Degree",
    'degree:professional_doctorate': 'Professional Doctorate',
    'degree:doctorate_phd': 'Doctorate / PhD',
    'degree:doctorate': 'Doctorate / PhD',
    'degree:other': 'Other',
  };
  const arabic = {
    'degree:secondary_school_certificate': 'شهادة المرحلة الثانوية',
    'degree:high_school': 'دبلوم الثانوية العامة',
    'degree:vocational_certificate': 'شهادة مهنية',
    'degree:vocational_diploma': 'دبلوم مهني',
    'degree:professional_certificate': 'شهادة احترافية',
    'degree:certificate': 'شهادة',
    'degree:diploma': 'دبلوم',
    'degree:associate': 'درجة جامعية متوسطة',
    'degree:foundation': 'درجة تأسيسية',
    'degree:bachelor': 'درجة البكالوريوس',
    'degree:graduate_certificate': 'شهادة دراسات عليا',
    'degree:postgraduate_diploma': 'دبلوم دراسات عليا',
    'degree:master': 'درجة الماجستير',
    'degree:professional_doctorate': 'دكتوراه مهنية',
    'degree:doctorate_phd': 'دكتوراه / PhD',
    'degree:doctorate': 'دكتوراه / PhD',
    'degree:other': 'أخرى',
  };
  return (language == 'ar' ? arabic : english)[code] ?? code;
}

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
  EntitySection.experience || EntitySection.volunteer => 3,
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

String itemTitle(ProfileItem item, [String language = 'en']) =>
    switch (item.section) {
      EntitySection.experience => item.text('job_title'),
      EntitySection.volunteer => item.text('role'),
      EntitySection.education => degreeLabel(item.text('degree'), language),
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
    EntitySection.volunteer => [
      item.text('organization'),
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
