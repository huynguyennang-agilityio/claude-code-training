import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/datasources/fake_auth_remote_data_source.dart';
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
  final dio = createDio(
    baseUrl: 'http://api.test/',
    adapter: FakeHttpAdapter(handler),
  );
  return DioAuthRemoteDataSource(dio, DioProvider(() => dio));
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

  test('change email sends change_email_request and reads user', () async {
    late RequestOptions sent;
    final dataSource = _dataSource((request) async {
      sent = request;
      return jsonBody(_example('user'), 200);
    });
    final request = _example('change_email_request');

    final user = await dataSource.changeEmail(
      newEmail: request['new_email'] as String,
      currentPassword: request['current_password'] as String,
    );

    expect(sent.method, 'PUT');
    expect(sentJson(sent), request);
    expect(user, AuthUserModel.fromJson(_example('user')));
  });

  test(
    'change password sends change_password_request and reads token_pair',
    () async {
      late RequestOptions sent;
      final dataSource = _dataSource((request) async {
        sent = request;
        return jsonBody(_example('token_pair'), 200);
      });
      final request = _example('change_password_request');

      final tokens = await dataSource.changePassword(
        currentPassword: request['current_password'] as String,
        newPassword: request['new_password'] as String,
      );

      expect(sent.method, 'PUT');
      expect(sent.uri.path, '/users/me/password');
      expect(sentJson(sent), request);
      expect(tokens, TokenPairModel.fromJson(_example('token_pair')));
    },
  );

  test('delete account sends delete_account_request and expects 204', () async {
    late RequestOptions sent;
    final dataSource = _dataSource((request) async {
      sent = request;
      return textBody('', 204);
    });
    final request = _example('delete_account_request');

    await dataSource.deleteAccount(
      currentPassword: request['current_password'] as String,
    );

    expect(sent.method, 'POST');
    expect(sent.uri.path, '/users/me/delete');
    expect(sentJson(sent), request);
  });

  test('delete account treats a 200 as a failure, not a deletion', () async {
    final dataSource = _dataSource((_) async => textBody('', 200));

    final failure = await _failureOf(
      dataSource.deleteAccount(currentPassword: 'run4medals'),
    );

    expect(failure.code, AuthFailureCode.unknown);
  });

  group('error examples map to failures', () {
    test('error_last_admin on the delete route', () async {
      final example = _example('error_last_admin');
      final dataSource = _dataSource((_) async => jsonBody(example, 409));

      final failure = await _failureOf(
        dataSource.deleteAccount(currentPassword: 'run4medals'),
      );

      expect(failure.code, AuthFailureCode.lastAdmin);
      expect(
        failure.message,
        (example['error'] as Map<String, dynamic>)['message'],
      );
    });

    test('error_incorrect_password on the delete route', () async {
      final dataSource = _dataSource(
        (_) async => jsonBody(_example('error_incorrect_password'), 403),
      );

      final failure = await _failureOf(
        dataSource.deleteAccount(currentPassword: 'wrong123'),
      );

      expect(failure.code, AuthFailureCode.incorrectPassword);
    });

    test('error_incorrect_password', () async {
      final example = _example('error_incorrect_password');
      final dataSource = _dataSource((_) async => jsonBody(example, 403));

      final failure = await _failureOf(
        dataSource.changeEmail(newEmail: 'a@b.co', currentPassword: 'x'),
      );

      expect(failure.code, AuthFailureCode.incorrectPassword);
      expect(
        failure.message,
        (example['error'] as Map<String, dynamic>)['message'],
      );
    });

    test('error_incorrect_password on the password route', () async {
      final example = _example('error_incorrect_password');
      final dataSource = _dataSource((_) async => jsonBody(example, 403));

      final failure = await _failureOf(
        dataSource.changePassword(
          currentPassword: 'x',
          newPassword: 'newrun5medals',
        ),
      );

      expect(failure.code, AuthFailureCode.incorrectPassword);
      expect(
        failure.message,
        (example['error'] as Map<String, dynamic>)['message'],
      );
    });

    test(
      'a validation_error naming new_password keeps the field message',
      () async {
        final dataSource = _dataSource(
          (_) async => jsonBody({
            'error': {
              'code': 'validation_error',
              'message': 'Request is invalid.',
              'fields': [
                {
                  'field': 'new_password',
                  'message':
                      'The new password must differ from the current one.',
                },
              ],
            },
          }, 422),
        );

        final failure = await _failureOf(
          dataSource.changePassword(
            currentPassword: 'run4medals',
            newPassword: 'run4medals',
          ),
        );

        expect(failure.code, AuthFailureCode.validation);
        expect(failure.fieldErrors, {
          'new_password': 'The new password must differ from the current one.',
        });
      },
    );

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

  group('the fake data source matches the examples', () {
    test(
      'change email accepts change_email_request and answers like user',
      () async {
        final fake = FakeAuthRemoteDataSource();
        final user = AuthUserModel.fromJson(_example('user'));
        final request = _example('change_email_request');
        await fake.signUp(
          email: user.email,
          password: request['current_password'] as String,
          displayName: user.displayName,
        );

        final changed = await fake.changeEmail(
          newEmail: request['new_email'] as String,
          currentPassword: request['current_password'] as String,
        );

        expect(changed.toJson().keys, user.toJson().keys);
        expect(changed.email, request['new_email']);
        expect(changed.displayName, user.displayName);
      },
    );

    test('change password accepts change_password_request and answers like '
        'token_pair', () async {
      final fake = FakeAuthRemoteDataSource();
      final pair = TokenPairModel.fromJson(_example('token_pair'));
      final request = _example('change_password_request');
      await fake.signUp(
        email: 'runner@example.com',
        password: request['current_password'] as String,
        displayName: 'Lan',
      );

      final changed = await fake.changePassword(
        currentPassword: request['current_password'] as String,
        newPassword: request['new_password'] as String,
      );

      expect(changed.toJson().keys, pair.toJson().keys);
      expect(changed.tokenType, pair.tokenType);
      expect(changed.expiresIn, pair.expiresIn);
    });

    test('delete account accepts delete_account_request', () async {
      final request = _example('delete_account_request');
      final fake = FakeAuthRemoteDataSource();
      await fake.signUp(
        email: 'runner@example.com',
        password: request['current_password'] as String,
        displayName: 'Lan',
      );

      await fake.deleteAccount(
        currentPassword: request['current_password'] as String,
      );

      // The account is gone: its password no longer signs in.
      final failure = await _failureOf(
        fake.signIn(
          email: 'runner@example.com',
          password: request['current_password'] as String,
        ),
      );
      expect(failure.code, AuthFailureCode.invalidCredentials);
    });

    test('a wrong password on delete is error_incorrect_password', () async {
      final fake = FakeAuthRemoteDataSource();
      final example = _example('error_incorrect_password')['error'] as Map;
      await fake.signUp(
        email: 'runner@example.com',
        password: 'run4medals',
        displayName: 'Lan',
      );

      final failure = await _failureOf(
        fake.deleteAccount(currentPassword: 'wrong123'),
      );

      expect(failure.code.wireCode, example['code']);
      expect(failure.message, example['message']);
    });

    test('the last admin gets error_last_admin', () async {
      final fake = FakeAuthRemoteDataSource(
        lastAdminEmails: {'runner@example.com'},
      );
      final example = _example('error_last_admin')['error'] as Map;
      await fake.signUp(
        email: 'runner@example.com',
        password: 'run4medals',
        displayName: 'Lan',
      );

      final failure = await _failureOf(
        fake.deleteAccount(currentPassword: 'run4medals'),
      );

      expect(failure.code.wireCode, example['code']);
      expect(failure.message, example['message']);
      expect(failure.fieldErrors, isEmpty);
    });

    test('a wrong current password is error_incorrect_password', () async {
      final fake = FakeAuthRemoteDataSource();
      final example = _example('error_incorrect_password')['error'] as Map;
      await fake.signUp(
        email: 'runner@example.com',
        password: 'run4medals',
        displayName: 'Lan',
      );

      final failure = await _failureOf(
        fake.changePassword(
          currentPassword: 'wrong123',
          newPassword: 'newrun5medals',
        ),
      );

      expect(failure.code.wireCode, example['code']);
      expect(failure.message, example['message']);
      expect(failure.fieldErrors, isEmpty);
    });

    test('a wrong password is error_incorrect_password', () async {
      final fake = FakeAuthRemoteDataSource();
      final example = _example('error_incorrect_password')['error'] as Map;
      await fake.signUp(
        email: 'runner@example.com',
        password: 'run4medals',
        displayName: 'Lan',
      );

      final failure = await _failureOf(
        fake.changeEmail(newEmail: 'a@b.co', currentPassword: 'wrong123'),
      );

      expect(failure.code.wireCode, example['code']);
      expect(failure.message, example['message']);
      expect(failure.fieldErrors, isEmpty);
    });
  });
}
