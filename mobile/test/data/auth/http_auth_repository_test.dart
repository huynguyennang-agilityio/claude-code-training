import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stridequest/data/auth/auth_failure.dart';
import 'package:stridequest/data/auth/auth_models.dart';
import 'package:stridequest/data/auth/http_auth_repository.dart';

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

http.Response _json(Object body, int status, {Map<String, String>? headers}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json', ...?headers},
  );
}

http.Response _error(
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

HttpAuthRepository _repository(
  MockClientHandler handler, {
  String baseUrl = 'http://api.test/',
  Duration timeout = const Duration(seconds: 15),
}) {
  return HttpAuthRepository(
    baseUrl: Uri.parse(baseUrl),
    client: MockClient(handler),
    timeout: timeout,
  );
}

Future<AuthFailure> _signInFailure(MockClientHandler handler) {
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
      late http.Request sent;
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
      expect(sent.url.toString(), 'http://api.test/auth/signup');
      expect(jsonDecode(sent.body), {
        'email': 'runner@example.com',
        'password': 'run4medals',
        'display_name': 'Lan Runner',
      });
      expect(session.user.id, _user['id']);
      expect(session.user.displayName, 'Lan Runner');
      expect(session.user.createdAt, DateTime.utc(2026, 10, 13, 9, 55));
      expect(
        session.tokens,
        const AuthTokens(
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
        (_) async => http.Response(
          'Too Many Requests',
          429,
          headers: {'retry-after': '30'},
        ),
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
        (_) => Completer<http.Response>().future,
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
        (_) async => throw http.ClientException('connection refused'),
      );

      final failure = await _failureOf(
        repository.signIn(email: 'a@b.co', password: 'abc12345'),
      );

      expect(failure.code, AuthFailureCode.network);
    });

    test('maps a body that is not an ErrorResponse to unknown', () async {
      final repository = _repository(
        (_) async => http.Response('<html>Bad gateway</html>', 502),
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
      final repository = _repository((_) async => http.Response('', 200));

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
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json({'user': _user, 'tokens': _tokens}, 200);
      }, baseUrl: 'https://example.com/api');

      await repository.signIn(email: 'a@b.co', password: 'abc12345');

      expect(sent.url.toString(), 'https://example.com/api/auth/signin');
    },
  );

  test('keeps the path prefix of the base URL', () async {
    late http.Request sent;
    final repository = HttpAuthRepository(
      baseUrl: Uri.parse('https://example.com/api/'),
      client: MockClient((request) async {
        sent = request;
        return _json({'user': _user, 'tokens': _tokens}, 200);
      }),
    );

    await repository.signIn(email: 'a@b.co', password: 'abc12345');

    expect(sent.url.toString(), 'https://example.com/api/auth/signin');
  });

  group('refresh', () {
    test('sends the refresh token and returns the new pair', () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json({
          ..._tokens,
          'access_token': 'access-2',
          'refresh_token': 'refresh-2',
        }, 200);
      });

      final tokens = await repository.refresh('refresh-1');

      expect(sent.url.path, '/auth/refresh');
      expect(jsonDecode(sent.body), {'refresh_token': 'refresh-1'});
      expect(
        tokens,
        const AuthTokens(
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
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return http.Response('', 204);
      });

      await repository.signOut('refresh-1');

      expect(sent.url.path, '/auth/signout');
      expect(jsonDecode(sent.body), {'refresh_token': 'refresh-1'});
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
