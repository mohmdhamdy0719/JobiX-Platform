import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/auth/auth_page.dart';
import '../../features/boot/startup.dart';
import '../../features/core_mvp/career_page.dart';
import '../../features/resume/resume_page.dart';
import '../../features/resume/resume_operation_page.dart';
import '../../features/core_mvp/credits_page.dart';
import '../../features/core_mvp/settings_page.dart';
import '../../features/core_mvp/account_information_page.dart';
import '../../features/home/home_page.dart';
import '../../features/onboarding/onboarding_controller.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/onboarding/research_context.dart';
import '../../features/onboarding/research_page.dart';
import '../../features/personal_information/personal_information_page.dart';
import '../../features/personal_information/profile_extras_page.dart';
import '../../features/career_profile/profile_sections.dart';
import '../../features/career_profile/text_section_page.dart';
import '../../features/builder/builder_scaffold.dart';
import '../../features/builder/builder_steps_page.dart';
import '../../features/builder/entity_editor_page.dart';
import '../../features/builder/review_page.dart';
import '../../features/shell/foundation_page.dart';
import '../providers.dart';
import 'back_policy.dart';

String routeFor(StartupState state) => switch (state) {
  StartupState.boot => '/boot',
  StartupState.signedOut => '/onboarding',
  StartupState.signedIn => '/home',
  StartupState.updateRequired => '/update-required',
  StartupState.failed => '/startup-failed',
};

final builderPath = RegExp(r'^/builder/[1-6]$');

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
        path == '/settings/account' ||
        path == '/credits' ||
        path == '/resume' ||
        path == '/export-history' ||
        path.startsWith('/resume-status/') ||
        path.startsWith('/resume-details/') ||
        builderPath.hasMatch(path) ||
        path.startsWith('/career/')) {
      return null;
    }
    final destination = entryLoading
        ? '/boot'
        : firstEntry
        ? '/builder/1'
        : '/home';
    return path == destination ? null : destination;
  }
  final destination = progress == null || !progress.onboardingDone
      ? '/onboarding'
      : !progress.experienceComplete
      ? '/research'
      : '/auth';
  if (path == '/auth' && progress?.experienceComplete == true) {
    return null;
  }
  if ((path == '/confirm' || path == '/forgot') &&
      progress?.experienceComplete == true) {
    return null;
  }
  if (path == '/onboarding' && progress?.onboardingDone != true) return null;
  if (path == '/research' &&
      progress?.onboardingDone == true &&
      progress?.firstLaunchComplete != true) {
    return null;
  }
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
    routes:
        [
              for (final route in [
                StartupState.boot,
                StartupState.failed,
                StartupState.updateRequired,
              ])
                GoRoute(
                  path: routeFor(route),
                  builder: (context, state) => FoundationPage(state: route),
                ),
              GoRoute(
                path: '/onboarding',
                builder: (_, __) => const OnboardingPage(),
              ),
              GoRoute(
                path: '/research',
                builder: (_, __) => const ResearchPage(),
              ),
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
              GoRoute(
                path: '/resume',
                builder: (_, state) => ResumePage(
                  historicalExportId: state.uri.queryParameters['again'],
                ),
              ),
              GoRoute(
                path: '/export-history',
                builder: (_, __) => const CreditsPage(initialTab: 1),
              ),
              GoRoute(
                path: '/resume-status/:id',
                builder: (_, state) => ResumeOperationPage(
                  exportId: state.pathParameters['id']!,
                  waiting: true,
                ),
              ),
              GoRoute(
                path: '/resume-details/:id',
                builder: (_, state) =>
                    ResumeOperationPage(exportId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsPage(),
              ),
              GoRoute(
                path: '/settings/account',
                builder: (_, __) => const AccountInformationPage(),
              ),
              GoRoute(
                path: '/credits',
                builder: (_, __) => const CreditsPage(),
              ),
              GoRoute(
                path: '/builder/:step',
                builder: (_, state) {
                  final step = int.tryParse(state.pathParameters['step']!) ?? 1;
                  return switch (step) {
                    1 => const PersonalInformationPage(builder: true),
                    2 => const TextSectionPage(
                      section: 'summary',
                      builderStep: 2,
                    ),
                    3 || 4 || 5 => BuilderSectionsStep(
                      key: ValueKey(
                        '$step-${state.uri.queryParameters['origin']}',
                      ),
                      step: step,
                      origin: EditorOrigin.parse(
                        state.uri.queryParameters['origin'],
                      ),
                    ),
                    _ => const ReviewPage(),
                  };
                },
              ),
              GoRoute(
                path: '/career/personal',
                builder: (_, state) => PersonalInformationPage(
                  origin: state.uri.queryParameters['origin'],
                ),
              ),
              GoRoute(
                path: '/career/extras',
                builder: (_, state) => ProfileExtrasPage(
                  origin: state.uri.queryParameters['origin'] ?? 'career',
                ),
              ),
              GoRoute(
                path: '/career/summary',
                builder: (_, state) => TextSectionPage(
                  section: 'summary',
                  origin: state.uri.queryParameters['origin'],
                ),
              ),
              GoRoute(
                path: '/career/edit/:section/:id',
                builder: (_, state) {
                  final section = EntitySection.values
                      .where((s) => s.key == state.pathParameters['section'])
                      .firstOrNull;
                  if (section == null) return const ReviewPage();
                  return EntityEditorPage(
                    key: ValueKey(state.uri.toString()),
                    section: section,
                    itemId: state.pathParameters['id']!,
                    origin: EditorOrigin.parse(
                      state.uri.queryParameters['origin'],
                    ),
                  );
                },
              ),
            ]
            .map(
              (route) => GoRoute(
                path: route.path,
                builder: (context, state) => JobixBackBoundary(
                  key: ValueKey(state.uri.toString()),
                  uri: state.uri,
                  child: route.builder!(context, state),
                ),
              ),
            )
            .toList(),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
