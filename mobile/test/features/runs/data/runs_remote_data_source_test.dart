import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/network/auth_interceptor.dart';
import 'package:stridequest/core/network/auth_token_handler.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/runs/data/datasources/runs_remote_data_source.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';

import '../../../helpers/fake_http_adapter.dart';

const _sample = {
  'health_record_id': 'a',
  'start_time': '2026-11-02T06:30:00.000Z',
  'end_time': '2026-11-02T07:30:00.000Z',
  'steps': 100,
};

DioRunsRemoteDataSource _source(
  FakeHttpHandler handler, {
  Duration timeout = const Duration(seconds: 15),
  List<Interceptor> interceptors = const [],
  FakeHttpAdapter? adapter,
}) => DioRunsRemoteDataSource(
  createDio(
    baseUrl: 'http://api.test/',
    adapter: adapter ?? FakeHttpAdapter(handler),
    interceptors: interceptors,
  ),
  timeout: timeout,
);

Future<RunsFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on RunsFailure catch (failure) {
    return failure;
  }
  fail('Expected a RunsFailure');
}

ResponseBody _error(String code, int status) => jsonBody({
  'error': {'code': code, 'message': 'ignored', 'fields': <Object>[]},
}, status);

class _MockTokens extends Mock implements AuthTokenHandler {}

void main() {
  group('syncSteps', () {
    test('posts the samples and parses the answer', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody({
          'accepted': 1,
          'ignored': 2,
          'enrollments': <Object>[],
        }, 200);
      });

      final result = await source.syncSteps([_sample]);

      expect(sent.method, 'POST');
      expect(sent.path, 'runs/steps');
      expect(sentJson(sent), {
        'samples': [_sample],
      });
      expect((result.accepted, result.ignored), (1, 2));
    });

    test('a refused body is a validation failure', () async {
      final source = _source((_) async => _error('validation_error', 422));

      expect(
        (await _failureOf(source.syncSteps([_sample]))).code,
        RunsFailureCode.validation,
      );
    });

    test('a body of the wrong shape is unknown', () async {
      final source = _source((_) async => jsonBody({'accepted': 'many'}, 200));

      expect(
        (await _failureOf(source.syncSteps([_sample]))).code,
        RunsFailureCode.unknown,
      );
    });
  });

  group('saveDailyActivity', () {
    test('puts the days', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody({'days': <Object>[]}, 200);
      });

      await source.saveDailyActivity([
        {'date': '2026-11-02', 'steps': 5},
      ]);

      expect(sent.method, 'PUT');
      expect(sent.path, 'runs/daily-activity');
      expect(sentJson(sent), {
        'days': [
          {'date': '2026-11-02', 'steps': 5},
        ],
      });
    });
  });

  group('myChallenges', () {
    test('sends the cursor and the limit', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody({'items': <Object>[], 'next_cursor': null}, 200);
      });

      final page = await source.myChallenges(cursor: 'abc', limit: 50);

      expect(sent.method, 'GET');
      expect(sent.path, 'runs');
      expect(sent.queryParameters, {'cursor': 'abc', 'limit': 50});
      expect(page.items, isEmpty);
    });

    test('leaves out a missing cursor', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody({'items': <Object>[], 'next_cursor': null}, 200);
      });

      await source.myChallenges();

      expect(sent.queryParameters, {'limit': 20});
    });
  });

  group('errors', () {
    for (final (code, status, expected) in [
      ('invalid_cursor', 422, RunsFailureCode.invalidCursor),
      ('not_authenticated', 401, RunsFailureCode.notAuthenticated),
      ('mystery', 500, RunsFailureCode.unknown),
    ]) {
      test('$code maps to its failure', () async {
        final source = _source((_) async => _error(code, status));

        expect((await _failureOf(source.myChallenges())).code, expected);
      });
    }

    test('a body that is not an error response is unknown', () async {
      final source = _source((_) async => textBody('<html>', 502));

      expect(
        (await _failureOf(source.myChallenges())).code,
        RunsFailureCode.unknown,
      );
    });

    test('a transport error is a network failure', () async {
      final source = _source((_) => throw const SocketLikeError());

      expect(
        (await _failureOf(source.myChallenges())).code,
        RunsFailureCode.network,
      );
    });

    test('a slow server is a network failure', () async {
      final source = _source(
        (_) => Completer<ResponseBody>().future,
        timeout: const Duration(milliseconds: 10),
      );

      expect(
        (await _failureOf(source.myChallenges())).code,
        RunsFailureCode.network,
      );
    });
  });

  group('behind the auth interceptor', () {
    late _MockTokens tokens;
    late FakeHttpAdapter adapter;
    var accessToken = 'access-1';

    DioRunsRemoteDataSource build(FakeHttpHandler handler) {
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

    test('an expired access token is refreshed and the call retried', () async {
      when(() => tokens.refreshTokens()).thenAnswer((_) async {
        accessToken = 'access-2';
        return TokenRefreshResult.refreshed;
      });
      final source = build(
        (request) async => request.headers['Authorization'] == 'Bearer access-1'
            ? _error('token_expired', 401)
            : jsonBody({'items': <Object>[], 'next_cursor': null}, 200),
      );

      final page = await source.myChallenges();

      expect(page.items, isEmpty);
      expect(adapter.requests, hasLength(2));
      verifyNever(() => tokens.expireSession());
    });

    test('a rejected refresh token ends the session', () async {
      when(
        () => tokens.refreshTokens(),
      ).thenAnswer((_) async => TokenRefreshResult.rejected);
      final source = build((_) async => _error('invalid_token', 401));

      expect(
        (await _failureOf(source.syncSteps([_sample]))).code,
        RunsFailureCode.invalidToken,
      );
      verify(() => tokens.expireSession()).called(1);
    });
  });
}

class SocketLikeError implements Exception {
  const SocketLikeError();
}
