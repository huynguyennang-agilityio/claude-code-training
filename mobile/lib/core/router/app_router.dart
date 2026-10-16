import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import 'go_router_refresh_stream.dart';

/// Routes that need a signed-in user. Home stays public for now; screens that
/// need an account add their path here.
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
GoRouter createAppRouter({
  required AuthBloc authBloc,
  List<RouteBase>? routes,
  Set<String> protected = protectedPaths,
  String initialLocation = HomePage.path,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: routes ?? appRoutes,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) =>
        authRedirect(authBloc.state, state.matchedLocation, protected),
  );
}

/// Where to send the user for [location], or null to stay.
///
/// A protected route needs an authenticated user; anyone else goes to sign
/// in. A signed-in user who lands on sign in goes home.
String? authRedirect(AuthState auth, String location, Set<String> protected) {
  final signedIn = auth is AuthAuthenticated;
  if (!signedIn && protected.contains(location)) return SignInPage.path;
  if (signedIn && location == SignInPage.path) return HomePage.path;
  return null;
}
