import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/di/api_environments.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/failures/auth_failure.dart';
import '../models/auth_session_model.dart';
import '../models/auth_user_model.dart';
import '../models/token_pair_model.dart';

/// The backend `/api/v1/auth/*` endpoints.
///
/// Every method throws [AuthFailure] on error.
abstract interface class AuthRemoteDataSource {
  Future<AuthSessionModel> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthSessionModel> signIn({
    required String email,
    required String password,
  });

  /// Exchanges [refreshToken] for a new pair of tokens.
  Future<TokenPairModel> refresh(String refreshToken);

  /// Revokes [refreshToken] on the backend.
  Future<void> signOut(String refreshToken);

  /// `PUT /users/me/email`: needs the access token. Returns the updated user.
  Future<AuthUserModel> changeEmail({
    required String newEmail,
    required String currentPassword,
  });

  /// `PUT /users/me/password`: needs the access token. Returns the new token
  /// pair for this device; every refresh token issued before is revoked.
  Future<TokenPairModel> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

/// [AuthRemoteDataSource] backed by the StrideQuest REST API.
///
/// Sign up, sign in, refresh and sign out use the public [Dio] (no auth
/// interceptor): they take no access token. Changing the email or password uses the
/// authenticated [Dio] (through a [DioProvider]), which adds the token and refreshes it once.
@realApi
@LazySingleton(as: AuthRemoteDataSource)
class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  DioAuthRemoteDataSource(
    @Named('publicDio') this._dio,
    this._authenticatedDio, {
    @ignoreParam this.timeout = const Duration(seconds: 15),
  });

  final Dio _dio;
  final DioProvider _authenticatedDio;

  /// How long to wait for a response before failing with
  /// [AuthFailureCode.network], whatever HTTP adapter is in use.
  final Duration timeout;

  @override
  Future<AuthSessionModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final json = await _post('auth/signup', {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    return _parse(json, AuthSessionModel.fromJson);
  }

  @override
  Future<AuthSessionModel> signIn({
    required String email,
    required String password,
  }) async {
    final json = await _post('auth/signin', {
      'email': email,
      'password': password,
    });
    return _parse(json, AuthSessionModel.fromJson);
  }

  @override
  Future<TokenPairModel> refresh(String refreshToken) async {
    final json = await _post('auth/refresh', {'refresh_token': refreshToken});
    return _parse(json, TokenPairModel.fromJson);
  }

  @override
  Future<void> signOut(String refreshToken) async {
    await _post('auth/signout', {'refresh_token': refreshToken});
  }

  @override
  Future<AuthUserModel> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final json = await _authenticatedPut('users/me/email', {
      'new_email': newEmail,
      'current_password': currentPassword,
    });
    return _parse(json, AuthUserModel.fromJson);
  }

  @override
  Future<TokenPairModel> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final json = await _authenticatedPut('users/me/password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    return _parse(json, TokenPairModel.fromJson);
  }

  /// Puts [body] as JSON through the authenticated [Dio] and returns the
  /// decoded response.
  Future<Map<String, dynamic>?> _authenticatedPut(
    String path,
    Map<String, Object> body,
  ) async {
    final Response<String> response;
    try {
      response = await _authenticatedDio()
          .put<String>(
            path,
            data: jsonEncode(body),
            // The default `validateStatus` is kept so a 401 reaches the auth
            // interceptor, which refreshes the token or ends the session.
            options: Options(
              responseType: ResponseType.plain,
              contentType: Headers.jsonContentType,
            ),
          )
          .timeout(timeout);
    } on DioException catch (error) {
      final failed = error.response;
      if (failed == null) throw AuthFailure(AuthFailureCode.network);
      throw _failure(
        failed.statusCode ?? 0,
        failed.headers,
        _decode(failed.data as String? ?? ''),
      );
    } on TimeoutException {
      throw AuthFailure(AuthFailureCode.network);
    }
    return _decode(response.data ?? '');
  }

  /// Posts [body] as JSON and returns the decoded response, or null when the
  /// response has no body.
  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, Object> body,
  ) async {
    final Response<String> response;
    try {
      response = await _dio
          .post<String>(
            path,
            data: jsonEncode(body),
            // Decode and check the status here, so a proxy error page or an
            // empty body maps to a typed failure instead of a parsing error.
            options: Options(
              responseType: ResponseType.plain,
              validateStatus: (_) => true,
            ),
          )
          .timeout(timeout);
    } on DioException {
      // Timeouts, refused connections, TLS errors: anything in transport.
      throw AuthFailure(AuthFailureCode.network);
    } on TimeoutException {
      throw AuthFailure(AuthFailureCode.network);
    }

    final status = response.statusCode ?? 0;
    final decoded = _decode(response.data ?? '');
    if (status >= 200 && status < 300) return decoded;
    throw _failure(status, response.headers, decoded);
  }

  /// Builds a model from a success body, treating a missing or malformed
  /// body as [AuthFailureCode.unknown] instead of a raw parsing error.
  T _parse<T>(
    Map<String, dynamic>? json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (json == null) throw AuthFailure(AuthFailureCode.unknown);
    try {
      return fromJson(json);
      // A wrong or missing field fails a cast, which throws TypeError (an
      // Error, not an Exception), so it is caught explicitly here.
    } on TypeError {
      throw AuthFailure(AuthFailureCode.unknown);
    } on FormatException {
      throw AuthFailure(AuthFailureCode.unknown);
    }
  }

  Map<String, dynamic>? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  AuthFailure _failure(
    int status,
    Headers headers,
    Map<String, dynamic>? body,
  ) {
    final retryAfter = _retryAfter(headers.value('retry-after'));
    final error = body?['error'];
    if (error is! Map<String, dynamic> || error['code'] is! String) {
      // The body is not an ErrorResponse, for example a proxy error page.
      return status == 429
          ? AuthFailure(AuthFailureCode.rateLimited, retryAfter: retryAfter)
          : AuthFailure(AuthFailureCode.unknown);
    }
    return AuthFailure(
      AuthFailureCode.fromWire(error['code'] as String),
      fieldErrors: _fieldErrors(error['fields']),
      retryAfter: retryAfter,
    );
  }

  /// Reads `Retry-After` in seconds, the form the backend sends. Returns null
  /// for a missing header or the HTTP-date form.
  Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  Map<String, String> _fieldErrors(Object? fields) {
    if (fields is! List<dynamic>) return const {};
    return {
      for (final item in fields.whereType<Map<String, dynamic>>())
        if (item['field'] is String && item['message'] is String)
          item['field'] as String: item['message'] as String,
    };
  }
}
