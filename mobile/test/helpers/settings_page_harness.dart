import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stridequest/core/theme/app_theme.dart';

import 'pump_screen.dart';

/// Text of the screen under a settings page, to tell that the page popped.
const parentText = 'Profile tab';

/// What the `/profile` route shows, so a test can tell it from the parent.
const profileRouteText = 'Profile route';

/// Pumps [page] at [path], pushed over a parent route under a [GoRouter], as
/// the app does, so a save can pop back to the parent. [refreshListenable] is
/// the router's, as `AuthBloc`'s stream is in the app. With [pushed] false the
/// page is the only one on the stack (a deep link).
Future<void> pumpSettingsPage(
  WidgetTester tester, {
  required String path,
  required Widget Function() page,
  Size size = smallPhone,
  double textScale = 1,
  Listenable? refreshListenable,
  bool pushed = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: pushed ? '/' : path,
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text(parentText)),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Text(profileRouteText)),
      ),
      GoRoute(path: path, builder: (context, state) => page()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  if (pushed) unawaited(router.push(path));
  await tester.pumpAndSettle();
}
