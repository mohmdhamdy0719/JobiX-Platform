import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/tokens.dart';
import 'core/navigation/router.dart';
import 'core/providers.dart';
import 'features/auth/auth_controller.dart';
import 'l10n/app_localizations.dart';

class JobixApp extends ConsumerWidget {
  const JobixApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authLinkServiceProvider);
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    final locale = ref.watch(resolvedLocaleProvider(device));
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: foundationTheme(languageCode: locale.languageCode),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
