import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/career_profile_repository.dart';
import '../boot/startup.dart';
import '../onboarding/onboarding_controller.dart';
import 'auth_repository.dart';

final authApiProvider = FutureProvider<AuthApi>(
  (ref) async =>
      SupabaseAuthApi(await ref.watch(supabaseClientProvider.future)),
);
final profileApiProvider = FutureProvider<ProfileApi>(
  (ref) async =>
      SupabaseProfileApi(await ref.watch(supabaseClientProvider.future)),
);
final draftRepositoryProvider = FutureProvider<DraftRepository>((ref) async {
  final client = await ref.watch(supabaseClientProvider.future);
  final user = client.auth.currentUser?.id;
  if (user == null || !sessionIsConfirmed(client.auth.currentSession)) {
    throw StateError('AUTH_REQUIRED');
  }
  return DraftRepository(
    await ref.watch(databaseProvider.future),
    await ref.watch(profileApiProvider.future),
    user,
    () =>
        client.auth.currentUser?.id == user &&
        sessionIsConfirmed(client.auth.currentSession),
  );
});
final firstProfileProvider = FutureProvider<CareerProfile>(
  (ref) async => (await ref.watch(draftRepositoryProvider.future)).load(),
);

class AuthFlow {
  const AuthFlow({
    this.registration = false,
    this.pending = false,
    this.recovery = false,
    this.error = false,
  });
  final bool registration, pending, recovery, error;
}

final authFlowProvider = StateProvider<AuthFlow>((ref) => const AuthFlow());
final firstEntryProvider = FutureProvider<bool>((ref) async {
  ref.watch(authSessionProvider);
  final client = await ref.watch(supabaseClientProvider.future);
  if (!sessionIsConfirmed(client.auth.currentSession)) return false;
  if (await ref.watch(startupProvider.future) != StartupState.signedIn) {
    return false;
  }
  // Server authority distinguishes new OAuth registrations from returning
  // Google users even when either chooses the other form's button.
  return (await ref.watch(profileApiProvider.future)).claimRegistrationEntry();
});
final authLinkServiceProvider = FutureProvider<void>((ref) async {
  final client = await ref.watch(supabaseClientProvider.future);
  final links = AppLinks();
  final database = await ref.watch(databaseProvider.future);
  var account = client.auth.currentUser?.id;
  var active = true;
  Future<void> process(Uri? uri) async {
    if (!active || uri == null || !validAuthCallback(uri)) return;
    try {
      await (await ref.read(authApiProvider.future)).callback(uri);
    } catch (_) {
      if (active) {
        ref.read(authFlowProvider.notifier).state = const AuthFlow(error: true);
      }
    }
  }

  // Recovery event is delivered by Supabase after exchange; do not infer it from an untrusted URI.
  final auth = client.auth.onAuthStateChange.listen((event) async {
    if (!active) return;
    try {
      if (event.event == AuthChangeEvent.passwordRecovery) {
        ref.read(authFlowProvider.notifier).state = const AuthFlow(
          recovery: true,
        );
      }
      if (event.event == AuthChangeEvent.signedIn) {
        final next = event.session?.user.id;
        final previous = account;
        account = next;
        if (previous != null && previous != next) {
          await database.clearAccount(previous);
          if (active) ref.invalidate(researchProvider);
        }
        if (active) {
          ref.invalidate(firstEntryProvider);
          ref.invalidate(draftRepositoryProvider);
          ref.invalidate(firstProfileProvider);
          ref.invalidate(contextMergeProvider);
        }
      }
      if (event.event == AuthChangeEvent.signedOut) {
        final previous = account;
        account = null;
        if (previous != null) await database.clearAccount(previous);
        if (!active) return;
        ref.read(authFlowProvider.notifier).state = const AuthFlow();
        ref.invalidate(researchProvider);
        ref.invalidate(draftRepositoryProvider);
        ref.invalidate(firstProfileProvider);
        ref.invalidate(firstEntryProvider);
        ref.invalidate(contextMergeProvider);
      }
    } catch (_) {
      if (active) {
        ref.read(authFlowProvider.notifier).state = const AuthFlow(error: true);
      }
    }
  });
  final subscription = links.uriLinkStream.listen(
    (uri) => unawaited(process(uri)),
    onError: (_) {
      if (active) {
        ref.read(authFlowProvider.notifier).state = const AuthFlow(error: true);
      }
    },
  );
  ref.onDispose(() {
    active = false;
    unawaited(subscription.cancel());
    unawaited(auth.cancel());
  });
  try {
    await process(await links.getInitialLink());
  } catch (_) {
    if (active) {
      ref.read(authFlowProvider.notifier).state = const AuthFlow(error: true);
    }
  }
});

final contextMergeProvider = FutureProvider<void>((ref) async {
  final client = await ref.watch(supabaseClientProvider.future);
  if (!sessionIsConfirmed(client.auth.currentSession)) return;
  var progress = await ref.read(researchProvider.future);
  final user = client.auth.currentUser!.id;
  if (!progress.complete || progress.mergedUser != null) return;
  final database = await ref.read(databaseProvider.future);
  final api = await ref.watch(profileApiProvider.future);
  bool current() =>
      client.auth.currentUser?.id == user &&
      sessionIsConfirmed(client.auth.currentSession);
  final original = progress.encode();
  progress = progress.copy(commandKey: progress.commandKey ?? newCommandKey());
  if (!await database.writeOwnedResearch(
    user,
    original,
    progress.encode(),
    current,
  )) {
    throw StateError('RESEARCH_OWNER_CHANGED');
  }
  if (!current()) return;
  await api.saveContext(progress);
  if (!current()) return;
  if (!await database.writeOwnedResearch(
    user,
    progress.encode(),
    progress.copy(mergedUser: user).encode(),
    current,
  )) {
    throw StateError('RESEARCH_OWNER_CHANGED');
  }
  if (current()) ref.invalidate(researchProvider);
});

Future<void> signOutAndWipe(WidgetRef ref) async {
  final container = ProviderScope.containerOf(ref.context);
  final client = await container.read(supabaseClientProvider.future);
  final user = client.auth.currentUser?.id;
  final database = await container.read(databaseProvider.future);
  await (await container.read(authApiProvider.future)).signOut();
  if (user != null) {
    await database.clearAccount(user);
  }
  container.read(authFlowProvider.notifier).state = const AuthFlow();
  container.invalidate(researchProvider);
  container.invalidate(firstProfileProvider);
  container.invalidate(draftRepositoryProvider);
  container.invalidate(contextMergeProvider);
  container.invalidate(firstEntryProvider);
}
