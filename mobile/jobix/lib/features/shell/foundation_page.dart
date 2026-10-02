import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/localization/direction.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/secure_session_storage.dart';
import '../boot/startup.dart';

class FoundationPage extends ConsumerWidget {
  const FoundationPage({super.key, required this.state});
  final StartupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    final title = switch (state) {
      StartupState.boot => copy.boot,
      StartupState.signedOut => copy.signedOut,
      StartupState.signedIn => copy.signedIn,
      StartupState.updateRequired => copy.updateRequired,
      StartupState.failed => copy.startupFailed,
    };
    return Scaffold(
      appBar: AppBar(title: Text(copy.appTitle)),
      body: Padding(
        padding: const EdgeInsetsDirectional.all(TokensV0.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              key: const Key('startup-state'),
              textDirection: contentDirection(
                title,
                Directionality.of(context),
              ),
            ),
            const SizedBox(height: TokensV0.space16),
            if (state == StartupState.boot)
              const CircularProgressIndicator()
            else if (state == StartupState.failed)
              TextButton(
                onPressed: () {
                  if (ref.read(databaseProvider).hasError) {
                    ref.invalidate(databaseProvider);
                  }
                  if (ref.read(supabaseClientProvider).hasError) {
                    ref.invalidate(supabaseClientProvider);
                  }
                  ref.invalidate(startupProvider);
                },
                child: Text(copy.retry),
              )
            else if (state != StartupState.updateRequired)
              Text(copy.placeholder),
            if (state == StartupState.signedIn)
              TextButton(
                onPressed: () async {
                  try {
                    final client = await ref.read(
                      supabaseClientProvider.future,
                    );
                    await client.auth.signOut();
                    await SecureSessionStorage(
                      ref.read(secretStoreProvider),
                      ref.read(appConfigProvider).environment.name,
                    ).removePersistedSession();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(copy.signOutFailed)),
                      );
                    }
                  }
                },
                child: Text(copy.signOut),
              ),
          ],
        ),
      ),
    );
  }
}
