import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/network/auth_interceptor.dart';
import 'package:stridequest/core/network/auth_token_handler.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/challenges/data/datasources/challenge_remote_data_source.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';

import '../../../helpers/fake_http_adapter.dart';

/// The challenges data source behind the real [AuthInterceptor], wired as in
/// `NetworkModule`: a `401` must reach the interceptor, which refreshes the
/// tokens or ends the session.

class _MockTokens extends Mock implements AuthTokenHandler {}

ResponseBody _unauthorized(String code) => jsonBody({
  'error': {'code': code, 'message': 'ignored', 'fields': <Object>[]},
}, 401);

const _page = {'items': <Object>[], 'next_cursor': null};

void main() {
  late _MockTokens tokens;
  late FakeHttpAdapter adapter;
  late DioChallengeRemoteDataSource source;
  var accessToken = 'access-1';

  void build(FakeHttpHandler handler) {
    adapter = FakeHttpAdapter(handler);
    source = DioChallengeRemoteDataSource(
      createDio(
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
      ),
    );
  }

  String? authHeader(int request) =>
      adapter.requests[request].headers['Authorization'] as String?;

  setUp(() {
    accessToken = 'access-1';
    tokens = _MockTokens();
    when(() => tokens.accessToken()).thenAnswer((_) async => accessToken);
    when(() => tokens.expireSession()).thenAnswer((_) async {});
  });

  for (final code in ['token_expired', 'invalid_token']) {
    test('$code refreshes the tokens once and retries the call', () async {
      when(() => tokens.refreshTokens()).thenAnswer((_) async {
        accessToken = 'access-2';
        return TokenRefreshResult.refreshed;
      });
      build(
        (request) async => request.headers['Authorization'] == 'Bearer access-1'
            ? _unauthorized(code)
            : jsonBody(_page, 200),
      );

      final page = await source.list();

      expect(page.items, isEmpty);
      expect(adapter.requests, hasLength(2));
      expect(authHeader(1), 'Bearer access-2');
      verify(() => tokens.refreshTokens()).called(1);
      verifyNever(() => tokens.expireSession());
    });
  }

  test('a rejected refresh token ends the session', () async {
    when(
      () => tokens.refreshTokens(),
    ).thenAnswer((_) async => TokenRefreshResult.rejected);
    build((_) async => _unauthorized('invalid_token'));

    await expectLater(
      source.list(),
      throwsA(
        isA<ChallengeFailure>().having(
          (failure) => failure.code,
          'code',
          ChallengeFailureCode.invalidToken,
        ),
      ),
    );

    verify(() => tokens.expireSession()).called(1);
  });

  test('a refresh that fails for another reason keeps the session', () async {
    when(
      () => tokens.refreshTokens(),
    ).thenAnswer((_) async => TokenRefreshResult.notRefreshed);
    build((_) async => _unauthorized('token_expired'));

    await expectLater(
      source.get(7),
      throwsA(
        isA<ChallengeFailure>().having(
          (failure) => failure.code,
          'code',
          ChallengeFailureCode.tokenExpired,
        ),
      ),
    );

    verifyNever(() => tokens.expireSession());
  });

  test('an action is retried after a refresh too', () async {
    when(() => tokens.refreshTokens()).thenAnswer((_) async {
      accessToken = 'access-2';
      return TokenRefreshResult.refreshed;
    });
    build(
      (request) async => request.headers['Authorization'] == 'Bearer access-1'
          ? _unauthorized('token_expired')
          : jsonBody({
              'error': {'code': 'challenge_ended', 'message': 'x'},
            }, 409),
    );

    await expectLater(
      source.join(7),
      throwsA(
        isA<ChallengeFailure>().having(
          (failure) => failure.code,
          'code',
          ChallengeFailureCode.challengeEnded,
        ),
      ),
    );
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.method, 'POST');
  });
}
