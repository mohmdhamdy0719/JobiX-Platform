import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/boot/startup.dart';
import '../../features/shell/foundation_page.dart';
import '../providers.dart';

String routeFor(StartupState state) => switch (state) {
  StartupState.boot => '/boot',
  StartupState.signedOut => '/signed-out',
  StartupState.signedIn => '/signed-in',
  StartupState.updateRequired => '/update-required',
  StartupState.failed => '/startup-failed',
};

final routerProvider = Provider<GoRouter>((ref) {
  final state = ref
      .watch(startupProvider)
      .when(
        data: (value) => value,
        loading: () => StartupState.boot,
        error: (_, __) => StartupState.failed,
      );
  final destination = routeFor(state);
  final router = GoRouter(
    initialLocation: '/boot',
    redirect: (context, route) =>
        route.matchedLocation == destination ? null : destination,
    routes: [
      for (final route in StartupState.values)
        GoRoute(
          path: routeFor(route),
          builder: (context, state) => FoundationPage(state: route),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
