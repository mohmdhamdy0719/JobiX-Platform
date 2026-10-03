import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../providers.dart';

class AppLanguageButton extends ConsumerWidget {
  const AppLanguageButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const Key('app-language'),
    tooltip: AppLocalizations.of(context)!.languageSwitch,
    icon: const Icon(Icons.language),
    onPressed: () async {
      final language = Localizations.localeOf(context).languageCode == 'ar'
          ? 'en'
          : 'ar';
      try {
        await ref.read(localeProvider.notifier).setOverride(language);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.localWriteError),
            ),
          );
        }
      }
    },
  );
}
