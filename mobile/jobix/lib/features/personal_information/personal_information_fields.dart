import 'package:flutter/material.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/localization/direction.dart';
import '../../l10n/app_localizations.dart';
import 'personal_information_validator.dart';
import 'country_autocomplete.dart';

class PersonalInformationFields extends StatelessWidget {
  const PersonalInformationFields({
    required this.copy,
    required this.clearLabel,
    required this.language,
    required this.controllers,
    required this.onChanged,
    required this.errors,
    required this.regionEgypt,
    required this.cityHistory,
    required this.targetRoleController,
    required this.onTargetRoleChanged,
    this.onBlur,
    this.enabled = true,
    super.key,
  });
  final AppLocalizations copy;
  final String clearLabel;
  final String language;
  final Map<String, TextEditingController> controllers;
  final void Function(String field, String value) onChanged;
  final ValueChanged<String>? onBlur;
  final Set<String> errors;
  final bool regionEgypt, enabled;
  final List<String> cityHistory;
  final TextEditingController targetRoleController;
  final ValueChanged<String> onTargetRoleChanged;

  String? error(String field) {
    if (!errors.contains(field)) return null;
    return switch (validatePersonalField(field, controllers[field]!.text)) {
      'email' => copy.invalidEmail,
      'phone' => copy.invalidPhone,
      'link' => copy.invalidLink,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final direction = language == 'ar' ? TextDirection.rtl : TextDirection.ltr;
    Widget field(
      String key,
      String label,
      String hint,
      IconData icon, {
      TextInputType keyboard = TextInputType.text,
    }) {
      if (key.endsWith('_url')) {
        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TokensV0.secondarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: TokensV0.surfaceCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: TokensV0.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Focus(
                        onFocusChange: (focused) {
                          if (!focused) onBlur?.call(key);
                        },
                        child: TextFormField(
                          key: Key('personal-$key'),
                          controller: controllers[key],
                          enabled: enabled,
                          keyboardType: TextInputType.url,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            hintText: hint,
                            errorText: error(key),
                            isDense: true,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            suffixIcon: controllers[key]!.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: clearLabel,
                                    icon: const Icon(Icons.clear),
                                    onPressed: enabled
                                        ? () {
                                            controllers[key]!.clear();
                                            onChanged(key, '');
                                          }
                                        : null,
                                  ),
                          ),
                          onChanged: (value) => onChanged(key, value),
                          onFieldSubmitted: (_) => onBlur?.call(key),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: TokensV0.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Focus(
              onFocusChange: (focused) {
                if (!focused) onBlur?.call(key);
              },
              child: TextFormField(
                key: Key('personal-$key'),
                controller: controllers[key],
                enabled: enabled,
                keyboardType: keyboard,
                textAlign: TextAlign.start,
                textDirection:
                    key == 'email' || key == 'phone' || key.endsWith('_url')
                    ? TextDirection.ltr
                    : contentDirection(controllers[key]!.text, direction),
                textCapitalization:
                    key == 'full_name' || key == 'city' || key == 'country'
                    ? TextCapitalization.words
                    : TextCapitalization.none,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  hintText: hint,
                  errorText: error(key),
                  prefixIcon: Icon(icon),
                  suffixIcon: controllers[key]!.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: clearLabel,
                          icon: const Icon(Icons.clear),
                          onPressed: enabled
                              ? () {
                                  controllers[key]!.clear();
                                  onChanged(key, '');
                                }
                              : null,
                        ),
                ),
                onChanged: (value) => onChanged(key, value),
                onFieldSubmitted: (_) => onBlur?.call(key),
              ),
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: direction,
      child: Theme(
        data: foundationTheme(languageCode: language),
        child: Column(
          children: [
            SliceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(
                    title: copy.contactHeading,
                    subtitle: copy.exportRequiredHint,
                  ),
                  const SizedBox(height: TokensV0.space16),
                  field(
                    'full_name',
                    copy.fullName,
                    copy.nameExample,
                    Icons.badge_outlined,
                  ),
                  field(
                    'email',
                    copy.emailLabel,
                    copy.emailExample,
                    Icons.mail_outline,
                    keyboard: TextInputType.emailAddress,
                  ),
                  field(
                    'phone',
                    copy.phoneLabel,
                    copy.phoneExample,
                    Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                  ),
                  Text(
                    copy.phoneValidationHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: TokensV0.space16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final country = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.countryLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 6),
                          CountryAutocomplete(
                            controller: controllers['country']!,
                            language: language,
                            hint: copy.countryExample,
                            clearLabel: clearLabel,
                            enabled: enabled,
                            onChanged: (value) => onChanged('country', value),
                          ),
                        ],
                      );
                      final city = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.cityLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 6),
                          _CityAutocomplete(
                            controller: controllers['city']!,
                            history: cityHistory,
                            direction: direction,
                            copy: copy,
                            enabled: enabled,
                            onChanged: (value) => onChanged('city', value),
                          ),
                        ],
                      );
                      // HTML's two-column location grid adapts for enlarged text.
                      if (constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(14) > 18) {
                        return Column(children: [country, city]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: country),
                          const SizedBox(width: 8),
                          Expanded(child: city),
                        ],
                      );
                    },
                  ),
                  if (regionEgypt && controllers['country']!.text.isEmpty)
                    TextButton(
                      key: const Key('use-egypt'),
                      onPressed: enabled
                          ? () {
                              final value = language == 'ar' ? 'مصر' : 'Egypt';
                              controllers['country']!.text = value;
                              onChanged('country', value);
                            }
                          : null,
                      child: Text(copy.useEgypt),
                    ),
                ],
              ),
            ),
            ...[
              const SizedBox(height: TokensV0.space24),
              SliceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeading(
                      title: copy.targetRoleOptional,
                      subtitle: language == 'ar'
                          ? 'يظهر هذا الدور أعلى سيرتك الذاتية.'
                          : 'This role appears near the top of your resume.',
                    ),
                    const SizedBox(height: TokensV0.space12),
                    TextField(
                      key: const Key('personal-target-role'),
                      controller: targetRoleController,
                      enabled: enabled,
                      maxLength: 120,
                      textDirection: direction,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: copy.targetRoleOptional,
                        hintText: language == 'ar'
                            ? 'مثال: مدير منتجات'
                            : 'Example: Product Manager',
                      ),
                      onChanged: onTargetRoleChanged,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: TokensV0.space24),
            SliceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(title: copy.optionalHeading),
                  const SizedBox(height: TokensV0.space16),
                  field(
                    'linkedin_url',
                    copy.linkedInLabel,
                    'https://linkedin.com/in/…',
                    Icons.work_outline,
                    keyboard: TextInputType.url,
                  ),
                  field(
                    'github_url',
                    copy.githubLabel,
                    'https://github.com/…',
                    Icons.code,
                    keyboard: TextInputType.url,
                  ),
                  field(
                    'portfolio_url',
                    copy.portfolioLabel,
                    'https://…',
                    Icons.link,
                    keyboard: TextInputType.url,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityAutocomplete extends StatefulWidget {
  const _CityAutocomplete({
    required this.controller,
    required this.history,
    required this.direction,
    required this.copy,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final List<String> history;
  final TextDirection direction;
  final AppLocalizations copy;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  State<_CityAutocomplete> createState() => _CityAutocompleteState();
}

class _CityAutocompleteState extends State<_CityAutocomplete> {
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(
    textEditingController: widget.controller,
    focusNode: focus,
    optionsBuilder: (value) => value.text.trim().isEmpty
        ? const []
        : widget.history.where(
            (city) => city.toLowerCase().contains(value.text.toLowerCase()),
          ),
    onSelected: widget.onChanged,
    fieldViewBuilder: (_, controller, node, submit) => TextField(
      key: const Key('personal-city'),
      enabled: widget.enabled,
      controller: controller,
      focusNode: node,
      textDirection: contentDirection(controller.text, widget.direction),
      decoration: InputDecoration(
        hintText: widget.copy.cityExample,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: widget.copy.localeName.startsWith('ar')
                    ? 'مسح الحقل'
                    : 'Clear field',
                onPressed: widget.enabled
                    ? () {
                        controller.clear();
                        widget.onChanged('');
                      }
                    : null,
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: widget.onChanged,
    ),
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 4,
        child: SizedBox(
          width: 260,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final option in options)
                ListTile(title: Text(option), onTap: () => onSelected(option)),
            ],
          ),
        ),
      ),
    ),
  );
}
