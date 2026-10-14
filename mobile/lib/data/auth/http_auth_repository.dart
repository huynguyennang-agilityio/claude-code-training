import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_failure.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

/// [AuthRepository] backed by the StrideQuest REST API.
///
/// Paths are resolved relative to [baseUrl], so a base such as
/// `https://example.com/api` keeps its `/api` prefix, with or without a
/// trailing slash.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required Uri baseUrl,
    required http.Client client,
    this.timeout = const Duration(seconds: 15),
  }) : baseUrl = _withTrailingSlash(baseUrl),
       _client = client;

  final Uri baseUrl;

  /// How long to wait for a response before failing with
  /// [AuthFailureCode.network].
  final Duration timeout;

  final http.Client _client;

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final json = await _post('auth/signup', {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    return _parse(json, AuthSession.fromJson);
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final json = await _post('auth/signin', {
      'email': email,
      'password': password,
    });
    return _parse(json, AuthSession.fromJson);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final json = await _post('auth/refresh', {'refresh_token': refreshToken});
    return _parse(json, AuthTokens.fromJson);
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
    final http.Response response;
    try {
      response = await _client
          .post(
            baseUrl.resolve(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on http.ClientException {
      throw AuthFailure(AuthFailureCode.network);
    } on TimeoutException {
      throw AuthFailure(AuthFailureCode.network);
    } on Exception {
      // Anything else the transport throws, such as a TLS HandshakeException,
      // so callers only ever have to handle AuthFailure.
      throw AuthFailure(AuthFailureCode.network);
    }

    final decoded = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw _failure(response, decoded);
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

  AuthFailure _failure(http.Response response, Map<String, dynamic>? body) {
    final retryAfter = _retryAfter(response.headers['retry-after']);
    final error = body?['error'];
    if (error is! Map<String, dynamic> || error['code'] is! String) {
      // The body is not an ErrorResponse, for example a proxy error page.
      return response.statusCode == 429
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

  static Uri _withTrailingSlash(Uri url) {
    return url.path.endsWith('/') ? url : url.replace(path: '${url.path}/');
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
