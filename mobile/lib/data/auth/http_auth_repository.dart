import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_failure.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

/// [AuthRepository] backed by the StrideQuest REST API.
///
/// Paths are resolved relative to [baseUrl], so a base such as
/// `https://example.com/api/` keeps its `/api/` prefix.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({required this.baseUrl, required http.Client client})
    : _client = client;

  static const _timeout = Duration(seconds: 15);

  final Uri baseUrl;
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
          .timeout(_timeout);
    } on http.ClientException {
      throw AuthFailure(AuthFailureCode.network);
    } on TimeoutException {
      throw AuthFailure(AuthFailureCode.network);
    }

    final decoded = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw _failure(response.statusCode, decoded);
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

  AuthFailure _failure(int status, Map<String, dynamic>? body) {
    final error = body?['error'];
    if (error is! Map<String, dynamic> || error['code'] is! String) {
      // The body is not an ErrorResponse, for example a proxy error page.
      return AuthFailure(
        status == 429 ? AuthFailureCode.rateLimited : AuthFailureCode.unknown,
      );
    }
    return AuthFailure(
      AuthFailureCode.fromWire(error['code'] as String),
      fieldErrors: _fieldErrors(error['fields']),
    );
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
