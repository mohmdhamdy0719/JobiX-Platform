import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'jobix_feedback.dart';
import 'tokens.dart';
import '../providers.dart';

class AppLanguageButton extends ConsumerWidget {
  const AppLanguageButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Tooltip(
      message: AppLocalizations.of(context)!.languageSwitch,
      child: TextButton.icon(
        key: const Key('app-language'),
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
          foregroundColor: TokensV0.deepBlue,
        ),
        icon: const Icon(Icons.translate, size: 18),
        label: Text(isArabic ? 'EN' : 'عربي'),
        onPressed: () async {
          final language = isArabic ? 'en' : 'ar';
          try {
            await ref.read(localeProvider.notifier).setOverride(language);
            if (context.mounted) {
              showJobixFeedback(
                context,
                language == 'ar'
                    ? 'تم تغيير لغة التطبيق إلى العربية.'
                    : 'App language changed to English.',
              );
            }
          } catch (_) {
            if (context.mounted) {
              showJobixFeedback(
                context,
                AppLocalizations.of(context)!.localWriteError,
                kind: JobixFeedbackKind.error,
              );
            }
          }
        },
      ),
    );
  }
}
