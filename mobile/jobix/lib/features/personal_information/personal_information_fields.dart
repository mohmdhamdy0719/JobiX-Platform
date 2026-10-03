import 'package:flutter/material.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/localization/direction.dart';
import '../../l10n/app_localizations.dart';
import 'personal_information_validator.dart';

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
    this.enabled = true,
    super.key,
  });
  final AppLocalizations copy;
  final String clearLabel;
  final String language;
  final Map<String, TextEditingController> controllers;
  final void Function(String field, String value) onChanged;
  final Set<String> errors;
  final bool regionEgypt, enabled;
  final List<String> cityHistory;

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
    }) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: TokensV0.space16),
      child: TextFormField(
        key: Key('personal-$key'),
        controller: controllers[key],
        enabled: enabled,
        keyboardType: keyboard,
        textAlign: TextAlign.start,
        textDirection: key == 'email' || key == 'phone' || key.endsWith('_url')
            ? TextDirection.ltr
            : contentDirection(controllers[key]!.text, direction),
        textCapitalization:
            key == 'full_name' || key == 'city' || key == 'country'
            ? TextCapitalization.words
            : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: label,
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
      ),
    );
    return Directionality(
      textDirection: direction,
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
                const SizedBox(height: TokensV0.space24),
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
              ],
            ),
          ),
          const SizedBox(height: TokensV0.space24),
          SliceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(title: copy.optionalHeading),
                const SizedBox(height: TokensV0.space24),
                field(
                  'country',
                  copy.countryLabel,
                  copy.countryExample,
                  Icons.public,
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
                _CityAutocomplete(
                  controller: controllers['city']!,
                  history: cityHistory,
                  direction: direction,
                  copy: copy,
                  enabled: enabled,
                  onChanged: (value) => onChanged('city', value),
                ),
                const SizedBox(height: TokensV0.space8),
                Text(
                  copy.locationDataMissing,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: TokensV0.space24),
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
        labelText: widget.copy.cityLabel,
        hintText: widget.copy.cityExample,
        prefixIcon: const Icon(Icons.location_on_outlined),
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
