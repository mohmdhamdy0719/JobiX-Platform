import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/tokens.dart';

/// Bundled Unicode CLDR display names: no network, location lookup, or implicit
/// selection. Country remains an editable string in the existing profile.
class CountryAutocomplete extends StatefulWidget {
  const CountryAutocomplete({
    required this.controller,
    required this.language,
    required this.onChanged,
    required this.hint,
    required this.clearLabel,
    this.enabled = true,
    super.key,
  });
  final TextEditingController controller;
  final String language, hint, clearLabel;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<CountryAutocomplete> createState() => _CountryAutocompleteState();
}

class _CountryAutocompleteState extends State<CountryAutocomplete> {
  final focus = FocusNode();
  List<String> names = const [];
  String? failure;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(CountryAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) load();
  }

  Future<void> load() async {
    final language = widget.language == 'ar' ? 'ar' : 'en';
    try {
      final raw = await rootBundle.loadString(
        'assets/localization/countries_$language.json',
      );
      final map =
          jsonDecode(raw)['main'][language]['localeDisplayNames']['territories']
              as Map;
      final values = [
        for (final entry in map.entries)
          if (RegExp(r'^[A-Z]{2}$').hasMatch(entry.key as String) &&
              !{'ZZ', 'EU', 'EZ', 'UN', 'QO', 'XA', 'XB'}.contains(entry.key))
            entry.value as String,
      ]..sort();
      if (!mounted || widget.language != language) return;
      setState(() {
        names = values;
        failure = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => failure = language == 'ar'
            ? 'الاقتراحات غير متاحة. يمكنك كتابة الدولة.'
            : 'Suggestions unavailable. You can still type your country.',
      );
    }
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(
    focusNode: focus,
    textEditingController: widget.controller,
    optionsBuilder: (value) {
      final query = value.text.trim().toLowerCase();
      return query.isEmpty
          ? const <String>[]
          : names.where((name) => name.toLowerCase().contains(query)).take(12);
    },
    onSelected: widget.onChanged,
    fieldViewBuilder: (_, controller, node, submit) => TextField(
      key: const Key('personal-country'),
      controller: controller,
      focusNode: node,
      enabled: widget.enabled,
      textCapitalization: TextCapitalization.words,
      textDirection: widget.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      decoration: InputDecoration(
        hintText: widget.hint,
        helperText: failure,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.public),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: widget.clearLabel,
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
      onSubmitted: (_) => submit(),
    ),
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
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 240),
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              for (final option in options)
                ListTile(title: Text(option), onTap: () => select(option)),
            ],
          ),
        ),
      ),
    ),
  );
}
