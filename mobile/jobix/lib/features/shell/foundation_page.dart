import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/async_states.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/localization/direction.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/secure_session_storage.dart';
import '../auth/auth_controller.dart';
import '../boot/startup.dart';

class FoundationPage extends ConsumerWidget {
  const FoundationPage({super.key, required this.state});
  final StartupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    if (state == StartupState.boot) {
      return const Scaffold(
        backgroundColor: TokensV0.navy,
        body: SafeArea(child: Center(child: BrandedLoadingState(onDark: true))),
      );
    }
    final failure = ref.watch(startupProvider).error;
    final failureMessage = failure is StartupFailure
        ? switch (failure.stage) {
            StartupFailureStage.protectedStorage => copy.startupStorageFailed,
            StartupFailureStage.sessionRecovery => copy.startupSessionFailed,
            StartupFailureStage.appPolicy => copy.startupPolicyFailed,
          }
        : copy.startupFailed;
    final title = switch (state) {
      StartupState.boot => copy.boot,
      StartupState.signedOut => copy.signedOut,
      StartupState.signedIn => copy.signedIn,
      StartupState.updateRequired => copy.updateRequired,
      StartupState.failed => copy.startupFailed,
    };
    return Scaffold(
      backgroundColor: TokensV0.canvas,
      appBar: AppBar(title: Text(copy.appTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(TokensV0.space24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state != StartupState.boot &&
                            state != StartupState.failed)
                          Semantics(
                            label: copy.appTitle,
                            child: const Center(child: BrandMark(size: 96)),
                          ),
                        const SizedBox(height: TokensV0.space32),
                        if (state != StartupState.failed)
                          Text(
                            title,
                            key: const Key('startup-state'),
                            textAlign: TextAlign.center,
                            textDirection: contentDirection(
                              title,
                              Directionality.of(context),
                            ),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        const SizedBox(height: TokensV0.space16),
                        if (state == StartupState.boot)
                          Column(
                            children: [
                              const BrandMark(size: 72),
                              const SizedBox(height: TokensV0.space24),
                              const SizedBox(
                                width: 180,
                                child: LinearProgressIndicator(minHeight: 3),
                              ),
                            ],
                          )
                        else if (state == StartupState.failed)
                          BrandedErrorState(
                            message: failureMessage,
                            retryLabel: copy.retry,
                            messageKey: const Key('startup-state'),
                            onRetry: () {
                              if (ref.read(databaseProvider).hasError) {
                                ref.invalidate(databaseProvider);
                              }
                              if (ref.read(supabaseClientProvider).hasError) {
                                ref.invalidate(supabaseClientProvider);
                              }
                              if (ref.read(firstEntryProvider).hasError) {
                                ref.invalidate(firstEntryProvider);
                              }
                              ref.invalidate(startupProvider);
                            },
                          )
                        else if (state != StartupState.updateRequired)
                          Text(
                            copy.placeholder,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        if (state == StartupState.signedIn) ...[
                          const SizedBox(height: TokensV0.space16),
                          OutlinedButton(
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
