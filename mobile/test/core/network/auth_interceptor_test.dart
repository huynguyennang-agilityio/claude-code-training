import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/network/auth_interceptor.dart';
import 'package:stridequest/core/network/auth_token_handler.dart';
import 'package:stridequest/core/network/dio_client.dart';

import '../../helpers/fake_http_adapter.dart';

class _MockTokens extends Mock implements AuthTokenHandler {}

ResponseBody _expired(String code) => jsonBody({
  'error': {'code': code, 'message': 'ignored', 'fields': <Object>[]},
}, 401);

void main() {
  late _MockTokens tokens;
  late FakeHttpAdapter adapter;
  late Dio dio;
  var accessToken = 'access-1';

  Dio buildDio(FakeHttpHandler handler) {
    adapter = FakeHttpAdapter(handler);
    return createDio(
      baseUrl: 'http://api.test/',
      adapter: adapter,
      interceptors: [
        AuthInterceptor(
          tokens: tokens,
          retryClient: createDio(baseUrl: 'http://api.test/', adapter: adapter),
        ),
      ],
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

  test('reads the error code of a plain-text response too', () async {
    when(() => tokens.refreshTokens()).thenAnswer((_) async {
      accessToken = 'access-2';
      return TokenRefreshResult.refreshed;
    });
    dio = buildDio(
      (request) async => request.headers['Authorization'] == 'Bearer access-1'
          ? _expired('token_expired')
          : jsonBody({'ok': true}, 200),
    );

    final response = await dio.get<String>(
      'runs',
      options: Options(responseType: ResponseType.plain),
    );

    expect(response.statusCode, 200);
    expect(adapter.requests, hasLength(2));
    verify(() => tokens.refreshTokens()).called(1);
  });

  test('adds the access token to each request', () async {
    dio = buildDio((_) async => jsonBody({'ok': true}, 200));

    await dio.get<dynamic>('runs');

    expect(authHeader(0), 'Bearer access-1');
  });

  test('sends no Authorization header when signed out', () async {
    when(() => tokens.accessToken()).thenAnswer((_) async => null);
    dio = buildDio((_) async => jsonBody({'ok': true}, 200));

    await dio.get<dynamic>('runs');

    expect(authHeader(0), isNull);
  });

  for (final code in ['token_expired', 'invalid_token']) {
    test('refreshes once and retries after $code', () async {
      when(() => tokens.refreshTokens()).thenAnswer((_) async {
        accessToken = 'access-2';
        return TokenRefreshResult.refreshed;
      });
      dio = buildDio(
        (request) async => request.headers['Authorization'] == 'Bearer access-2'
            ? jsonBody({'ok': true}, 200)
            : _expired(code),
      );

      final response = await dio.get<dynamic>('runs');

      expect(response.statusCode, 200);
      expect(adapter.requests, hasLength(2));
      expect(authHeader(1), 'Bearer access-2');
      verify(() => tokens.refreshTokens()).called(1);
      verifyNever(() => tokens.expireSession());
    });
  }

  test('expires the session when the refresh token is rejected', () async {
    when(
      () => tokens.refreshTokens(),
    ).thenAnswer((_) async => TokenRefreshResult.rejected);
    dio = buildDio((_) async => _expired('token_expired'));

    await expectLater(
      dio.get<dynamic>('runs'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
    verify(() => tokens.expireSession()).called(1);
  });

  test('keeps the session when the refresh fails for another reason', () async {
    when(
      () => tokens.refreshTokens(),
    ).thenAnswer((_) async => TokenRefreshResult.notRefreshed);
    dio = buildDio((_) async => _expired('token_expired'));

    await expectLater(
      dio.get<dynamic>('runs'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    verifyNever(() => tokens.expireSession());
    expect(adapter.requests, hasLength(1));
  });

  test('refreshes once for requests that fail at the same time', () async {
    when(() => tokens.refreshTokens()).thenAnswer((_) async {
      accessToken = 'access-2';
      return TokenRefreshResult.refreshed;
    });
    dio = buildDio(
      (request) async => request.headers['Authorization'] == 'Bearer access-2'
          ? jsonBody({'ok': true}, 200)
          : _expired('token_expired'),
    );

    final responses = await Future.wait([
      dio.get<dynamic>('runs'),
      dio.get<dynamic>('medals'),
    ]);

    expect(responses.map((r) => r.statusCode), [200, 200]);
    verify(() => tokens.refreshTokens()).called(1);
    expect(adapter.requests, hasLength(4));
  });

  test('passes the error on when signed out meanwhile', () async {
    dio = buildDio((_) async => _expired('token_expired'));
    when(() => tokens.accessToken()).thenAnswer((_) async => null);

    await expectLater(dio.get<dynamic>('runs'), throwsA(isA<DioException>()));
    verifyNever(() => tokens.refreshTokens());
  });

  test('does not refresh a second time when the retry is rejected', () async {
    when(() => tokens.refreshTokens()).thenAnswer((_) async {
      accessToken = 'access-2';
      return TokenRefreshResult.refreshed;
    });
    dio = buildDio((_) async => _expired('token_expired'));

    await expectLater(dio.get<dynamic>('runs'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(2));
    verify(() => tokens.refreshTokens()).called(1);
  });

  test('passes other 401 errors through without refreshing', () async {
    dio = buildDio((_) async => _expired('invalid_credentials'));

    await expectLater(dio.get<dynamic>('runs'), throwsA(isA<DioException>()));
    verifyNever(() => tokens.refreshTokens());
    expect(adapter.requests, hasLength(1));
  });
}
