import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/models/auth_session_model.dart';
import 'package:stridequest/features/auth/data/models/auth_user_model.dart';
import 'package:stridequest/features/auth/data/models/token_pair_model.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';

import '../helpers/fake_http_adapter.dart';

/// The shared examples of `docs/api/auth.md`. The backend tests compare their
/// responses with the same files, so a field that drifts on either side fails.
const _examplesDir = '../docs/api/examples/auth';

Map<String, dynamic> _example(String name) {
  final file = File('$_examplesDir/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

DioAuthRemoteDataSource _dataSource(FakeHttpHandler handler) {
  return DioAuthRemoteDataSource(
    createDio(baseUrl: 'http://api.test/', adapter: FakeHttpAdapter(handler)),
  );
}

Future<AuthFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on AuthFailure catch (failure) {
    return failure;
  }
  fail('Expected an AuthFailure');
}

void main() {
  test('the examples directory is found from the mobile folder', () {
    expect(Directory(_examplesDir).existsSync(), isTrue);
  });

  group('success examples parse into the models', () {
    test('token_pair', () {
      final tokens = TokenPairModel.fromJson(_example('token_pair'));

      expect(tokens.accessToken, startsWith('eyJ'));
      expect(tokens.refreshToken, startsWith('kq3Vh'));
      expect(tokens.tokenType, 'bearer');
      expect(tokens.expiresIn, const Duration(seconds: 900));
    });

    test('user', () {
      final user = AuthUserModel.fromJson(_example('user'));

      expect(user.id, '6f1c2b3a-8d4e-4f5a-9b6c-7d8e9f0a1b2c');
      expect(user.email, 'runner@example.com');
      expect(user.displayName, 'Lan Runner');
      expect(user.createdAt, DateTime.utc(2026, 10, 13, 9, 55));
    });

    test('auth_response', () {
      final session = AuthSessionModel.fromJson(_example('auth_response'));

      expect(session.user, AuthUserModel.fromJson(_example('user')));
      expect(session.tokens, TokenPairModel.fromJson(_example('token_pair')));
    });
  });

  group('the data source against the examples', () {
    test('sign up sends signup_request and reads auth_response', () async {
      late RequestOptions sent;
      final dataSource = _dataSource((request) async {
        sent = request;
        return jsonBody(_example('auth_response'), 201);
      });
      final request = _example('signup_request');

      final session = await dataSource.signUp(
        email: request['email'] as String,
        password: request['password'] as String,
        displayName: request['display_name'] as String,
      );

      expect(sentJson(sent), request);
      expect(session, AuthSessionModel.fromJson(_example('auth_response')));
    });

    test('sign in sends signin_request and reads auth_response', () async {
      late RequestOptions sent;
      final dataSource = _dataSource((request) async {
        sent = request;
        return jsonBody(_example('auth_response'), 200);
      });
      final request = _example('signin_request');

      final session = await dataSource.signIn(
        email: request['email'] as String,
        password: request['password'] as String,
      );

      expect(sentJson(sent), request);
      expect(session.tokens.expiresIn, const Duration(seconds: 900));
    });

    test('refresh sends refresh_token_request and reads token_pair', () async {
      late RequestOptions sent;
      final dataSource = _dataSource((request) async {
        sent = request;
        return jsonBody(_example('token_pair'), 200);
      });
      final request = _example('refresh_token_request');

      final tokens = await dataSource.refresh(
        request['refresh_token'] as String,
      );

      expect(sentJson(sent), request);
      expect(tokens, TokenPairModel.fromJson(_example('token_pair')));
    });

    test('sign out sends refresh_token_request', () async {
      late RequestOptions sent;
      final dataSource = _dataSource((request) async {
        sent = request;
        return textBody('', 204);
      });
      final request = _example('refresh_token_request');

      await dataSource.signOut(request['refresh_token'] as String);

      expect(sentJson(sent), request);
    });
  });

  group('error examples map to failures', () {
    test('error_invalid_credentials', () async {
      final dataSource = _dataSource(
        (_) async => jsonBody(_example('error_invalid_credentials'), 401),
      );

      final failure = await _failureOf(
        dataSource.signIn(email: 'a@b.co', password: 'abc12345'),
      );

      expect(failure.code, AuthFailureCode.invalidCredentials);
      expect(failure.fieldErrors, isEmpty);
    });

    test('error_validation keeps the field message', () async {
      final dataSource = _dataSource(
        (_) async => jsonBody(_example('error_validation'), 422),
      );

      final failure = await _failureOf(
        dataSource.signUp(
          email: 'a@b.co',
          password: 'abcdefgh',
          displayName: 'A',
        ),
      );

      expect(failure.code, AuthFailureCode.validation);
      expect(failure.fieldErrors, {
        'password': 'Password must contain at least one digit.',
      });
    });
  });
}
