import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/profile/domain/entities/profile.dart';
import 'package:stridequest/features/profile/domain/failures/profile_failure.dart';
import 'package:stridequest/features/profile/presentation/bloc/profile_info_bloc.dart';

import '../../../../helpers/profile_fixtures.dart';

final _loaded = ProfileInfoForm.fromProfile(sampleProfile);

void main() {
  late MockProfileRepository repository;

  setUpAll(registerProfileFallback);
  setUp(() {
    repository = MockProfileRepository();
    when(() => repository.getProfile()).thenAnswer((_) async => sampleProfile);
  });

  ProfileInfoBloc build() => ProfileInfoBloc(
    repository,
    clock: () => DateTime.utc(2026, 10, 26, 23, 30),
  );

  blocTest<ProfileInfoBloc, ProfileInfoState>(
    'loads the profile into the form',
    build: build,
    act: (bloc) => bloc.add(const ProfileInfoStarted()),
    expect: () => [const ProfileInfoLoading(), _loaded],
    verify: (_) {
      expect(_loaded.firstName, 'Max');
      expect(_loaded.heightCm, 180.3);
      expect(_loaded.unitSystem, UnitSystem.imperial);
    },
  );

  blocTest<ProfileInfoBloc, ProfileInfoState>(
    'an empty profile gives an empty metric form',
    setUp: () => when(
      () => repository.getProfile(),
    ).thenAnswer((_) async => emptyProfile),
    build: build,
    act: (bloc) => bloc.add(const ProfileInfoStarted()),
    expect: () => [
      const ProfileInfoLoading(),
      ProfileInfoForm.fromProfile(emptyProfile),
    ],
  );

  blocTest<ProfileInfoBloc, ProfileInfoState>(
    'a load failure can be retried',
    setUp: () {
      var calls = 0;
      when(() => repository.getProfile()).thenAnswer((_) async {
        if (calls++ == 0) {
          throw const ProfileFailure(ProfileFailureCode.network);
        }
        return sampleProfile;
      });
    },
    build: build,
    act: (bloc) async {
      bloc.add(const ProfileInfoStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ProfileInfoStarted());
    },
    expect: () => [
      const ProfileInfoLoading(),
      const ProfileInfoLoadFailed(ProfileFailure(ProfileFailureCode.network)),
      const ProfileInfoLoading(),
      _loaded,
    ],
  );

  group('editing', () {
    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'a name over 50 characters is an error until it is fixed',
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc
        ..add(ProfileInfoTextChanged(ProfileField.firstName, 'x' * 51))
        ..add(const ProfileInfoTextChanged(ProfileField.firstName, 'Lan')),
      expect: () => [
        _loaded.copyWith(
          firstName: 'x' * 51,
          errors: {ProfileField.firstName: ProfileFieldError.tooLong},
        ),
        _loaded.copyWith(firstName: 'Lan', errors: {}),
      ],
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'the state is limited to 100 characters, spaces not counted',
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc
        ..add(ProfileInfoTextChanged(ProfileField.state, '${'x' * 100}  '))
        ..add(ProfileInfoTextChanged(ProfileField.state, 'x' * 101)),
      expect: () => [
        _loaded.copyWith(state: '${'x' * 100}  '),
        _loaded.copyWith(
          state: 'x' * 101,
          errors: {ProfileField.state: ProfileFieldError.tooLong},
        ),
      ],
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'picked values replace the old ones and can be cleared',
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc
        ..add(const ProfileInfoCountryChanged('VN'))
        ..add(const ProfileInfoGenderChanged(null))
        ..add(ProfileInfoBirthdayChanged(DateTime.utc(2000, 2, 29))),
      expect: () => [
        _loaded.copyWith(country: 'VN'),
        _loaded.copyWith(country: 'VN', gender: null),
        _loaded.copyWith(
          country: 'VN',
          gender: null,
          birthday: DateTime.utc(2000, 2, 29),
        ),
      ],
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'a birthday must be after 1900-01-01 and not after today in UTC',
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc
        ..add(ProfileInfoBirthdayChanged(DateTime.utc(1900)))
        ..add(ProfileInfoBirthdayChanged(DateTime.utc(2026, 10, 27)))
        ..add(ProfileInfoBirthdayChanged(DateTime.utc(2026, 10, 26))),
      expect: () => [
        _loaded.copyWith(
          birthday: DateTime.utc(1900),
          errors: {ProfileField.birthday: ProfileFieldError.outOfRange},
        ),
        _loaded.copyWith(
          birthday: DateTime.utc(2026, 10, 27),
          errors: {ProfileField.birthday: ProfileFieldError.outOfRange},
        ),
        _loaded.copyWith(birthday: DateTime.utc(2026, 10, 26), errors: {}),
      ],
    );
  });

  group('height and weight', () {
    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'switching units changes nothing but the unit: no rounding drift',
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc
        ..add(const ProfileInfoUnitsChanged(UnitSystem.metric))
        ..add(const ProfileInfoUnitsChanged(UnitSystem.imperial))
        ..add(const ProfileInfoUnitsChanged(UnitSystem.metric)),
      verify: (bloc) {
        final form = bloc.state as ProfileInfoForm;
        expect(form.heightCm, 180.3);
        expect(form.weightKg, 84.4);
        expect(form.unitSystem, UnitSystem.metric);
      },
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'metric height and weight are rounded to one decimal',
      build: build,
      seed: () => _loaded.copyWith(unitSystem: UnitSystem.metric),
      act: (bloc) => bloc
        ..add(const ProfileInfoHeightChanged('175.26'))
        ..add(const ProfileInfoWeightChanged('70,44')),
      verify: (bloc) {
        final form = bloc.state as ProfileInfoForm;
        expect(form.heightCm, 175.3);
        expect(form.weightKg, 70.4);
        expect(form.errors, isEmpty);
      },
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'imperial entries are stored as metric',
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc
        ..add(const ProfileInfoHeightChanged('6', '2'))
        ..add(const ProfileInfoWeightChanged('200')),
      verify: (bloc) {
        final form = bloc.state as ProfileInfoForm;
        expect(form.heightCm, 188.0);
        expect(form.weightKg, 90.7);
      },
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'feet alone count as zero inches; inches alone are too short',
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc
        ..add(const ProfileInfoHeightChanged('6'))
        ..add(const ProfileInfoHeightChanged('', '11')),
      expect: () => [
        _loaded.copyWith(heightCm: 182.9),
        _loaded.copyWith(
          heightCm: 182.9,
          errors: {ProfileField.height: ProfileFieldError.outOfRange},
        ),
      ],
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'empty fields clear the value',
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc
        ..add(const ProfileInfoHeightChanged('', ' '))
        ..add(const ProfileInfoWeightChanged('  ')),
      verify: (bloc) {
        final form = bloc.state as ProfileInfoForm;
        expect(form.heightCm, isNull);
        expect(form.weightKg, isNull);
        expect(form.errors, isEmpty);
      },
    );

    for (final (name, event, field, error) in [
      (
        'text that is not a number',
        const ProfileInfoHeightChanged('1x', '2'),
        ProfileField.height,
        ProfileFieldError.invalid,
      ),
      (
        '12 or more inches',
        const ProfileInfoHeightChanged('5', '12'),
        ProfileField.height,
        ProfileFieldError.invalid,
      ),
      (
        'a height under 50 cm',
        const ProfileInfoHeightChanged('1', '7'),
        ProfileField.height,
        ProfileFieldError.outOfRange,
      ),
      (
        'a height over 272 cm',
        const ProfileInfoHeightChanged('9', '0'),
        ProfileField.height,
        ProfileFieldError.outOfRange,
      ),
      (
        'a weight under 20 kg',
        const ProfileInfoWeightChanged('40'),
        ProfileField.weight,
        ProfileFieldError.outOfRange,
      ),
      (
        'a weight that is not a number',
        const ProfileInfoWeightChanged('abc'),
        ProfileField.weight,
        ProfileFieldError.invalid,
      ),
    ]) {
      blocTest<ProfileInfoBloc, ProfileInfoState>(
        '$name is an error and keeps the stored value',
        build: build,
        seed: () => _loaded,
        act: (bloc) => bloc.add(event),
        expect: () => [
          _loaded.copyWith(errors: {field: error}),
        ],
      );
    }

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'switching units drops the errors of height and weight only',
      build: build,
      seed: () => _loaded.copyWith(
        errors: {
          ProfileField.height: ProfileFieldError.invalid,
          ProfileField.weight: ProfileFieldError.invalid,
          ProfileField.firstName: ProfileFieldError.tooLong,
        },
      ),
      act: (bloc) => bloc.add(const ProfileInfoUnitsChanged(UnitSystem.metric)),
      expect: () => [
        _loaded.copyWith(
          unitSystem: UnitSystem.metric,
          errors: {ProfileField.firstName: ProfileFieldError.tooLong},
        ),
      ],
    );
  });

  group('saving', () {
    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'saves the profile as loaded, metric values untouched',
      setUp: () => when(
        () => repository.saveProfile(any()),
      ).thenAnswer((_) async => sampleProfile),
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc.add(const ProfileInfoSaved()),
      expect: () => [
        _loaded.copyWith(status: ProfileInfoStatus.saving),
        _loaded.copyWith(status: ProfileInfoStatus.saved),
      ],
      verify: (_) =>
          verify(() => repository.saveProfile(sampleProfile)).called(1),
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'trims text and sends an empty one as null',
      setUp: () => when(
        () => repository.saveProfile(any()),
      ).thenAnswer((_) async => emptyProfile),
      build: build,
      seed: () => const ProfileInfoForm(firstName: '  Lan ', lastName: '   '),
      act: (bloc) => bloc.add(const ProfileInfoSaved()),
      verify: (_) => verify(
        () => repository.saveProfile(const Profile(firstName: 'Lan')),
      ).called(1),
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'a refused save keeps the form and says why',
      setUp: () => when(() => repository.saveProfile(any())).thenThrow(
        const ProfileFailure(
          ProfileFailureCode.validation,
          fieldErrors: {'country': 'Country must be a two-letter code.'},
        ),
      ),
      build: build,
      seed: () => _loaded,
      act: (bloc) => bloc.add(const ProfileInfoSaved()),
      expect: () => [
        _loaded.copyWith(status: ProfileInfoStatus.saving),
        _loaded.copyWith(
          saveFailure: const ProfileFailure(
            ProfileFailureCode.validation,
            fieldErrors: {'country': 'Country must be a two-letter code.'},
          ),
        ),
      ],
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'an edit after a failed save hides the banner',
      build: build,
      seed: () => _loaded.copyWith(
        saveFailure: const ProfileFailure(ProfileFailureCode.network),
      ),
      act: (bloc) => bloc.add(const ProfileInfoGenderChanged(Gender.female)),
      expect: () => [_loaded.copyWith(gender: Gender.female)],
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'does not save while a field has an error',
      build: build,
      seed: () => _loaded.copyWith(
        errors: {ProfileField.height: ProfileFieldError.outOfRange},
      ),
      act: (bloc) => bloc.add(const ProfileInfoSaved()),
      expect: () => <ProfileInfoState>[],
      verify: (_) => verifyNever(() => repository.saveProfile(any())),
    );

    blocTest<ProfileInfoBloc, ProfileInfoState>(
      'ignores a second save and edits while saving',
      build: build,
      seed: () => _loaded.copyWith(status: ProfileInfoStatus.saving),
      act: (bloc) => bloc
        ..add(const ProfileInfoSaved())
        ..add(const ProfileInfoCountryChanged('VN')),
      expect: () => <ProfileInfoState>[],
      verify: (_) => verifyNever(() => repository.saveProfile(any())),
    );
  });
}
