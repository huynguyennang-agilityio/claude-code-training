import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/config/app_config.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';

/// Browse, search, filter, join, pause, resume and leave in the real app
/// against the real backend.
///
/// Needs the API running (see `sign_in_flow_test.dart`) and the demo
/// challenges, which are made through the admin API:
///
///     python -m demo.load_demo --email <an admin> --with-blocked
///
/// and a simulator or emulator:
///
///     flutter test integration_test/challenges_flow_test.dart -d <device id>
///
/// The test creates its own user and leaves its challenges before it ends, so
/// it can be run again and again.

const _oldQuarter = 'Old Quarter 50K Steps';
const _autumn = 'Hanoi Autumn 30K Steps';
const _myKhe = 'Mỹ Khê Bay 20 km';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for ${finder.describeMatch(Plurality.one)}.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, Finder finder, String text) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

/// Taps [text] and waits for [expected] to show: the action is a real request.
Future<void> tapAndWait(
  WidgetTester tester,
  Finder button,
  Finder expected,
) async {
  await tester.tap(button);
  await pumpUntilFound(tester, expected);
}

Future<void> openChallenge(WidgetTester tester, String title) async {
  // The list builds only the cards near the screen: start from the top and
  // scroll down to the one wanted.
  await tester.fling(find.byType(ListView), const Offset(0, 3000), 3000);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(title),
    300,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  // Centre it, clear of the edges of the list, so the tap lands on the card.
  await Scrollable.ensureVisible(
    tester.element(find.text(title)),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await pumpUntilFound(tester, find.byTooltip('Back'));
}

Future<void> back(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a user browses, joins, pauses, resumes and leaves', (
    tester,
  ) async {
    final email = 'it-ch-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'run4medals';
    await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)).post<void>(
      'auth/signup',
      data: {
        'email': email,
        'password': password,
        'display_name': 'Integration Runner',
      },
    );

    await getIt.reset();
    configureDependencies();
    addTearDown(getIt.reset);
    // The device may still hold the session of an earlier run: start signed out.
    await getIt<AuthRepository>().signOut();
    final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
    await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
    await tester.pumpAndSettle();

    await typeInto(tester, find.widgetWithText(AuthTextField, 'Email'), email);
    await typeInto(
      tester,
      find.widgetWithText(AuthTextField, 'Password'),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await pumpUntilFound(tester, find.text(_oldQuarter));

    // Browse: the demo challenges are there, with a Join button each.
    expect(find.widgetWithText(FilledButton, 'Join'), findsWidgets);

    // Filter by type, then search.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Swim'));
    await pumpUntilFound(tester, find.text(_myKhe));
    expect(find.text(_oldQuarter), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await pumpUntilFound(tester, find.text(_oldQuarter));
    await typeInto(tester, find.byType(TextField), 'autumn');
    await pumpUntilFound(tester, find.text(_autumn));
    expect(find.text(_oldQuarter), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await pumpUntilFound(tester, find.text(_oldQuarter));

    // Join Old Quarter from its detail.
    await openChallenge(tester, _oldQuarter);
    expect(find.text('Challenge ends in'), findsOneWidget);
    await tapAndWait(
      tester,
      find.text('Join Challenge'),
      find.widgetWithText(OutlinedButton, 'Pause'),
    );
    expect(find.text('Joined'), findsOneWidget);
    await back(tester);
    await pumpUntilFound(tester, find.text('Joined'));

    // The overlapping run challenge is blocked, and says by which.
    await openChallenge(tester, _autumn);
    await pumpUntilFound(
      tester,
      find.textContaining('“$_oldQuarter”, which runs at the same time'),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Join Challenge'),
          )
          .onPressed,
      isNull,
    );
    await back(tester);

    // Pausing frees the slot: Autumn can be joined, and Old Quarter then
    // cannot be resumed.
    await openChallenge(tester, _oldQuarter);
    await tapAndWait(
      tester,
      find.text('Pause'),
      find.widgetWithText(OutlinedButton, 'Resume'),
    );
    expect(find.text('Paused'), findsOneWidget);
    await back(tester);
    await openChallenge(tester, _autumn);
    await tapAndWait(
      tester,
      find.text('Join Challenge'),
      find.widgetWithText(OutlinedButton, 'Pause'),
    );
    await back(tester);
    await openChallenge(tester, _oldQuarter);
    await pumpUntilFound(
      tester,
      find.textContaining('“$_autumn”, which runs at the same time'),
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Resume'))
          .onPressed,
      isNull,
    );
    await back(tester);

    // Leave Autumn (after the question), then Old Quarter resumes.
    await openChallenge(tester, _autumn);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this challenge?'), findsOneWidget);
    await tapAndWait(
      tester,
      find.text('Leave challenge'),
      find.widgetWithText(FilledButton, 'Join Challenge'),
    );
    await back(tester);
    await openChallenge(tester, _oldQuarter);
    await tapAndWait(
      tester,
      find.text('Resume'),
      find.widgetWithText(OutlinedButton, 'Pause'),
    );

    // Leave it too, so the next run starts clean.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Leave'));
    await tester.pumpAndSettle();
    await tapAndWait(
      tester,
      find.text('Leave challenge'),
      find.widgetWithText(FilledButton, 'Join Challenge'),
    );
    expect(find.text('Joined'), findsNothing);
  });
}
