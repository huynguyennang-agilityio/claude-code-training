import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/config/app_config.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';

/// The sign-in flow of `integration_test/sign_in_flow_test.dart` with Patrol, plus a step
/// outside the app. Use Patrol only for a flow that crosses into a native dialog or another
/// app; the rest stays in `integration_test`.
///
/// Needs the API running at `API_BASE_URL` (default `http://localhost:8000/api/v1/`, which a
/// simulator reaches on the host), `patrol_cli` and a booted iOS simulator:
///
///     patrol test --target patrol_test/sign_in_flow_test.dart -d <simulator>
///
/// The test creates its own user, so it can be run again and again.
Future<void> _startApp(PatrolIntegrationTester $) async {
  // The simulator keeps the keychain between runs, so start signed out and leave it so for
  // the next test, including the ones in `integration_test`.
  const storage = FlutterSecureStorage();
  await storage.deleteAll();
  addTearDown(storage.deleteAll);
  await getIt.reset();
  configureDependencies();
  addTearDown(getIt.reset);
  final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
  await $.pumpWidgetAndSettle(StrideQuestApp(authBloc: authBloc));
}

void main() {
  patrolTest('a user signs in, is greeted, and signs out', ($) async {
    final email = 'pt-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'run4medals';
    await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)).post<void>(
      'auth/signup',
      data: {
        'email': email,
        'password': password,
        'display_name': 'Patrol Runner',
      },
    );
    await _startApp($);

    // Signed out: the app starts on Sign in.
    expect($('Welcome back'), findsOneWidget);
    expect($(NavigationBar), findsNothing);

    // A wrong password is refused with the documented message.
    await $(AuthTextField).containing('Email').enterText(email);
    await $(AuthTextField).containing('Password').enterText('wrong-pass1');
    await $(FilledButton).containing('Sign in').tap();
    await $(
      AuthFailureCode.invalidCredentials.defaultMessage,
    ).waitUntilVisible();

    // The right one reaches Home; the Profile tab shows the name.
    await $(AuthTextField).containing('Password').enterText(password);
    await $(FilledButton).containing('Sign in').tap();
    await $(NavigationBar).waitUntilVisible();
    await $(NavigationBar).$('Profile').tap();
    expect($('Patrol Runner'), findsOneWidget);

    // Sign out returns to Sign in.
    await $(OutlinedButton).containing('Sign out').tap();
    await $('Welcome back').waitUntilVisible();
  });

  patrolTest('the app is still signed in after a visit to iOS Settings', (
    $,
  ) async {
    final email = 'pt-nat-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'run4medals';
    await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)).post<void>(
      'auth/signup',
      data: {
        'email': email,
        'password': password,
        'display_name': 'Native Runner',
      },
    );
    await _startApp($);
    await $(AuthTextField).containing('Email').enterText(email);
    await $(AuthTextField).containing('Password').enterText(password);
    await $(FilledButton).containing('Sign in').tap();
    await $(NavigationBar).waitUntilVisible();

    // Leave the app for the system Settings app, then come back.
    await $.platformAutomator.mobile.openPlatformApp(
      iosAppId: 'com.apple.Preferences',
    );
    await $.platformAutomator.mobile.openApp();

    await $(NavigationBar).waitUntilVisible();
    expect($('Welcome back'), findsNothing);
  });
}
