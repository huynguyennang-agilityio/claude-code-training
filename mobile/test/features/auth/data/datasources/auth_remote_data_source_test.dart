import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/network/auth_interceptor.dart';
import 'package:stridequest/core/network/auth_token_handler.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/core/network/network_simulation.dart';
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/models/auth_user_model.dart';
import 'package:stridequest/features/auth/data/models/token_pair_model.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';

import '../../../../helpers/fake_http_adapter.dart';

const _user = {
  'id': '6f1c2b3a-8d4e-4f5a-9b6c-7d8e9f0a1b2c',
  'email': 'runner@example.com',
  'display_name': 'Lan Runner',
  'created_at': '2026-10-13T09:55:00Z',
};
const _tokens = {
  'access_token': 'access-1',
  'refresh_token': 'refresh-1',
  'token_type': 'bearer',
  'expires_in': 900,
};

class _MockTokens extends Mock implements AuthTokenHandler {}

ResponseBody _json(Object body, int status, {Map<String, String>? headers}) {
  return jsonBody(body, status, headers: headers ?? const {});
}

ResponseBody _error(
  String code,
  int status, {
  List<Object>? fields,
  Map<String, String>? headers,
}) {
  return _json(
    {
      'error': {'code': code, 'message': 'ignored', 'fields': fields ?? []},
    },
    status,
    headers: headers,
  );
}

DioAuthRemoteDataSource _repository(
  FakeHttpHandler handler, {
  String baseUrl = 'http://api.test/',
  Duration timeout = const Duration(seconds: 15),
}) {
  final dio = createDio(baseUrl: baseUrl, adapter: FakeHttpAdapter(handler));
  return DioAuthRemoteDataSource(dio, DioProvider(() => dio), timeout: timeout);
}

Future<AuthFailure> _signInFailure(FakeHttpHandler handler) {
  return _failureOf(
    _repository(handler).signIn(email: 'a@b.co', password: 'abc12345'),
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
  group('signUp', () {
    test('posts the form and returns the session', () async {
      late RequestOptions sent;
      final repository = _repository((request) async {
        sent = request;
        return _json({'user': _user, 'tokens': _tokens}, 201);
      });

      final session = await repository.signUp(
        email: 'runner@example.com',
        password: 'run4medals',
        displayName: 'Lan Runner',
      );

      expect(sent.method, 'POST');
      expect(sent.uri.toString(), 'http://api.test/auth/signup');
      expect(sentJson(sent), {
        'email': 'runner@example.com',
        'password': 'run4medals',
        'display_name': 'Lan Runner',
      });
      expect(session.user.id, _user['id']);
      expect(session.user.displayName, 'Lan Runner');
      expect(session.user.createdAt, DateTime.utc(2026, 10, 13, 9, 55));
      expect(
        session.tokens,
        const TokenPairModel(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          expiresIn: Duration(seconds: 900),
        ),
      );
    });

    test('maps 409 email_taken', () async {
      final repository = _repository((_) async => _error('email_taken', 409));

      final failure = await _failureOf(
        repository.signUp(
          email: 'a@b.co',
          password: 'abc12345',
          displayName: 'A',
        ),
      );

      expect(failure.code, AuthFailureCode.emailTaken);
    });

    test('maps validation_error with its field messages', () async {
      final repository = _repository(
        (_) async => _error(
          'validation_error',
          422,
          fields: [
            {'field': 'password', 'message': 'Must contain a digit.'},
          ],
        ),
      );

      final failure = await _failureOf(
        repository.signUp(
          email: 'a@b.co',
          password: 'abcdefgh',
          displayName: 'A',
        ),
      );

      expect(failure.code, AuthFailureCode.validation);
      expect(failure.fieldErrors, {'password': 'Must contain a digit.'});
    });
  });

  group('signIn', () {
    test('returns the session', () async {
      final repository = _repository(
        (_) async => _json({'user': _user, 'tokens': _tokens}, 200),
      );

      final session = await repository.signIn(
        email: 'runner@example.com',
        password: 'run4medals',
      );

      expect(session.user.email, 'runner@example.com');
    });

    test('maps 401 invalid_credentials', () async {
      final repository = _repository(
        (_) async => _error('invalid_credentials', 401),
      );

      final failure = await _failureOf(
        repository.signIn(email: 'a@b.co', password: 'wrong123'),
      );

      expect(failure.code, AuthFailureCode.invalidCredentials);
      expect(failure.message, 'The email or password is incorrect.');
    });

    test('maps 429 rate_limited with its Retry-After seconds', () async {
      final failure = await _signInFailure(
        (_) async =>
            _error('rate_limited', 429, headers: {'retry-after': '120'}),
      );

      expect(failure.code, AuthFailureCode.rateLimited);
      expect(failure.retryAfter, const Duration(minutes: 2));
    });

    test('maps 429 without Retry-After to a null retryAfter', () async {
      final failure = await _signInFailure(
        (_) async => _error('rate_limited', 429),
      );

      expect(failure.retryAfter, isNull);
    });

    test('maps a 429 that is not an ErrorResponse to rate_limited', () async {
      final failure = await _signInFailure(
        (_) async =>
            textBody('Too Many Requests', 429, headers: {'retry-after': '30'}),
      );

      expect(failure.code, AuthFailureCode.rateLimited);
      expect(failure.retryAfter, const Duration(seconds: 30));
    });

    test('maps a 5xx ErrorResponse by its code', () async {
      final failure = await _signInFailure(
        (_) async => _error('internal_error', 500),
      );

      expect(failure.code, AuthFailureCode.unknown);
    });

    for (final (code, expected) in [
      ('not_authenticated', AuthFailureCode.notAuthenticated),
      ('invalid_token', AuthFailureCode.invalidToken),
      ('token_expired', AuthFailureCode.tokenExpired),
    ]) {
      test('maps 401 $code', () async {
        final failure = await _signInFailure((_) async => _error(code, 401));

        expect(failure.code, expected);
      });
    }

    test('maps a timeout to network', () async {
      final repository = _repository(
        (_) => Completer<ResponseBody>().future,
        timeout: const Duration(milliseconds: 10),
      );

      final failure = await _failureOf(
        repository.signIn(email: 'a@b.co', password: 'abc12345'),
      );

      expect(failure.code, AuthFailureCode.network);
    });

    test('maps a TLS handshake error to network', () async {
      final failure = await _signInFailure(
        (_) async => throw const HandshakeException('bad certificate'),
      );

      expect(failure.code, AuthFailureCode.network);
    });

    test('maps a success body with an unsupported token_type to unknown', () {
      return expectLater(
        _signInFailure(
          (_) async => _json({
            'user': _user,
            'tokens': {..._tokens, 'token_type': 'mac'},
          }, 200),
        ).then((failure) => failure.code),
        completion(AuthFailureCode.unknown),
      );
    });

    test('maps a connection error to network', () async {
      final repository = _repository(
        (_) async => throw const SocketException('connection refused'),
      );

      final failure = await _failureOf(
        repository.signIn(email: 'a@b.co', password: 'abc12345'),
      );

      expect(failure.code, AuthFailureCode.network);
    });

    test('maps a body that is not an ErrorResponse to unknown', () async {
      final repository = _repository(
        (_) async => textBody('<html>Bad gateway</html>', 502),
      );

      final failure = await _failureOf(
        repository.signIn(email: 'a@b.co', password: 'abc12345'),
      );

      expect(failure.code, AuthFailureCode.unknown);
    });

    test('maps a success body without tokens to unknown', () async {
      final repository = _repository((_) async => _json({'user': _user}, 200));

      final failure = await _failureOf(
        repository.signIn(email: 'a@b.co', password: 'abc12345'),
      );

      expect(failure.code, AuthFailureCode.unknown);
    });

    test('maps an empty success body to unknown', () async {
      final repository = _repository((_) async => textBody('', 200));

      final failure = await _failureOf(
        repository.signIn(email: 'a@b.co', password: 'abc12345'),
      );

      expect(failure.code, AuthFailureCode.unknown);
    });

    test('maps an unknown error code to unknown', () async {
      final repository = _repository((_) async => _error('brand_new', 400));

      final failure = await _failureOf(
        repository.signIn(email: 'a@b.co', password: 'abc12345'),
      );

      expect(failure.code, AuthFailureCode.unknown);
    });
  });

  test(
    'keeps the path prefix of a base URL without a trailing slash',
    () async {
      late RequestOptions sent;
      final repository = _repository((request) async {
        sent = request;
        return _json({'user': _user, 'tokens': _tokens}, 200);
      }, baseUrl: 'https://example.com/api');

      await repository.signIn(email: 'a@b.co', password: 'abc12345');

      expect(sent.uri.toString(), 'https://example.com/api/auth/signin');
    },
  );

  test('keeps the path prefix of the base URL', () async {
    late RequestOptions sent;
    final repository = _repository((request) async {
      sent = request;
      return _json({'user': _user, 'tokens': _tokens}, 200);
    }, baseUrl: 'https://example.com/api/');

    await repository.signIn(email: 'a@b.co', password: 'abc12345');

    expect(sent.uri.toString(), 'https://example.com/api/auth/signin');
  });

  group('refresh', () {
    test('sends the refresh token and returns the new pair', () async {
      late RequestOptions sent;
      final repository = _repository((request) async {
        sent = request;
        return _json({
          ..._tokens,
          'access_token': 'access-2',
          'refresh_token': 'refresh-2',
        }, 200);
      });

      final tokens = await repository.refresh('refresh-1');

      expect(sent.uri.path, '/auth/refresh');
      expect(sentJson(sent), {'refresh_token': 'refresh-1'});
      expect(
        tokens,
        const TokenPairModel(
          accessToken: 'access-2',
          refreshToken: 'refresh-2',
          expiresIn: Duration(seconds: 900),
        ),
      );
    });

    test('maps 401 invalid_refresh_token', () async {
      final repository = _repository(
        (_) async => _error('invalid_refresh_token', 401),
      );

      final failure = await _failureOf(repository.refresh('revoked'));

      expect(failure.code, AuthFailureCode.invalidRefreshToken);
    });

    test('maps 422 validation_error', () async {
      final repository = _repository(
        (_) async => _error(
          'validation_error',
          422,
          fields: [
            {'field': 'refresh_token', 'message': 'Field required.'},
          ],
        ),
      );

      final failure = await _failureOf(repository.refresh(''));

      expect(failure.code, AuthFailureCode.validation);
      expect(failure.fieldErrors.keys, ['refresh_token']);
    });
  });

  group('signOut', () {
    test('accepts 204 with an empty body', () async {
      late RequestOptions sent;
      final repository = _repository((request) async {
        sent = request;
        return textBody('', 204);
      });

      await repository.signOut('refresh-1');

      expect(sent.uri.path, '/auth/signout');
      expect(sentJson(sent), {'refresh_token': 'refresh-1'});
    });

    test('maps 422 validation_error', () async {
      final repository = _repository(
        (_) async => _error('validation_error', 422),
      );

      final failure = await _failureOf(repository.signOut(''));

      expect(failure.code, AuthFailureCode.validation);
    });
  });

  group('simulated network faults', () {
    DioAuthRemoteDataSource simulated(SimulatedFault fault) {
      final adapter = FakeHttpAdapter(
        (_) async => _json({'user': _user, 'tokens': _tokens}, 200),
      );
      final dio = createDio(
        baseUrl: 'http://api.test/',
        adapter: adapter,
        interceptors: [
          NetworkSimulationInterceptor(NetworkSimulation(fault: fault)),
        ],
      );
      return DioAuthRemoteDataSource(dio, DioProvider(() => dio));
    }

    for (final fault in [SimulatedFault.offline, SimulatedFault.timeout]) {
      test('$fault becomes AuthFailureCode.network', () async {
        final failure = await _failureOf(
          simulated(fault).signIn(email: 'a@b.co', password: 'abc12345'),
        );

        expect(failure.code, AuthFailureCode.network);
      });
    }
  });

  group('changeEmail', () {
    test('puts the new email and password and reads the user', () async {
      late RequestOptions sent;
      final repository = _repository((request) async {
        sent = request;
        return _json(_user, 200);
      });

      final user = await repository.changeEmail(
        newEmail: 'new.runner@example.com',
        currentPassword: 'run4medals',
      );

      expect(sent.method, 'PUT');
      expect(sent.uri.path, '/users/me/email');
      expect(sentJson(sent), {
        'new_email': 'new.runner@example.com',
        'current_password': 'run4medals',
      });
      expect(user, AuthUserModel.fromJson(_user));
    });

    for (final (status, code, expected) in [
      (403, 'incorrect_password', AuthFailureCode.incorrectPassword),
      (409, 'email_taken', AuthFailureCode.emailTaken),
      (422, 'validation_error', AuthFailureCode.validation),
      (429, 'rate_limited', AuthFailureCode.rateLimited),
      (401, 'not_authenticated', AuthFailureCode.notAuthenticated),
    ]) {
      test('maps $status $code', () async {
        final failure = await _failureOf(
          _repository(
            (_) async => _error(code, status, headers: {'retry-after': '90'}),
          ).changeEmail(newEmail: 'a@b.co', currentPassword: 'p'),
        );

        expect(failure.code, expected);
      });
    }

    test('keeps Retry-After and the field messages', () async {
      final limited = await _failureOf(
        _repository(
          (_) async =>
              _error('rate_limited', 429, headers: {'retry-after': '90'}),
        ).changeEmail(newEmail: 'a@b.co', currentPassword: 'p'),
      );
      final invalid = await _failureOf(
        _repository(
          (_) async => _error(
            'validation_error',
            422,
            fields: [
              {'field': 'new_email', 'message': 'Must differ.'},
            ],
          ),
        ).changeEmail(newEmail: 'a@b.co', currentPassword: 'p'),
      );

      expect(limited.retryAfter, const Duration(seconds: 90));
      expect(invalid.fieldErrors, {'new_email': 'Must differ.'});
    });

    test('an unreadable success body is unknown', () async {
      final failure = await _failureOf(
        _repository(
          (_) async => textBody('<html>', 200),
        ).changeEmail(newEmail: 'a@b.co', currentPassword: 'p'),
      );

      expect(failure.code, AuthFailureCode.unknown);
    });

    test('a refused connection is network', () async {
      final failure = await _failureOf(
        _repository(
          (_) async => throw const SocketException('refused'),
        ).changeEmail(newEmail: 'a@b.co', currentPassword: 'p'),
      );

      expect(failure.code, AuthFailureCode.network);
    });
  });

  group('changePassword', () {
    test('puts both passwords and reads the new token pair', () async {
      late RequestOptions sent;
      final repository = _repository((request) async {
        sent = request;
        return _json(_tokens, 200);
      });

      final tokens = await repository.changePassword(
        currentPassword: 'run4medals',
        newPassword: 'newrun5medals',
      );

      expect(sent.method, 'PUT');
      expect(sent.uri.path, '/users/me/password');
      expect(sentJson(sent), {
        'current_password': 'run4medals',
        'new_password': 'newrun5medals',
      });
      expect(tokens, TokenPairModel.fromJson(_tokens));
    });

    for (final (status, code, expected) in [
      (403, 'incorrect_password', AuthFailureCode.incorrectPassword),
      (422, 'validation_error', AuthFailureCode.validation),
      (429, 'rate_limited', AuthFailureCode.rateLimited),
      (401, 'not_authenticated', AuthFailureCode.notAuthenticated),
    ]) {
      test('maps $status $code', () async {
        final failure = await _failureOf(
          _repository(
            (_) async => _error(code, status, headers: {'retry-after': '90'}),
          ).changePassword(currentPassword: 'p', newPassword: 'q'),
        );

        expect(failure.code, expected);
      });
    }

    test('keeps Retry-After and the field messages', () async {
      final limited = await _failureOf(
        _repository(
          (_) async =>
              _error('rate_limited', 429, headers: {'retry-after': '90'}),
        ).changePassword(currentPassword: 'p', newPassword: 'q'),
      );
      final invalid = await _failureOf(
        _repository(
          (_) async => _error(
            'validation_error',
            422,
            fields: [
              {'field': 'new_password', 'message': 'Must differ.'},
            ],
          ),
        ).changePassword(currentPassword: 'p', newPassword: 'q'),
      );

      expect(limited.retryAfter, const Duration(seconds: 90));
      expect(invalid.fieldErrors, {'new_password': 'Must differ.'});
    });

    test('an unreadable success body is unknown', () async {
      final failure = await _failureOf(
        _repository(
          (_) async => textBody('<html>', 200),
        ).changePassword(currentPassword: 'p', newPassword: 'q'),
      );

      expect(failure.code, AuthFailureCode.unknown);
    });

    test('a refused connection is network', () async {
      final failure = await _failureOf(
        _repository(
          (_) async => throw const SocketException('refused'),
        ).changePassword(currentPassword: 'p', newPassword: 'q'),
      );

      expect(failure.code, AuthFailureCode.network);
    });
  });

  group('deleteAccount', () {
    test('posts the password and accepts 204 with no body', () async {
      late RequestOptions sent;
      final repository = _repository((request) async {
        sent = request;
        return textBody('', 204);
      });

      await repository.deleteAccount(currentPassword: 'run4medals');

      expect(sent.method, 'POST');
      expect(sent.uri.path, '/users/me/delete');
      expect(sentJson(sent), {'current_password': 'run4medals'});
    });

    for (final (status, code, expected) in [
      (401, 'not_authenticated', AuthFailureCode.notAuthenticated),
      (401, 'invalid_token', AuthFailureCode.invalidToken),
      (401, 'token_expired', AuthFailureCode.tokenExpired),
      (403, 'incorrect_password', AuthFailureCode.incorrectPassword),
      (409, 'last_admin', AuthFailureCode.lastAdmin),
      (422, 'validation_error', AuthFailureCode.validation),
      (429, 'rate_limited', AuthFailureCode.rateLimited),
    ]) {
      test('maps $status $code', () async {
        final failure = await _failureOf(
          _repository(
            (_) async => _error(code, status, headers: {'retry-after': '90'}),
          ).deleteAccount(currentPassword: 'p'),
        );

        expect(failure.code, expected);
      });
    }

    test('keeps Retry-After and the field messages', () async {
      final limited = await _failureOf(
        _repository(
          (_) async =>
              _error('rate_limited', 429, headers: {'retry-after': '90'}),
        ).deleteAccount(currentPassword: 'p'),
      );
      final invalid = await _failureOf(
        _repository(
          (_) async => _error(
            'validation_error',
            422,
            fields: [
              {'field': 'current_password', 'message': 'Enter your password.'},
            ],
          ),
        ).deleteAccount(currentPassword: ''),
      );

      expect(limited.retryAfter, const Duration(seconds: 90));
      expect(invalid.fieldErrors, {'current_password': 'Enter your password.'});
    });

    test('a refused connection is network', () async {
      final failure = await _failureOf(
        _repository(
          (_) async => throw const SocketException('refused'),
        ).deleteAccount(currentPassword: 'p'),
      );

      expect(failure.code, AuthFailureCode.network);
    });

    test('a timeout is network', () async {
      final failure = await _failureOf(
        _repository(
          (_) => Completer<ResponseBody>().future,
          timeout: const Duration(milliseconds: 10),
        ).deleteAccount(currentPassword: 'p'),
      );

      expect(failure.code, AuthFailureCode.network);
    });
  });

  group('changeEmail behind the auth interceptor', () {
    late _MockTokens tokens;
    late FakeHttpAdapter adapter;
    var accessToken = 'access-1';

    DioAuthRemoteDataSource build(FakeHttpHandler handler) {
      adapter = FakeHttpAdapter(handler);
      final authenticated = createDio(
        baseUrl: 'http://api.test/',
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
      // The public Dio must never be used for this call.
      final public = createDio(
        baseUrl: 'http://public.test/',
        adapter: FakeHttpAdapter((_) async => fail('used the public Dio')),
      );
      return DioAuthRemoteDataSource(public, DioProvider(() => authenticated));
    }

    setUp(() {
      accessToken = 'access-1';
      tokens = _MockTokens();
      when(() => tokens.accessToken()).thenAnswer((_) async => accessToken);
      when(() => tokens.expireSession()).thenAnswer((_) async {});
    });

    test('sends the bearer token', () async {
      final source = build((_) async => _json(_user, 200));

      await source.changeEmail(newEmail: 'a@b.co', currentPassword: 'p');

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test('a token_expired 401 refreshes once and the retry succeeds', () async {
      when(() => tokens.refreshTokens()).thenAnswer((_) async {
        accessToken = 'access-2';
        return TokenRefreshResult.refreshed;
      });
      final source = build(
        (request) async => request.headers['Authorization'] == 'Bearer access-1'
            ? _error('token_expired', 401)
            : _json(_user, 200),
      );

      final user = await source.changeEmail(
        newEmail: 'a@b.co',
        currentPassword: 'p',
      );

      expect(user, AuthUserModel.fromJson(_user));
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.headers['Authorization'], 'Bearer access-2');
      verify(() => tokens.refreshTokens()).called(1);
      verifyNever(() => tokens.expireSession());
    });

    test('a 403 incorrect_password is not refreshed or retried', () async {
      final source = build((_) async => _error('incorrect_password', 403));

      final failure = await _failureOf(
        source.changeEmail(newEmail: 'a@b.co', currentPassword: 'p'),
      );

      expect(failure.code, AuthFailureCode.incorrectPassword);
      expect(adapter.requests, hasLength(1));
      verifyNever(() => tokens.refreshTokens());
    });

    test('changePassword: a token_expired 401 refreshes and retries', () async {
      when(() => tokens.refreshTokens()).thenAnswer((_) async {
        accessToken = 'access-2';
        return TokenRefreshResult.refreshed;
      });
      final source = build(
        (request) async => request.headers['Authorization'] == 'Bearer access-1'
            ? _error('token_expired', 401)
            : _json(_tokens, 200),
      );

      final pair = await source.changePassword(
        currentPassword: 'p',
        newPassword: 'q',
      );

      expect(pair, TokenPairModel.fromJson(_tokens));
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.headers['Authorization'], 'Bearer access-2');
      verify(() => tokens.refreshTokens()).called(1);
      verifyNever(() => tokens.expireSession());
    });

    test('deleteAccount: sends the bearer token', () async {
      final source = build((_) async => textBody('', 204));

      await source.deleteAccount(currentPassword: 'p');

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test(
      'deleteAccount: a token_expired 401 refreshes once and retries',
      () async {
        when(() => tokens.refreshTokens()).thenAnswer((_) async {
          accessToken = 'access-2';
          return TokenRefreshResult.refreshed;
        });
        final source = build(
          (request) async =>
              request.headers['Authorization'] == 'Bearer access-1'
              ? _error('token_expired', 401)
              : textBody('', 204),
        );

        await source.deleteAccount(currentPassword: 'p');

        expect(adapter.requests, hasLength(2));
        expect(
          adapter.requests.last.headers['Authorization'],
          'Bearer access-2',
        );
        verify(() => tokens.refreshTokens()).called(1);
        verifyNever(() => tokens.expireSession());
      },
    );

    test('deleteAccount: an invalid_token 401 with a rejected refresh ends the '
        'session', () async {
      when(
        () => tokens.refreshTokens(),
      ).thenAnswer((_) async => TokenRefreshResult.rejected);
      final source = build((_) async => _error('invalid_token', 401));

      final failure = await _failureOf(
        source.deleteAccount(currentPassword: 'p'),
      );

      expect(failure.code, AuthFailureCode.invalidToken);
      expect(adapter.requests, hasLength(1));
      verify(() => tokens.refreshTokens()).called(1);
      verify(() => tokens.expireSession()).called(1);
    });

    test('deleteAccount: a 403 is not refreshed or retried', () async {
      final source = build((_) async => _error('incorrect_password', 403));

      final failure = await _failureOf(
        source.deleteAccount(currentPassword: 'p'),
      );

      expect(failure.code, AuthFailureCode.incorrectPassword);
      expect(adapter.requests, hasLength(1));
      verifyNever(() => tokens.refreshTokens());
    });

    test('changePassword: a 403 is not refreshed or retried', () async {
      final source = build((_) async => _error('incorrect_password', 403));

      final failure = await _failureOf(
        source.changePassword(currentPassword: 'p', newPassword: 'q'),
      );

      expect(failure.code, AuthFailureCode.incorrectPassword);
      expect(adapter.requests, hasLength(1));
      verifyNever(() => tokens.refreshTokens());
    });
  });
}
