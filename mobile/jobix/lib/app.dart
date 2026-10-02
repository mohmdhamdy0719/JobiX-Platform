import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/tokens.dart';
import 'core/navigation/router.dart';
import 'core/providers.dart';
import 'l10n/app_localizations.dart';

class JobixApp extends ConsumerWidget {
  const JobixApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: ref.watch(resolvedLocaleProvider(device)),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ref.watch(themeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
