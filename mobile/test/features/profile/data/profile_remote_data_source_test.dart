import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/network/auth_interceptor.dart';
import 'package:stridequest/core/network/auth_token_handler.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/profile/data/datasources/profile_fixtures.dart';
import 'package:stridequest/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:stridequest/features/profile/data/models/profile_model.dart';
import 'package:stridequest/features/profile/domain/entities/profile.dart';
import 'package:stridequest/features/profile/domain/failures/profile_failure.dart';

import '../../../helpers/fake_http_adapter.dart';

DioProfileRemoteDataSource _source(
  FakeHttpHandler handler, {
  Duration timeout = const Duration(seconds: 15),
  List<Interceptor> interceptors = const [],
  FakeHttpAdapter? adapter,
}) => DioProfileRemoteDataSource(
  createDio(
    baseUrl: 'http://api.test/',
    adapter: adapter ?? FakeHttpAdapter(handler),
    interceptors: interceptors,
  ),
  timeout: timeout,
);

Future<ProfileFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ProfileFailure catch (failure) {
    return failure;
  }
  fail('Expected a ProfileFailure');
}

ResponseBody _error(String code, int status) => jsonBody({
  'error': {'code': code, 'message': 'ignored', 'fields': <Object>[]},
}, status);

class _MockTokens extends Mock implements AuthTokenHandler {}

class _TransportError implements Exception {
  const _TransportError();
}

void main() {
  group('requests and bodies', () {
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

    test('a body that is not a profile is an unknown failure', () async {
      final source = _source((_) async => jsonBody({'first_name': 3}, 200));

      expect((await _failureOf(source.get())).code, ProfileFailureCode.unknown);
    });

    test('a 500 without an error body is an unknown failure', () async {
      final source = _source((_) async => textBody('oops', 500));

      expect((await _failureOf(source.get())).code, ProfileFailureCode.unknown);
    });
  });

  group('the wire format', () {
    test('a whole number is read as a double', () async {
      final source = _source(
        (_) async => jsonBody({
          ...profileFixture,
          'height_cm': 180,
          'weight_kg': 84,
        }, 200),
      );

      final model = await source.get();

      expect(model.heightCm, 180.0);
      expect(model.weightKg, 84.0);
    });

    test('put sends the numbers as numbers and the dates as text', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody(profileFixture, 200);
      });

      await source.put(ProfileModel.fromJson(profileFixture));

      final body = sent.data as Map<String, dynamic>;
      expect(body, profileFixture);
      expect(body['height_cm'], isA<double>());
      expect(body['birthday'], isA<String>());
    });
  });

  group('422 validation_error', () {
    test('each field message is kept under its API field name', () async {
      final source = _source(
        (_) async => jsonBody(errorValidationFixture, 422),
      );

      final failure = await _failureOf(
        source.put(ProfileModel.fromJson(profileFixture)),
      );

      expect(failure.code, ProfileFailureCode.validation);
      expect(failure.fieldErrors, {
        'country': 'Country must be a two-letter code in capitals.',
        'height_cm': 'Height must be between 50.0 and 272.0 cm.',
      });
    });

    test('an entry that is not a field message is skipped', () async {
      final source = _source(
        (_) async => jsonBody({
          'error': {
            'code': 'validation_error',
            'message': 'x',
            'fields': [
              {'field': 'state', 'message': 'State is 1 to 100 characters.'},
              {'field': 'country'},
              'oops',
            ],
          },
        }, 422),
      );

      final failure = await _failureOf(
        source.put(ProfileModel.fromJson(profileFixture)),
      );

      expect(failure.fieldErrors, {'state': 'State is 1 to 100 characters.'});
    });

    test('without fields it still is a validation failure', () async {
      final source = _source((_) async => _error('validation_error', 422));

      final failure = await _failureOf(
        source.put(ProfileModel.fromJson(profileFixture)),
      );

      expect(failure.code, ProfileFailureCode.validation);
      expect(failure.fieldErrors, isEmpty);
      expect(failure.message, ProfileFailureCode.validation.defaultMessage);
    });
  });

  group('errors', () {
    for (final (code, expected) in [
      ('not_authenticated', ProfileFailureCode.notAuthenticated),
      ('invalid_token', ProfileFailureCode.invalidToken),
      ('token_expired', ProfileFailureCode.tokenExpired),
    ]) {
      test('a 401 $code maps to its failure, on get and put', () async {
        final source = _source((_) async => _error(code, 401));

        expect((await _failureOf(source.get())).code, expected);
        expect(
          (await _failureOf(
            source.put(ProfileModel.fromJson(profileFixture)),
          )).code,
          expected,
        );
      });
    }

    test('an unknown code is an unknown failure', () async {
      final source = _source((_) async => _error('mystery', 500));

      expect((await _failureOf(source.get())).code, ProfileFailureCode.unknown);
    });

    test('a transport error is a network failure', () async {
      final source = _source((_) => throw const _TransportError());

      expect((await _failureOf(source.get())).code, ProfileFailureCode.network);
    });

    test('a slow server is a network failure', () async {
      final source = _source(
        (_) => Completer<ResponseBody>().future,
        timeout: const Duration(milliseconds: 10),
      );

      expect((await _failureOf(source.get())).code, ProfileFailureCode.network);
    });
  });

  group('behind the auth interceptor', () {
    late _MockTokens tokens;
    late FakeHttpAdapter adapter;
    var accessToken = 'access-1';

    DioProfileRemoteDataSource build(FakeHttpHandler handler) {
      adapter = FakeHttpAdapter(handler);
      return _source(
        handler,
        adapter: adapter,
        interceptors: [
          AuthInterceptor(
            tokens: tokens,
            retryClient: createDio(
              baseUrl: 'http://api.test/',
              adapter: adapter,
            ),
          ),
        ],
      );
    }

    setUp(() {
      accessToken = 'access-1';
      tokens = _MockTokens();
      when(() => tokens.accessToken()).thenAnswer((_) async => accessToken);
      when(() => tokens.expireSession()).thenAnswer((_) async {});
    });

    test('an expired access token is refreshed and put retried', () async {
      when(() => tokens.refreshTokens()).thenAnswer((_) async {
        accessToken = 'access-2';
        return TokenRefreshResult.refreshed;
      });
      final source = build(
        (request) async => request.headers['Authorization'] == 'Bearer access-1'
            ? _error('token_expired', 401)
            : jsonBody(profileFixture, 200),
      );

      final model = await source.put(ProfileModel.fromJson(profileFixture));

      expect(model.firstName, 'Max');
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.data, profileFixture);
      verifyNever(() => tokens.expireSession());
    });

    test('a rejected refresh token ends the session', () async {
      when(
        () => tokens.refreshTokens(),
      ).thenAnswer((_) async => TokenRefreshResult.rejected);
      final source = build((_) async => _error('invalid_token', 401));

      expect(
        (await _failureOf(source.get())).code,
        ProfileFailureCode.invalidToken,
      );
      verify(() => tokens.expireSession()).called(1);
    });
  });
}
