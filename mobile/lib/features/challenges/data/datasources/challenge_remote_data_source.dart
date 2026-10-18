import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/challenge.dart';
import '../../domain/failures/challenge_failure.dart';
import '../models/challenge_models.dart';

/// The backend `/api/v1/challenges` endpoints (`docs/api/challenges.md`).
///
/// Every method throws [ChallengeFailure] on error.
abstract interface class ChallengeRemoteDataSource {
  Future<ChallengePageModel> list({
    ChallengeType? type,
    String? query,
    String? cursor,
    int limit,
  });

  Future<ChallengeModel> get(int id);

  Future<ChallengeModel> join(int id);

  Future<ChallengeModel> pause(int id);

  Future<ChallengeModel> resume(int id);

  Future<ChallengeModel> leave(int id);
}

/// [ChallengeRemoteDataSource] over the authenticated [Dio]: it adds the access
/// token and refreshes it once when it has expired.
@LazySingleton(as: ChallengeRemoteDataSource)
class DioChallengeRemoteDataSource implements ChallengeRemoteDataSource {
  DioChallengeRemoteDataSource(
    @Named('authenticatedDio') this._dio, {
    @ignoreParam this.timeout = const Duration(seconds: 15),
  });

  final Dio _dio;
  final Duration timeout;

  @override
  Future<ChallengePageModel> list({
    ChallengeType? type,
    String? query,
    String? cursor,
    int limit = 20,
  }) async {
    final json = await _request('GET', 'challenges', {
      if (type != null) 'type': type.wire,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      'cursor': ?cursor,
      'limit': limit,
    });
    return _parse(json, ChallengePageModel.fromJson);
  }

  @override
  Future<ChallengeModel> get(int id) async {
    final json = await _request('GET', 'challenges/$id');
    return _parse(json, ChallengeModel.fromJson);
  }

  @override
  Future<ChallengeModel> join(int id) => _act(id, 'join');

  @override
  Future<ChallengeModel> pause(int id) => _act(id, 'pause');

  @override
  Future<ChallengeModel> resume(int id) => _act(id, 'resume');

  @override
  Future<ChallengeModel> leave(int id) => _act(id, 'leave');

  Future<ChallengeModel> _act(int id, String action) async {
    final json = await _request('POST', 'challenges/$id/$action');
    return _parse(json, ChallengeModel.fromJson);
  }

  Future<Map<String, dynamic>?> _request(
    String method,
    String path, [
    Map<String, Object>? query,
  ]) async {
    final Response<String> response;
    try {
      response = await _dio
          .request<String>(
            path,
            queryParameters: query,
            // The default `validateStatus` is kept: a non-2xx answer must go
            // through the auth interceptor, which refreshes an expired token
            // or ends the session. It reaches here as a [DioException].
            options: Options(method: method, responseType: ResponseType.plain),
          )
          .timeout(timeout);
    } on DioException catch (error) {
      final failed = error.response;
      if (failed == null) {
        throw const ChallengeFailure(ChallengeFailureCode.network);
      }
      throw _failure(_decode(failed.data as String? ?? ''));
    } on TimeoutException {
      throw const ChallengeFailure(ChallengeFailureCode.network);
    }
    return _decode(response.data ?? '');
  }

  T _parse<T>(
    Map<String, dynamic>? json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (json == null) {
      throw const ChallengeFailure(ChallengeFailureCode.unknown);
    }
    try {
      return fromJson(json);
    } on TypeError {
      throw const ChallengeFailure(ChallengeFailureCode.unknown);
    } on FormatException {
      throw const ChallengeFailure(ChallengeFailureCode.unknown);
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

  ChallengeFailure _failure(Map<String, dynamic>? body) {
    final error = body?['error'];
    if (error is! Map<String, dynamic> || error['code'] is! String) {
      return const ChallengeFailure(ChallengeFailureCode.unknown);
    }
    final code = ChallengeFailureCode.fromWire(error['code'] as String);
    // The overlap message names the other challenge, so it is worth showing as is.
    final message = error['message'];
    return ChallengeFailure(
      code,
      serverMessage:
          code == ChallengeFailureCode.overlappingChallenge && message is String
          ? message
          : null,
    );
  }
}
