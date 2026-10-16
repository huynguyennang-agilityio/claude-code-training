import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart';
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
  return DioAuthRemoteDataSource(
    createDio(baseUrl: baseUrl, adapter: FakeHttpAdapter(handler)),
    timeout: timeout,
  );
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
}
