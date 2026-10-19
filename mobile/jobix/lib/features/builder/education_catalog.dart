import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/tokens.dart';
import '../../core/providers.dart';

/// A single bilingual suggestion. Suggestions never own or validate a profile
/// value; the editor remains an ordinary free-text field.
class EducationSuggestion {
  const EducationSuggestion({
    required this.nameEn,
    this.nameAr,
    this.aliasesEn = const [],
    this.aliasesAr = const [],
  });

  final String nameEn;
  final String? nameAr;
  final List<String> aliasesEn;
  final List<String> aliasesAr;

  String labelFor(String language) {
    if (language == 'ar' && nameAr?.trim().isNotEmpty == true) {
      return nameAr!.trim();
    }
    if (nameEn.trim().isNotEmpty) return nameEn.trim();
    return nameAr?.trim() ?? '';
  }

  String? secondaryLabelFor(String language) {
    final primary = labelFor(language);
    final secondary = language == 'ar' ? nameEn.trim() : nameAr?.trim();
    return secondary == null || secondary.isEmpty || secondary == primary
        ? null
        : secondary;
  }

  Iterable<String> get searchTerms => [
    nameEn,
    if (nameAr != null) nameAr!,
    ...aliasesEn,
    ...aliasesAr,
  ];

  factory EducationSuggestion.fromRow(Map<String, dynamic> row) =>
      EducationSuggestion(
        nameEn: row['name_en'] as String? ?? '',
        nameAr: row['name_ar'] as String?,
        aliasesEn: _stringList(row['aliases_en']),
        aliasesAr: _stringList(row['aliases_ar']),
      );
}

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];

class EducationCatalogData {
  const EducationCatalogData({
    required this.institutions,
    required this.studyFields,
    required this.institutionsFromServer,
    required this.studyFieldsFromServer,
  });

  final List<EducationSuggestion> institutions;
  final List<EducationSuggestion> studyFields;
  final bool institutionsFromServer;
  final bool studyFieldsFromServer;

  static const fallback = EducationCatalogData(
    institutions: commonInstitutionSuggestions,
    studyFields: commonStudyFieldSuggestions,
    institutionsFromServer: false,
    studyFieldsFromServer: false,
  );
}

/// These bundled entries keep suggestions useful when the catalog migration
/// has not been applied or the user is offline. The editable fields still
/// accept any value. The full curated list is read from the authenticated,
/// read-only catalog tables when available.
const commonInstitutionSuggestions = <EducationSuggestion>[
  EducationSuggestion(
    nameEn: 'Cairo University',
    nameAr: 'جامعة القاهرة',
    aliasesEn: ['CU', 'University of Cairo'],
    aliasesAr: ['القاهرة'],
  ),
  EducationSuggestion(
    nameEn: 'Ain Shams University',
    nameAr: 'جامعة عين شمس',
    aliasesEn: ['ASU'],
  ),
  EducationSuggestion(
    nameEn: 'Alexandria University',
    nameAr: 'جامعة الإسكندرية',
    aliasesEn: ['Alex University'],
  ),
  EducationSuggestion(nameEn: 'Mansoura University', nameAr: 'جامعة المنصورة'),
  EducationSuggestion(nameEn: 'Assiut University', nameAr: 'جامعة أسيوط'),
  EducationSuggestion(nameEn: 'Zagazig University', nameAr: 'جامعة الزقازيق'),
  EducationSuggestion(nameEn: 'Helwan University', nameAr: 'جامعة حلوان'),
  EducationSuggestion(
    nameEn: 'American University in Cairo',
    nameAr: 'الجامعة الأمريكية بالقاهرة',
    aliasesEn: ['AUC'],
  ),
  EducationSuggestion(
    nameEn: 'German University in Cairo',
    nameAr: 'الجامعة الألمانية بالقاهرة',
    aliasesEn: ['GUC'],
  ),
  EducationSuggestion(
    nameEn: 'British University in Egypt',
    nameAr: 'الجامعة البريطانية في مصر',
    aliasesEn: ['BUE'],
  ),
  EducationSuggestion(nameEn: 'Nile University', nameAr: 'جامعة النيل'),
  EducationSuggestion(
    nameEn: 'Egypt-Japan University of Science and Technology',
    nameAr: 'الجامعة المصرية اليابانية للعلوم والتكنولوجيا',
    aliasesEn: ['E-JUST', 'EJUST'],
  ),
  EducationSuggestion(
    nameEn: 'New Cairo Technological University',
    nameAr: 'جامعة القاهرة الجديدة التكنولوجية',
  ),
  EducationSuggestion(
    nameEn: 'Sadat Academy for Management Sciences',
    nameAr: 'أكاديمية السادات للعلوم الإدارية',
    aliasesEn: ['SAMS'],
  ),
  EducationSuggestion(
    nameEn: 'Higher Institute of Engineering and Technology, 6th of October',
    nameAr: 'المعهد العالي للهندسة والتكنولوجيا بمدينة 6 أكتوبر',
    aliasesEn: ['October Higher Institute of Engineering'],
  ),
];

const commonStudyFieldSuggestions = <EducationSuggestion>[
  EducationSuggestion(
    nameEn: 'Accounting',
    nameAr: 'المحاسبة',
    aliasesEn: ['Accountancy', 'Financial Accounting'],
  ),
  EducationSuggestion(
    nameEn: 'Agriculture',
    nameAr: 'الزراعة',
    aliasesEn: ['Agricultural Sciences'],
  ),
  EducationSuggestion(
    nameEn: 'Architecture and Urban Planning',
    nameAr: 'العمارة والتخطيط العمراني',
    aliasesEn: ['Architecture', 'Urban Design'],
  ),
  EducationSuggestion(
    nameEn: 'Biology',
    nameAr: 'علم الأحياء',
    aliasesEn: ['Biological Sciences'],
  ),
  EducationSuggestion(
    nameEn: 'Business Administration',
    nameAr: 'إدارة الأعمال',
    aliasesEn: ['Business', 'Management'],
  ),
  EducationSuggestion(nameEn: 'Chemistry', nameAr: 'الكيمياء'),
  EducationSuggestion(
    nameEn: 'Civil Engineering',
    nameAr: 'الهندسة المدنية',
    aliasesEn: ['Structural Engineering'],
  ),
  EducationSuggestion(
    nameEn: 'Computer Science',
    nameAr: 'علوم الحاسب',
    aliasesEn: ['Computing', 'Computer Studies'],
  ),
  EducationSuggestion(nameEn: 'Dentistry', nameAr: 'طب الأسنان'),
  EducationSuggestion(nameEn: 'Economics', nameAr: 'الاقتصاد'),
  EducationSuggestion(
    nameEn: 'Education',
    nameAr: 'التربية',
    aliasesEn: ['Educational Studies', 'Teaching'],
  ),
  EducationSuggestion(
    nameEn: 'Electrical and Electronic Engineering',
    nameAr: 'الهندسة الكهربائية والإلكترونية',
    aliasesEn: ['Electrical Engineering', 'Electronics'],
  ),
  EducationSuggestion(
    nameEn: 'English Language and Literature',
    nameAr: 'اللغة الإنجليزية وآدابها',
    aliasesEn: ['English Studies', 'English'],
  ),
  EducationSuggestion(
    nameEn: 'Finance and Banking',
    nameAr: 'التمويل والمصارف',
    aliasesEn: ['Finance', 'Banking'],
  ),
  EducationSuggestion(
    nameEn: 'Fine Arts',
    nameAr: 'الفنون الجميلة',
    aliasesEn: ['Visual Arts'],
  ),
  EducationSuggestion(
    nameEn: 'Law',
    nameAr: 'القانون',
    aliasesEn: ['Legal Studies'],
  ),
  EducationSuggestion(nameEn: 'Marketing', nameAr: 'التسويق'),
  EducationSuggestion(
    nameEn: 'Mathematics',
    nameAr: 'الرياضيات',
    aliasesEn: ['Applied Mathematics'],
  ),
  EducationSuggestion(
    nameEn: 'Mechanical Engineering',
    nameAr: 'الهندسة الميكانيكية',
    aliasesEn: ['Mechatronics'],
  ),
  EducationSuggestion(
    nameEn: 'Medicine',
    nameAr: 'الطب',
    aliasesEn: ['Medicine and Surgery'],
  ),
  EducationSuggestion(
    nameEn: 'Media and Communication',
    nameAr: 'الإعلام والاتصال',
    aliasesEn: ['Journalism', 'Mass Communication'],
  ),
  EducationSuggestion(nameEn: 'Nursing', nameAr: 'التمريض'),
  EducationSuggestion(nameEn: 'Pharmacy', nameAr: 'الصيدلة'),
  EducationSuggestion(nameEn: 'Physics', nameAr: 'الفيزياء'),
  EducationSuggestion(
    nameEn: 'Political Science',
    nameAr: 'العلوم السياسية',
    aliasesEn: ['Politics', 'International Relations'],
  ),
  EducationSuggestion(nameEn: 'Psychology', nameAr: 'علم النفس'),
  EducationSuggestion(
    nameEn: 'Social Work',
    nameAr: 'الخدمة الاجتماعية',
    aliasesEn: ['Social Services'],
  ),
  EducationSuggestion(nameEn: 'Sociology', nameAr: 'علم الاجتماع'),
  EducationSuggestion(
    nameEn: 'Tourism and Hospitality',
    nameAr: 'السياحة والضيافة',
    aliasesEn: ['Hotel Management', 'Tourism Studies'],
  ),
];

/// Reads the non-user-specific reference catalogs using the authenticated
/// client's SELECT-only grants. Each table independently falls back if its
/// migration is unavailable or the device is offline.
final educationCatalogProvider =
    FutureProvider.autoDispose<EducationCatalogData>((ref) async {
      try {
        final client = await ref.watch(supabaseClientProvider.future);
        final institutions = await _readCatalog(
          client,
          'education_institution_catalog',
        );
        final studyFields = await _readCatalog(client, 'study_field_catalog');
        return EducationCatalogData(
          institutions: institutions.rows.isEmpty
              ? commonInstitutionSuggestions
              : institutions.rows,
          studyFields: studyFields.rows.isEmpty
              ? commonStudyFieldSuggestions
              : studyFields.rows,
          institutionsFromServer: institutions.available,
          studyFieldsFromServer: studyFields.available,
        );
      } catch (_) {
        return EducationCatalogData.fallback;
      }
    });

class _CatalogRead {
  const _CatalogRead(this.rows, this.available);
  final List<EducationSuggestion> rows;
  final bool available;
}

Future<_CatalogRead> _readCatalog(SupabaseClient client, String table) async {
  try {
    final rows = await client
        .from(table)
        .select('name_en,name_ar,aliases_en,aliases_ar')
        .order('name_en');
    final suggestions = [
      for (final row in rows)
        EducationSuggestion.fromRow(Map<String, dynamic>.from(row)),
    ];
    return _CatalogRead(suggestions, suggestions.isNotEmpty);
  } catch (_) {
    return const _CatalogRead([], false);
  }
}

String _normalizeSuggestionText(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064b-\u065f\u0670]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ');

/// Requires every query token to match some part of a bilingual name or
/// alias. This is deliberately not fuzzy-acceptance logic for saved values.
List<EducationSuggestion> filterEducationSuggestions(
  Iterable<EducationSuggestion> source,
  String query, {
  int limit = 12,
}) {
  final normalized = _normalizeSuggestionText(query);
  if (normalized.isEmpty || limit <= 0) return const [];
  final tokens = normalized.split(' ');
  final ranked = <(int, EducationSuggestion)>[];
  for (final suggestion in source) {
    final terms = suggestion.searchTerms
        .map(_normalizeSuggestionText)
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (!tokens.every((token) => terms.any((term) => term.contains(token)))) {
      continue;
    }
    final score = terms.any((term) => term == normalized)
        ? 0
        : terms.any((term) => term.startsWith(normalized))
        ? 1
        : 2;
    ranked.add((score, suggestion));
  }
  ranked.sort((a, b) => a.$1.compareTo(b.$1));
  return ranked.take(limit).map((entry) => entry.$2).toList(growable: false);
}

class EducationAutocompleteField extends StatefulWidget {
  const EducationAutocompleteField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.language,
    required this.suggestions,
    required this.onChanged,
    required this.clearLabel,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.fieldKey,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String language;
  final List<EducationSuggestion> suggestions;
  final ValueChanged<String> onChanged;
  final String clearLabel;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final Key? fieldKey;

  @override
  State<EducationAutocompleteField> createState() =>
      _EducationAutocompleteFieldState();
}

class _EducationAutocompleteFieldState
    extends State<EducationAutocompleteField> {
  late final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: RawAutocomplete<EducationSuggestion>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.labelFor(widget.language),
      optionsBuilder: (value) =>
          filterEducationSuggestions(widget.suggestions, value.text),
      onSelected: (option) =>
          widget.onChanged(option.labelFor(widget.language)),
      optionsViewBuilder: (context, select, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          color: TokensV0.surfaceCard,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TokensV0.cardRadius),
            side: const BorderSide(color: TokensV0.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 256),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(
                    dense: true,
                    title: Text(option.labelFor(widget.language)),
                    subtitle: option.secondaryLabelFor(widget.language) == null
                        ? null
                        : Text(option.secondaryLabelFor(widget.language)!),
                    onTap: () => select(option),
                  ),
              ],
            ),
          ),
        ),
      ),
      fieldViewBuilder: (context, fieldController, focusNode, submit) =>
          TextField(
            key: widget.fieldKey,
            controller: fieldController,
            focusNode: focusNode,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.words,
            textDirection: widget.language == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              helperText: widget.helperText,
              helperMaxLines: 2,
              errorText: widget.errorText,
              suffixIcon: fieldController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: widget.clearLabel,
                      onPressed: widget.enabled
                          ? () {
                              fieldController.clear();
                              widget.onChanged('');
                            }
                          : null,
                      icon: const Icon(Icons.clear, size: 18),
                    ),
            ),
            onChanged: widget.onChanged,
            onSubmitted: (_) => submit(),
          ),
    ),
  );
}
