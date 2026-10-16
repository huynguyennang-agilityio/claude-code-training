import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/home/presentation/pages/home_page.dart';

/// Route patterns that need a signed-in user, written exactly as the
/// [GoRoute.path] they guard (for example `/challenges/:id`, not
/// `/challenges/abc`). Routes nested under a protected pattern are protected
/// too. Home stays public for now; screens that need an account add their
/// pattern here.
const protectedPaths = <String>{};

final appRoutes = <RouteBase>[
  GoRoute(path: HomePage.path, builder: (context, state) => const HomePage()),
  GoRoute(
    path: SignInPage.path,
    builder: (context, state) => const SignInPage(),
  ),
];

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
  String initialLocation = HomePage.path,
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
/// lands on sign in goes home. While the stored session is still being read
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
  if (signedIn && location == SignInPage.path) return HomePage.path;
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
