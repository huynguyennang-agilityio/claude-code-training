import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/config/app_config.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:stridequest/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:stridequest/features/profile/data/models/profile_model.dart';
import 'package:stridequest/features/profile/domain/failures/profile_failure.dart';
import 'package:stridequest/features/profile/presentation/pages/profile_info_page.dart';

/// The Profile info screen in the real app against the real backend: an empty
/// profile, every field saved and read back in both unit systems, a refused
/// save (`422`) shown on the form, and the other documented errors at the
/// data source.
///
/// Needs the API running at `API_BASE_URL` (see `sign_in_flow_test.dart`) and
/// a simulator or emulator:
///
///     flutter test integration_test/profile_info_flow_test.dart -d <device id> \
///       --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/
///
/// The test creates its own user, so it can be run again and again.

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
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The text field of the form with this label above it.
Finder field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Column)).first;

/// What the text field with this label holds.
String valueOf(WidgetTester tester, String label) =>
    tester.widget<TextField>(fieldInput(label)).controller!.text;

Finder fieldInput(String label) =>
    find.descendant(of: field(label), matching: find.byType(TextField));

/// Wraps the real data source: while [corruptCountry] is set, `put` sends a
/// country the form cannot produce, so the backend answers `422`.
class _CorruptingDataSource implements ProfileRemoteDataSource {
  _CorruptingDataSource(this._real);

  final ProfileRemoteDataSource _real;
  bool corruptCountry = false;

  @override
  Future<ProfileModel> get() => _real.get();

  @override
  Future<ProfileModel> put(ProfileModel profile) =>
      _real.put(corruptCountry ? profile.copyWith(country: 'usa') : profile);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a user fills, saves and reads back the profile', (tester) async {
    final email = 'it-pr-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'run4medals';
    await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)).post<void>(
      'auth/signup',
      data: {
        'email': email,
        'password': password,
        'display_name': 'Profile Runner',
      },
    );

    await getIt.reset();
    configureDependencies();
    addTearDown(getIt.reset);
    final real = DioProfileRemoteDataSource(
      getIt<Dio>(instanceName: 'authenticatedDio'),
    );
    final remote = _CorruptingDataSource(real);
    getIt
      ..unregister<ProfileRemoteDataSource>()
      ..registerSingleton<ProfileRemoteDataSource>(remote);
    // The device may still hold the session of an earlier run.
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
    await pumpUntilFound(tester, find.byType(NavigationBar));

    Future<void> openProfileInfo() async {
      // The 'Profile saved' snackbar of the last save would cover Save.
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Profile'),
        ),
      );
      await pumpUntilFound(tester, find.text('First Name'));
    }

    Future<void> save() async {
      await tapVisible(tester, find.text('Save'));
    }

    Future<void> saveAndWaitForTab() async {
      await save();
      await pumpUntilFound(tester, find.text('Profile saved'));
      await pumpUntilFound(tester, find.byType(NavigationBar));
      // Back on the Profile tab, which has no form.
      expect(find.text('First Name'), findsNothing);
    }

    // 1. A user who never saved gets the empty, metric profile.
    await openProfileInfo();
    expect(find.text('Select your birthday'), findsOneWidget);
    expect(find.text('Select your country'), findsOneWidget);
    expect(find.text('Select your gender'), findsOneWidget);
    expect(find.text('cm'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    // 2. Fill every field, in metric.
    await typeInto(tester, fieldInput('First Name'), 'Max');
    await typeInto(tester, fieldInput('Last Name'), 'Darsonval');
    await tapVisible(tester, find.text('Select your birthday'));
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final now = DateTime.now().toUtc();
    // The picker opens on 1 January, 25 years ago.
    final birthday = formatDate(DateTime.utc(now.year - 25, 1, 15));
    expect(find.text(birthday), findsOneWidget);
    await tapVisible(tester, find.text('Select your country'));
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'viet',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Vietnam'),
      ),
    );
    await tester.pumpAndSettle();
    await typeInto(tester, fieldInput('State'), 'Da Nang');
    await tapVisible(tester, find.text('Select your gender'));
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Female'),
      ),
    );
    await tester.pumpAndSettle();
    await typeInto(tester, fieldInput('Height'), '180.3');
    await typeInto(tester, fieldInput('Weight'), '84.4');

    // 3. A save the backend refuses (`422`) shows its message and keeps the form.
    remote.corruptCountry = true;
    await save();
    await pumpUntilFound(
      tester,
      find.text('Country must be a two-letter code in capitals.'),
    );
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);

    // 4. The same form saves once the value is right.
    remote.corruptCountry = false;
    await saveAndWaitForTab();

    // 5. Reopen: every field came back, in metric.
    await openProfileInfo();
    expect(find.text('Max'), findsOneWidget);
    expect(find.text('Darsonval'), findsOneWidget);
    expect(find.text(birthday), findsOneWidget);
    expect(find.text('Vietnam'), findsOneWidget);
    expect(find.text('Da Nang'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(valueOf(tester, 'Height'), '180.3');
    expect(valueOf(tester, 'Weight'), '84.4');
    expect(find.text('cm'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    // 6. Switch to imperial: the stored values are shown in feet and pounds,
    //    and saving without touching them keeps them exactly.
    await tapVisible(tester, find.byType(Switch));
    expect(find.text('Height (ft)'), findsOneWidget);
    expect(valueOf(tester, 'Height (ft)'), '5');
    expect(valueOf(tester, 'Height (in)'), '11');
    expect(valueOf(tester, 'Weight'), '186.1');
    expect(find.text('lbs'), findsOneWidget);
    await saveAndWaitForTab();
    final unchanged = await real.get();
    expect(
      (unchanged.unitSystem, unchanged.heightCm, unchanged.weightKg),
      ('imperial', 180.3, 84.4),
    );

    // 7. Reopen in imperial, edit in feet and pounds, save, read back.
    await openProfileInfo();
    expect(find.text('Height (ft)'), findsOneWidget);
    expect(valueOf(tester, 'Weight'), '186.1');
    await typeInto(tester, fieldInput('Height (ft)'), '6');
    await typeInto(tester, fieldInput('Height (in)'), '0');
    await typeInto(tester, fieldInput('Weight'), '190');
    await saveAndWaitForTab();
    final edited = await real.get();
    expect(
      (edited.unitSystem, edited.heightCm, edited.weightKg),
      ('imperial', 182.9, 86.2),
    );
    await openProfileInfo();
    expect(valueOf(tester, 'Weight'), '190');
    expect(find.text('lbs'), findsOneWidget);

    // 8. Back to metric: the same stored values in centimetres and kilograms.
    await tapVisible(tester, find.byType(Switch));
    expect(valueOf(tester, 'Height'), '182.9');
    expect(valueOf(tester, 'Weight'), '86.2');

    // 9. Clearing an optional value saves null.
    await tapVisible(tester, find.byTooltip('Clear Birthday'));
    expect(find.text('Select your birthday'), findsOneWidget);
    await saveAndWaitForTab();
    final cleared = await real.get();
    expect(cleared.birthday, isNull);
    expect(cleared.country, 'VN');
    expect(cleared.unitSystem, 'metric');
  });

  testWidgets('the documented errors reach the data source as failures', (
    tester,
  ) async {
    final email = 'it-pe-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'run4medals';
    await getIt.reset();
    configureDependencies();
    addTearDown(getIt.reset);
    final repository = getIt<AuthRepository>();
    await repository.signOut();
    await repository.signUp(
      email: email,
      password: password,
      displayName: 'Profile Errors',
    );
    final source = DioProfileRemoteDataSource(
      getIt<Dio>(instanceName: 'authenticatedDio'),
    );

    // 422 validation_error names each broken field, with the backend message.
    final refused = await _failureOf(
      source.put(
        const ProfileModel(unitSystem: 'metric', country: 'usa', heightCm: 18),
      ),
    );
    expect(refused.code, ProfileFailureCode.validation);
    expect(refused.fieldErrors, {
      'country': 'Country must be a two-letter code in capitals.',
      'height_cm': 'Height must be between 50.0 and 272.0 cm.',
    });
    // The refused save changed nothing.
    expect((await source.get()).country, isNull);

    // 401 not_authenticated: no token at all (the public client sends none).
    final anonymous = DioProfileRemoteDataSource(
      getIt<Dio>(instanceName: 'publicDio'),
    );
    expect(
      (await _failureOf(anonymous.get())).code,
      ProfileFailureCode.notAuthenticated,
    );
    expect(
      (await _failureOf(
        anonymous.put(const ProfileModel(unitSystem: 'metric')),
      )).code,
      ProfileFailureCode.notAuthenticated,
    );

    // No server: a network failure.
    final offline = DioProfileRemoteDataSource(
      createDio(baseUrl: 'http://127.0.0.1:1/api/v1/'),
    );
    expect((await _failureOf(offline.get())).code, ProfileFailureCode.network);
  });
}

Future<ProfileFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ProfileFailure catch (failure) {
    return failure;
  }
  fail('Expected a ProfileFailure');
}
