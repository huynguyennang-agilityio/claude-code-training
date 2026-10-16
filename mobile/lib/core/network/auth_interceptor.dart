import 'package:dio/dio.dart';

import 'auth_token_handler.dart';

/// Adds the access token to requests and recovers from an expired one.
///
/// Follows `docs/api/auth.md`: when a protected route returns `401` with
/// `token_expired` or `invalid_token`, refresh once and retry the request.
/// Only a rejected refresh token ends the session; a refresh that fails for
/// another reason (network, rate limit, server error) keeps it, and the
/// caller gets the original error.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required AuthTokenHandler tokens, required Dio retryClient})
    : _tokens = tokens,
      _retryClient = retryClient;

  static const _expiredTokenCodes = {'token_expired', 'invalid_token'};

  final AuthTokenHandler _tokens;

  /// Sends the retried request. It must not use this interceptor, so a second
  /// `401` goes back to the caller instead of starting another refresh.
  final Dio _retryClient;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.accessToken();
    if (token != null) options.headers['Authorization'] = _bearer(token);
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_isExpiredToken(err.response)) return handler.next(err);

    final request = err.requestOptions;
    final current = await _tokens.accessToken();
    if (current == null) return handler.next(err);

    // Errors are handled one at a time. If another failed request already
    // refreshed while this one waited, its token is stale: retry with the
    // new one instead of refreshing again.
    if (request.headers['Authorization'] != _bearer(current)) {
      return _retry(request, current, handler);
    }

    switch (await _tokens.refreshTokens()) {
      case TokenRefreshResult.refreshed:
        final token = await _tokens.accessToken();
        if (token == null) return handler.next(err);
        return _retry(request, token, handler);
      case TokenRefreshResult.rejected:
        await _tokens.expireSession();
        return handler.next(err);
      case TokenRefreshResult.notRefreshed:
        return handler.next(err);
    }
  }

  Future<void> _retry(
    RequestOptions request,
    String token,
    ErrorInterceptorHandler handler,
  ) async {
    request.headers['Authorization'] = _bearer(token);
    try {
      handler.resolve(await _retryClient.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  String _bearer(String token) => 'Bearer $token';

  bool _isExpiredToken(Response<dynamic>? response) {
    if (response?.statusCode != 401) return false;
    final body = response?.data;
    final error = body is Map<String, dynamic> ? body['error'] : null;
    return error is Map<String, dynamic> &&
        _expiredTokenCodes.contains(error['code']);
  }
}
