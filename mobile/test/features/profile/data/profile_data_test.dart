import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/profile/data/datasources/fake_profile_remote_data_source.dart';
import 'package:stridequest/features/profile/data/datasources/profile_fixtures.dart';
import 'package:stridequest/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:stridequest/features/profile/data/models/profile_model.dart';
import 'package:stridequest/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:stridequest/features/profile/domain/entities/profile.dart';
import 'package:stridequest/features/profile/domain/failures/profile_failure.dart';

import '../../../helpers/fake_http_adapter.dart';

DioProfileRemoteDataSource _source(
  FakeHttpHandler handler, [
  FakeHttpAdapter? adapter,
]) => DioProfileRemoteDataSource(
  createDio(
    baseUrl: 'http://api.test/',
    adapter: adapter ?? FakeHttpAdapter(handler),
  ),
);

Future<ProfileFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ProfileFailure catch (failure) {
    return failure;
  }
  fail('Expected a ProfileFailure');
}

class _MockRemote extends Mock implements ProfileRemoteDataSource {}

void main() {
  setUpAll(
    () => registerFallbackValue(const ProfileModel(unitSystem: 'metric')),
  );

  group('DioProfileRemoteDataSource', () {
    test('get reads users/me/profile', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody(profileFixture, 200);
      });

      final model = await source.get();

      expect(sent.method, 'GET');
      expect(sent.path, 'users/me/profile');
      expect(model.firstName, 'Max');
      expect(model.heightCm, 180.3);
    });

    test('put sends all nine keys, null included', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody(profileEmptyFixture, 200);
      });

      await source.put(ProfileModel.fromEntity(const Profile()));

      expect(sent.method, 'PUT');
      expect(sent.path, 'users/me/profile');
      expect(sent.data, profileEmptyFixture);
    });

    test('a 422 carries the field messages', () async {
      final source = _source(
        (_) async => jsonBody(errorValidationFixture, 422),
      );

      final failure = await _failureOf(
        source.put(ProfileModel.fromEntity(const Profile())),
      );

      expect(failure.code, ProfileFailureCode.validation);
      expect(failure.fieldErrors.keys, ['country', 'height_cm']);
      expect(failure.message, contains('two-letter code'));
    });

    test('a 401 with an unrefreshable token maps its code', () async {
      final source = _source(
        (_) async => jsonBody({
          'error': {'code': 'not_authenticated', 'message': 'x', 'fields': []},
        }, 401),
      );

      final failure = await _failureOf(source.get());

      expect(failure.code, ProfileFailureCode.notAuthenticated);
    });

    test('no response is a network failure', () async {
      final source = _source(
        (request) async => throw DioException.connectionError(
          requestOptions: request,
          reason: 'offline',
        ),
      );

      final failure = await _failureOf(source.get());

      expect(failure.code, ProfileFailureCode.network);
    });

    test('a body that is not a profile is an unknown failure', () async {
      final source = _source((_) async => jsonBody({'first_name': 3}, 200));

      final failure = await _failureOf(source.get());

      expect(failure.code, ProfileFailureCode.unknown);
    });

    test('a 500 without an error body is an unknown failure', () async {
      final source = _source((_) async => textBody('oops', 500));

      final failure = await _failureOf(source.get());

      expect(failure.code, ProfileFailureCode.unknown);
    });
  });

  group('FakeProfileRemoteDataSource', () {
    test('answers with profile.json until something is saved', () async {
      final fake = FakeProfileRemoteDataSource();

      final model = await fake.get();

      expect(model.toJson(), profileFixture);
    });

    test('keeps what put saved, in memory', () async {
      final fake = FakeProfileRemoteDataSource();
      const saved = ProfileModel(unitSystem: 'metric', firstName: 'Lan');

      expect(await fake.put(saved), saved);
      expect(await fake.get(), saved);
    });

    test('put checks the rules of the contract', () async {
      final fake = FakeProfileRemoteDataSource(
        now: () => DateTime.utc(2026, 10, 26),
      );
      const bad = ProfileModel(
        unitSystem: 'metric',
        firstName: '   ',
        birthday: '2026-10-27',
        country: 'usa',
        state: '',
        heightCm: 300,
        weightKg: 10,
      );

      final failure = await _failureOf(fake.put(bad));

      expect(failure.code, ProfileFailureCode.validation);
      expect(failure.fieldErrors.keys, [
        'first_name',
        'birthday',
        'country',
        'state',
        'height_cm',
        'weight_kg',
      ]);
      expect((await fake.get()).toJson(), profileFixture);
    });

    test('a birthday of 1900-01-01 is refused, the next day is fine', () async {
      final fake = FakeProfileRemoteDataSource();

      final failure = await _failureOf(
        fake.put(
          const ProfileModel(unitSystem: 'metric', birthday: '1900-01-01'),
        ),
      );
      final saved = await fake.put(
        const ProfileModel(unitSystem: 'metric', birthday: '1900-01-02'),
      );

      expect(failure.fieldErrors.keys, ['birthday']);
      expect(saved.birthday, '1900-01-02');
    });
  });

  group('ProfileRepositoryImpl', () {
    test('getProfile maps the model to the entity', () async {
      final repository = ProfileRepositoryImpl(FakeProfileRemoteDataSource());

      final profile = await repository.getProfile();

      expect(profile.birthday, DateTime.utc(1991, 6, 24));
      expect(profile.gender, Gender.male);
      expect(profile.unitSystem, UnitSystem.imperial);
    });

    test('saveProfile sends the model and returns what was saved', () async {
      final remote = _MockRemote();
      when(() => remote.put(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.first as ProfileModel,
      );
      final repository = ProfileRepositoryImpl(remote);
      final profile = Profile(
        firstName: 'Lan',
        birthday: DateTime.utc(1999, 1, 5),
        gender: Gender.nonBinary,
        heightCm: 170.5,
      );

      final saved = await repository.saveProfile(profile);

      expect(saved, profile);
      final sent =
          verify(() => remote.put(captureAny())).captured.single
              as ProfileModel;
      expect(sent.birthday, '1999-01-05');
      expect(sent.gender, 'non_binary');
      expect(sent.toJson().length, 9);
    });

    test('a failure of the data source reaches the caller', () async {
      final remote = _MockRemote();
      when(
        () => remote.get(),
      ).thenThrow(const ProfileFailure(ProfileFailureCode.network));

      final failure = await _failureOf(
        ProfileRepositoryImpl(remote).getProfile(),
      );

      expect(failure.code, ProfileFailureCode.network);
    });
  });
}
