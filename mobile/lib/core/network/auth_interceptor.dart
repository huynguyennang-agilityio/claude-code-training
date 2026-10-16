import 'package:dio/dio.dart';

import 'auth_token_handler.dart';

/// Adds the access token to requests and recovers from an expired one.
///
/// Follows `docs/api/auth.md`: when a protected route returns `401` with
/// `token_expired` or `invalid_token`, refresh once and retry the request. If
/// the refresh fails, clear the session so the router sends the user to
/// sign in.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required AuthTokenHandler tokens, required Dio retryClient})
    : _tokens = tokens,
      _retryClient = retryClient;

  /// Marks a request that was already retried after a refresh.
  static const retriedKey = 'auth_retried';

  static const _expiredTokenCodes = {'token_expired', 'invalid_token'};

  final AuthTokenHandler _tokens;

  /// Sends the retried request. It must not use this interceptor, so a second
  /// `401` is returned to the caller instead of starting another refresh.
  final Dio _retryClient;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.accessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (request.extra[retriedKey] == true || !_isExpiredToken(err.response)) {
      return handler.next(err);
    }

    if (!await _tokens.refreshTokens()) {
      await _tokens.expireSession();
      return handler.next(err);
    }

    final token = await _tokens.accessToken();
    request.extra[retriedKey] = true;
    request.headers['Authorization'] = 'Bearer $token';
    try {
      handler.resolve(await _retryClient.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isExpiredToken(Response<dynamic>? response) {
    if (response?.statusCode != 401) return false;
    final body = response?.data;
    final error = body is Map<String, dynamic> ? body['error'] : null;
    return error is Map<String, dynamic> &&
        _expiredTokenCodes.contains(error['code']);
  }
}
