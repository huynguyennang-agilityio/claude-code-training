import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/sign_in_bloc.dart';
import '../../features/auth/presentation/bloc/sign_up_bloc.dart';
import '../../features/auth/presentation/pages/change_email_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import '../../features/challenges/presentation/bloc/challenges_bloc.dart';
import '../../features/challenges/presentation/pages/challenge_detail_page.dart';
import '../../features/challenges/presentation/pages/challenges_page.dart';
import '../../features/home/presentation/pages/home_shell.dart';
import '../../features/medals/presentation/pages/medals_page.dart';
import '../../features/profile/presentation/pages/profile_info_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/runs/presentation/bloc/health_gate_bloc.dart';
import '../../features/runs/presentation/pages/active_challenges_page.dart';
import '../di/injection.dart';

/// Route patterns that need a signed-in user, written as the full pattern
/// from the root (`GoRouterState.fullPath`, for example `/challenges/:id` or
/// `/challenges/:id/edit`), not as concrete locations like `/challenges/abc`
/// or as a nested route's relative `path` like `edit`. Routes nested under a
/// protected pattern are protected too. The four tabs are protected, and so is
/// `/`, which leads to them: a signed-out user starts on sign in. Screens that
/// need an account add their pattern here.
const protectedPaths = <String>{
  HomeShell.path,
  ChallengesPage.path,
  ChallengeDetailPage.path,
  ActiveChallengesPage.path,
  MedalsPage.path,
  ProfilePage.path,
  ProfileInfoPage.path,
  ChangeEmailPage.path,
  ChangePasswordPage.path,
};

final appRoutes = <RouteBase>[
  // `/` has no screen: it leads to the first tab.
  GoRoute(
    path: HomeShell.path,
    redirect: (context, state) => ChallengesPage.path,
  ),
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        HomeShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: ChallengesPage.path,
            builder: (context, state) => BlocProvider(
              create: (_) =>
                  getIt<ChallengesBloc>()..add(const ChallengesStarted()),
              child: const ChallengesPage(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: ActiveChallengesPage.path,
            builder: (context, state) => BlocProvider(
              create: (_) =>
                  getIt<HealthGateBloc>()..add(const HealthGateStarted()),
              child: const ActiveChallengesPage(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: MedalsPage.path,
            builder: (context, state) => const MedalsPage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: ProfilePage.path,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  ),
  // The detail has no tab bar, so it sits above the shell. The route carries the id only.
  GoRoute(
    path: ChallengeDetailPage.path,
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      return BlocProvider(
        create: (_) {
          final bloc = getIt<ChallengeDetailBloc>();
          if (id != null) bloc.add(ChallengeDetailStarted(id));
          return bloc;
        },
        child: ChallengeDetailPage(challengeId: id ?? 0),
      );
    },
  ),
  // The account screens have no tab bar either, so they sit above the shell
  // like the detail (the app has no navigator keys to target instead).
  GoRoute(
    path: ProfileInfoPage.path,
    builder: (context, state) => const ProfileInfoPage(),
  ),
  GoRoute(
    path: ChangeEmailPage.path,
    builder: (context, state) => const ChangeEmailPage(),
  ),
  GoRoute(
    path: ChangePasswordPage.path,
    builder: (context, state) => const ChangePasswordPage(),
  ),
  GoRoute(
    path: SignInPage.path,
    builder: (context, state) => BlocProvider(
      create: (_) => getIt<SignInBloc>(),
      child: const SignInPage(),
    ),
  ),
  GoRoute(
    path: SignUpPage.path,
    builder: (context, state) => BlocProvider(
      create: (_) => getIt<SignUpBloc>(),
      child: const SignUpPage(),
    ),
  ),
];

/// Pages for signed-out users only; a signed-in user who lands on one goes to
/// the first tab.
const _signedOutOnlyPaths = {SignInPage.path, SignUpPage.path};

/// Builds the app router. Sign-in and sign-out redirects come only from
/// [authRedirect], driven by [authBloc]; screens never navigate on auth
/// changes themselves.
///
/// [refreshListenable] must fire whenever [authBloc] emits; pass a
/// `GoRouterRefreshStream(authBloc.stream)`. The caller owns it and disposes
/// it with the router (`GoRouter.dispose` does not).
GoRouter createAppRouter({
  required AuthBloc authBloc,
  required Listenable refreshListenable,
  List<RouteBase>? routes,
  Set<String> protected = protectedPaths,
  String initialLocation = HomeShell.path,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: routes ?? appRoutes,
    refreshListenable: refreshListenable,
    redirect: (context, state) => authRedirect(
      authBloc.state,
      location: state.matchedLocation,
      route: state.fullPath,
      protected: protected,
    ),
  );
}

/// Where to send the user for [location], or null to stay.
///
/// [route] is the matched route pattern (`GoRouterState.fullPath`, for
/// example `/challenges/:id`); protection is decided from it, because
/// [location] holds concrete parameter values. A protected route needs an
/// authenticated user; anyone signed out goes to sign in. A signed-in user who
/// lands on sign in or sign up goes to the first tab. While the stored session is still being read
/// ([AuthUnknown]) nothing moves, so a deep link to a protected page survives
/// app start.
String? authRedirect(
  AuthState auth, {
  required String location,
  required String? route,
  required Set<String> protected,
}) {
  if (auth is AuthUnknown) return null;
  final signedIn = auth is AuthAuthenticated;
  if (!signedIn && isProtectedRoute(route, protected)) return SignInPage.path;
  if (signedIn && _signedOutOnlyPaths.contains(location)) {
    return ChallengesPage.path;
  }
  return null;
}

/// Whether the route pattern [route] is in [protected] or nested under one of
/// its patterns. Nesting is checked per path segment, so `/challenges` does
/// not protect `/challenges-archive`. A location that matched no route
/// ([route] is null) is left to the router's error page.
bool isProtectedRoute(String? route, Set<String> protected) {
  if (route == null) return false;
  return protected.any((p) => route == p || route.startsWith('$p/'));
}
