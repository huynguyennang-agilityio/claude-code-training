import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/profile/domain/entities/profile.dart';
import 'package:stridequest/features/profile/domain/failures/profile_failure.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/profile_fixtures.dart';
import '../../../../helpers/profile_info_harness.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  late MockProfileRepository repository;

  setUpAll(registerProfileFallback);
  setUp(() => repository = repositoryWith(sampleProfile));

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  Future<void> tapSave(WidgetTester tester) async {
    await tapVisible(tester, find.text('Save'));
  }

  group('the form', () {
    testWidgets('shows the saved profile in imperial units', (tester) async {
      await pumpProfileInfo(tester, repository);

      expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);
      expect(textOf(tester, 'First Name'), 'Max');
      expect(textOf(tester, 'Last Name'), 'Darsonval');
      expect(find.text('Jun 24, 1991'), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);
      expect(textOf(tester, 'State'), 'California');
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Imperial (US)'), findsOneWidget);
      expect(find.text('Metric'), findsOneWidget);
      expect(textOf(tester, 'Height (ft)'), '5');
      expect(textOf(tester, 'Height (in)'), '11');
      expect(textOf(tester, 'Weight'), '186.1');
      expect(find.text('lbs'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('an empty profile shows empty fields in metric', (
      tester,
    ) async {
      await pumpProfileInfo(tester, repositoryWith(emptyProfile));

      expect(textOf(tester, 'First Name'), '');
      expect(find.text('Select your birthday'), findsOneWidget);
      expect(find.text('Select your country'), findsOneWidget);
      expect(find.text('Select your gender'), findsOneWidget);
      expect(textOf(tester, 'Height'), '');
      expect(find.text('cm'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('the Units switch shows the same values in metric and back', (
      tester,
    ) async {
      await pumpProfileInfo(tester, repository);

      await tapVisible(tester, find.byType(Switch));

      expect(textOf(tester, 'Height'), '180.3');
      expect(textOf(tester, 'Weight'), '84.4');
      expect(find.text('Height (ft)'), findsNothing);

      await tapVisible(tester, find.byType(Switch));

      expect(textOf(tester, 'Height (ft)'), '5');
      expect(textOf(tester, 'Height (in)'), '11');
      expect(textOf(tester, 'Weight'), '186.1');
    });

    testWidgets('Save sends the loaded metric values, even after a unit trip', (
      tester,
    ) async {
      await pumpProfileInfo(tester, repository);

      await tapVisible(tester, find.byType(Switch));
      await tapVisible(tester, find.byType(Switch));
      await tapSave(tester);

      expect(savedProfile(repository), sampleProfile);
    });

    testWidgets('an edited name is saved, a cleared one is sent as null', (
      tester,
    ) async {
      await pumpProfileInfo(tester, repository);

      await tester.enterText(fieldFor('First Name'), '  Lan ');
      await tester.enterText(fieldFor('State'), '   ');
      await tapSave(tester);

      final saved = savedProfile(repository);
      expect(saved.firstName, 'Lan');
      expect(saved.state, isNull);
      expect(saved.lastName, 'Darsonval');
    });

    testWidgets('imperial height and weight are saved as metric', (
      tester,
    ) async {
      await pumpProfileInfo(tester, repository);

      await tester.enterText(fieldFor('Height (ft)'), '6');
      await tester.enterText(fieldFor('Height (in)'), '2');
      await tester.enterText(fieldFor('Weight'), '200');
      await tapSave(tester);

      final saved = savedProfile(repository);
      expect(saved.heightCm, 188.0);
      expect(saved.weightKg, 90.7);
      expect(saved.unitSystem, UnitSystem.imperial);
    });

    testWidgets('clearing height and weight sends null', (tester) async {
      await pumpProfileInfo(tester, repository);

      await tester.enterText(fieldFor('Height (ft)'), '');
      await tester.enterText(fieldFor('Height (in)'), '');
      await tester.enterText(fieldFor('Weight'), '');
      await tapSave(tester);

      final saved = savedProfile(repository);
      expect(saved.heightCm, isNull);
      expect(saved.weightKg, isNull);
    });

    testWidgets(
      'a bad value shows its error in the shown units and blocks Save',
      (tester) async {
        await pumpProfileInfo(tester, repository);

        await tester.enterText(fieldFor('Height (ft)'), '9');
        await tester.enterText(fieldFor('Weight'), '10');
        await tester.pumpAndSettle();

        expect(
          find.text('Height must be between 1 ft 8 in and 8 ft 11 in.'),
          findsOneWidget,
        );
        expect(
          find.text('Weight must be between 44.1 and 881.8 lbs.'),
          findsOneWidget,
        );

        await tapSave(tester);
        verifyNever(() => repository.saveProfile(any()));

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(find.textContaining('must be between'), findsNothing);
        expect(textOf(tester, 'Height'), '180.3');
      },
    );

    testWidgets('a name over 50 characters shows an error', (tester) async {
      await pumpProfileInfo(tester, repository);

      await tester.enterText(fieldFor('Last Name'), 'x' * 51);
      await tester.pumpAndSettle();

      expect(find.text('Last name is at most 50 characters.'), findsOneWidget);
    });
  });

  group('pickers', () {
    testWidgets('Gender: a bottom sheet with the four choices', (tester) async {
      await pumpProfileInfo(tester, repository);

      await tapVisible(tester, pickerFor('Gender'));
      for (final label in [
        'Female',
        'Male',
        'Non-binary',
        'Prefer not to say',
      ]) {
        expect(inSheet(label), findsOneWidget);
      }
      await tester.tap(find.text('Non-binary'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(savedProfile(repository).gender, Gender.nonBinary);
    });

    testWidgets('Country: a searchable list of names with ISO codes', (
      tester,
    ) async {
      await pumpProfileInfo(tester, repository);

      await tapVisible(tester, pickerFor('Country'));
      await tester.enterText(find.byType(TextField).last, 'viet');
      await tester.pumpAndSettle();

      expect(inSheet('Vietnam'), findsOneWidget);
      expect(inSheet('United States'), findsNothing);

      await tester.tap(find.text('Vietnam'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(savedProfile(repository).country, 'VN');
    });

    testWidgets('Country: a search without a match says so', (tester) async {
      await pumpProfileInfo(tester, repository);

      await tapVisible(tester, pickerFor('Country'));
      await tester.enterText(find.byType(TextField).last, 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No country found'), findsOneWidget);
    });

    testWidgets('Birthday: the date picker sets the day', (tester) async {
      await pumpProfileInfo(tester, repository);

      await tapVisible(tester, pickerFor('Birthday'));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Jun 15, 1991'), findsOneWidget);
      await tapSave(tester);
      expect(savedProfile(repository).birthday, DateTime.utc(1991, 6, 15));
    });

    testWidgets('dismissing a picker changes nothing', (tester) async {
      await pumpProfileInfo(tester, repository);

      await tapVisible(tester, pickerFor('Birthday'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Jun 24, 1991'), findsOneWidget);
    });

    testWidgets('the clear buttons empty a picked value', (tester) async {
      await pumpProfileInfo(tester, repository);

      for (final label in ['Birthday', 'Country', 'Gender']) {
        await tapVisible(tester, find.byTooltip('Clear $label'));
      }
      await tapSave(tester);

      final saved = savedProfile(repository);
      expect(saved.birthday, isNull);
      expect(saved.country, isNull);
      expect(saved.gender, isNull);
      expect(find.text('Select your birthday'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('loading shows a spinner and no form', (tester) async {
      when(
        () => repository.getProfile(),
      ).thenAnswer((_) => Completer<Profile>().future);

      await pumpProfileInfo(tester, repository, settle: false);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('First Name'), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('a load error says why and Try again loads the form', (
      tester,
    ) async {
      var calls = 0;
      when(() => repository.getProfile()).thenAnswer((_) async {
        if (calls++ == 0) {
          throw const ProfileFailure(ProfileFailureCode.network);
        }
        return sampleProfile;
      });
      await pumpProfileInfo(tester, repository);

      expect(
        find.text('Cannot reach StrideQuest. Check your connection.'),
        findsOneWidget,
      );
      expect(find.text('First Name'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'First Name'), 'Max');
    });

    testWidgets('saving disables Save, shows a spinner and locks the fields', (
      tester,
    ) async {
      final saving = Completer<Profile>();
      when(
        () => repository.saveProfile(any()),
      ).thenAnswer((_) => saving.future);
      await pumpProfileInfo(tester, repository);

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Save'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(fieldFor('First Name')).enabled, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

      saving.complete(sampleProfile);
      await tester.pumpAndSettle();
    });

    testWidgets('a refused save shows a banner and keeps the form', (
      tester,
    ) async {
      when(() => repository.saveProfile(any())).thenThrow(
        const ProfileFailure(
          ProfileFailureCode.validation,
          fieldErrors: {'country': 'Country must be a two-letter code.'},
        ),
      );
      await pumpProfileInfo(tester, repository);

      await tapSave(tester);

      expect(find.text('Country must be a two-letter code.'), findsOneWidget);
      expect(textOf(tester, 'First Name'), 'Max');
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('a saved profile shows a snackbar and goes back', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => profileInfoPage(repository),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('First Name'), findsOneWidget);

      await tapSave(tester);

      expect(find.text('Profile saved'), findsOneWidget);
      expect(find.text('First Name'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });

  for (final size in [smallPhone, largePhone]) {
    for (final textScale in [1.0, 2.0]) {
      group('on $size at text x$textScale', () {
        testWidgets('the form fits and is accessible', (tester) async {
          await pumpProfileInfo(
            tester,
            repository,
            size: size,
            textScale: textScale,
          );

          expectNoLayoutException(tester);
          await expectAccessible(tester);
        });

        testWidgets('the empty metric form fits and is accessible', (
          tester,
        ) async {
          await pumpProfileInfo(
            tester,
            repositoryWith(emptyProfile),
            size: size,
            textScale: textScale,
          );

          expectNoLayoutException(tester);
          await expectAccessible(tester);
        });

        testWidgets('errors and the save banner fit and are accessible', (
          tester,
        ) async {
          when(
            () => repository.saveProfile(any()),
          ).thenThrow(const ProfileFailure(ProfileFailureCode.network));
          await pumpProfileInfo(
            tester,
            repository,
            size: size,
            textScale: textScale,
          );
          await tester.enterText(fieldFor('First Name'), 'x' * 51);
          await tester.enterText(fieldFor('Height (ft)'), '9');
          await tester.enterText(fieldFor('Weight'), '10');
          await tester.pumpAndSettle();
          await tester.enterText(fieldFor('First Name'), 'Lan');
          await tester.pumpAndSettle();
          await tester.enterText(fieldFor('Height (ft)'), '5');
          await tester.enterText(fieldFor('Weight'), '180');
          await tapSave(tester);
          await tester.enterText(fieldFor('Weight'), '10');
          await tester.pumpAndSettle();

          expectNoLayoutException(tester);
          await expectAccessible(tester);
        });

        testWidgets('the load error fits and is accessible', (tester) async {
          when(
            () => repository.getProfile(),
          ).thenThrow(const ProfileFailure(ProfileFailureCode.unknown));
          await pumpProfileInfo(
            tester,
            repository,
            size: size,
            textScale: textScale,
          );

          expectNoLayoutException(tester);
          await expectAccessible(tester);
        });

        testWidgets('loading fits', (tester) async {
          when(
            () => repository.getProfile(),
          ).thenAnswer((_) => Completer<Profile>().future);
          await pumpProfileInfo(
            tester,
            repository,
            size: size,
            textScale: textScale,
            settle: false,
          );
          await tester.pump();

          expectNoLayoutException(tester);
        });

        testWidgets('saving fits and is accessible', (tester) async {
          final saving = Completer<Profile>();
          when(
            () => repository.saveProfile(any()),
          ).thenAnswer((_) => saving.future);
          await pumpProfileInfo(
            tester,
            repository,
            size: size,
            textScale: textScale,
          );
          await tester.ensureVisible(find.text('Save'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save'));
          await tester.pump();

          expectNoLayoutException(tester);
          saving.complete(sampleProfile);
          await tester.pumpAndSettle();
        });
      });
    }
  }
}
