import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/auth/auth_page.dart';
import '../../features/boot/startup.dart';
import '../../features/core_mvp/career_page.dart';
import '../../features/core_mvp/credits_page.dart';
import '../../features/core_mvp/settings_page.dart';
import '../../features/home/home_page.dart';
import '../../features/onboarding/onboarding_controller.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/onboarding/research_context.dart';
import '../../features/onboarding/research_page.dart';
import '../../features/personal_information/personal_information_page.dart';
import '../../features/shell/foundation_page.dart';
import '../providers.dart';

String routeFor(StartupState state) => switch (state) {
  StartupState.boot => '/boot',
  StartupState.signedOut => '/onboarding',
  StartupState.signedIn => '/home',
  StartupState.updateRequired => '/update-required',
  StartupState.failed => '/startup-failed',
};

/// Pure guard contract shared by native navigation and tests.
String? sliceRedirect({
  required StartupState startup,
  required String path,
  required ResearchProgress? progress,
  required bool firstEntry,
  required bool entryLoading,
  required bool recovery,
}) {
  if (startup != StartupState.signedIn && startup != StartupState.signedOut) {
    final destination = routeFor(startup);
    return path == destination ? null : destination;
  }
  if (startup == StartupState.signedIn) {
    if (recovery) return path == '/recovery' ? null : '/recovery';
    if (path == '/home' ||
        path == '/career' ||
        path == '/settings' ||
        path == '/credits' ||
        path == '/career/personal') {
      return null;
    }
    final destination = entryLoading
        ? '/boot'
        : firstEntry
        ? '/career/personal'
        : '/home';
    return path == destination ? null : destination;
  }
  final destination = progress == null || !progress.onboardingDone
      ? '/onboarding'
      : !progress.complete
      ? '/research'
      : '/auth';
  if (path == '/auth' && progress?.complete == true) {
    return null;
  }
  if ((path == '/confirm' || path == '/forgot') && progress?.complete == true) {
    return null;
  }
  if (path == '/onboarding' && progress?.onboardingDone != true) return null;
  if (path == '/research' && progress?.onboardingDone == true) return null;
  return path == destination ? null : destination;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(startupProvider, (_, __) => refresh.value++);
  ref.listen(authSessionProvider, (_, __) => refresh.value++);
  ref.listen(researchProvider, (_, __) => refresh.value++);
  ref.listen(firstEntryProvider, (_, __) => refresh.value++);
  ref.listen(authFlowProvider, (_, __) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/boot',
    refreshListenable: refresh,
    redirect: (context, route) {
      final startup = ref.read(startupProvider);
      var state = startup.hasError
          ? StartupState.failed
          : startup.valueOrNull ?? StartupState.boot;
      final session = ref.read(authSessionProvider);
      if (state == StartupState.signedIn &&
          session.hasValue &&
          !sessionIsConfirmed(session.valueOrNull)) {
        state = StartupState.signedOut;
      }
      final entry = ref.read(firstEntryProvider);
      if (state == StartupState.signedIn && entry.hasError) {
        state = StartupState.failed;
      }
      final flow = ref.read(authFlowProvider);
      return sliceRedirect(
        startup: state,
        path: route.matchedLocation,
        progress: ref.read(researchProvider).valueOrNull,
        firstEntry: entry.valueOrNull ?? false,
        entryLoading: entry.isLoading,
        recovery: flow.recovery,
      );
    },
    routes: [
      for (final route in [
        StartupState.boot,
        StartupState.failed,
        StartupState.updateRequired,
      ])
        GoRoute(
          path: routeFor(route),
          builder: (context, state) => FoundationPage(state: route),
        ),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/research', builder: (_, __) => const ResearchPage()),
      GoRoute(
        path: '/auth',
        builder: (_, state) => AuthPage(
          key: ValueKey(state.uri.toString()),
          mode: state.uri.queryParameters['mode'] ?? 'gateway',
        ),
      ),
      GoRoute(
        path: '/confirm',
        builder: (_, __) => const AuthPage(mode: 'confirm'),
      ),
      GoRoute(
        path: '/forgot',
        builder: (_, __) => const AuthPage(mode: 'forgot'),
      ),
      GoRoute(
        path: '/recovery',
        builder: (_, __) => const AuthPage(mode: 'recovery'),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(path: '/career', builder: (_, __) => const CareerPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/credits', builder: (_, __) => const CreditsPage()),
      GoRoute(
        path: '/career/personal',
        builder: (_, __) => const PersonalInformationPage(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
