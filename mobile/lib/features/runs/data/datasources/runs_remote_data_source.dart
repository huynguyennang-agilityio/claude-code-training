import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../domain/failures/runs_failure.dart';
import '../models/runs_models.dart';

/// The backend `/api/v1/runs` endpoints (`docs/api/runs.md`).
///
/// Every method throws [RunsFailure] on error.
abstract interface class RunsRemoteDataSource {
  Future<StepSyncResultModel> syncSteps(List<Map<String, Object>> samples);

  Future<void> saveDailyActivity(List<Map<String, Object>> days);

  Future<MyChallengePageModel> myChallenges({String? cursor, int limit});
}

/// [RunsRemoteDataSource] over the authenticated [Dio]: it adds the access token
/// and refreshes it once when it has expired. A non-2xx answer reaches here as a
/// [DioException], after the auth interceptor has had its turn.
@LazySingleton(as: RunsRemoteDataSource)
class DioRunsRemoteDataSource implements RunsRemoteDataSource {
  DioRunsRemoteDataSource(
    @Named('authenticatedDio') this._dio, {
    @ignoreParam this.timeout = const Duration(seconds: 15),
  });

  final Dio _dio;
  final Duration timeout;

  @override
  Future<StepSyncResultModel> syncSteps(
    List<Map<String, Object>> samples,
  ) async {
    final json = await _request('POST', 'runs/steps', {'samples': samples});
    return _parse(json, StepSyncResultModel.fromJson);
  }

  @override
  Future<void> saveDailyActivity(List<Map<String, Object>> days) async {
    await _request('PUT', 'runs/daily-activity', {'days': days});
  }

  @override
  Future<MyChallengePageModel> myChallenges({
    String? cursor,
    int limit = 20,
  }) async {
    final json = await _request('GET', 'runs', null, {
      'cursor': ?cursor,
      'limit': limit,
    });
    return _parse(json, MyChallengePageModel.fromJson);
  }

  Future<Map<String, dynamic>?> _request(
    String method,
    String path, [
    Object? body,
    Map<String, Object>? query,
  ]) async {
    final Response<String> response;
    try {
      response = await _dio
          .request<String>(
            path,
            data: body == null ? null : jsonEncode(body),
            queryParameters: query,
            options: Options(method: method, responseType: ResponseType.plain),
          )
          .timeout(timeout);
    } on DioException catch (error) {
      final failed = error.response;
      if (failed == null) throw const RunsFailure(RunsFailureCode.network);
      throw _failure(_decode(failed.data as String? ?? ''));
    } on TimeoutException {
      throw const RunsFailure(RunsFailureCode.network);
    }
    return _decode(response.data ?? '');
  }

  T _parse<T>(
    Map<String, dynamic>? json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (json == null) throw const RunsFailure(RunsFailureCode.unknown);
    try {
      return fromJson(json);
    } on TypeError {
      throw const RunsFailure(RunsFailureCode.unknown);
    } on FormatException {
      throw const RunsFailure(RunsFailureCode.unknown);
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

  RunsFailure _failure(Map<String, dynamic>? body) {
    final error = body?['error'];
    if (error is! Map<String, dynamic> || error['code'] is! String) {
      return const RunsFailure(RunsFailureCode.unknown);
    }
    return RunsFailure(RunsFailureCode.fromWire(error['code'] as String));
  }
}
