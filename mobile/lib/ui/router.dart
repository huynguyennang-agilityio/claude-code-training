import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: HomeScreen.path,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
