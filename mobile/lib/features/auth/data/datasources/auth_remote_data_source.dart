import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/di/api_environments.dart';
import '../../domain/failures/auth_failure.dart';
import '../models/auth_session_model.dart';
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
}

/// [AuthRemoteDataSource] backed by the StrideQuest REST API.
///
/// Uses the public [Dio] (no auth interceptor): these endpoints take no
/// access token.
@realApi
@LazySingleton(as: AuthRemoteDataSource)
class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  DioAuthRemoteDataSource(
    @Named('publicDio') this._dio, {
    @ignoreParam this.timeout = const Duration(seconds: 15),
  });

  final Dio _dio;

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
