// Pure Dart: shared by native Preview and the standalone server canonicalizer.
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
