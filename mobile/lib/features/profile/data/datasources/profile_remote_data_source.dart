import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/di/api_environments.dart';
import '../../domain/failures/profile_failure.dart';
import '../models/profile_model.dart';

/// The backend `/api/v1/users/me/profile` endpoints (`docs/api/profile.md`).
///
/// Every method throws [ProfileFailure] on error.
abstract interface class ProfileRemoteDataSource {
  Future<ProfileModel> get();

  Future<ProfileModel> put(ProfileModel profile);
}

/// [ProfileRemoteDataSource] over the authenticated [Dio]: it adds the access
/// token and refreshes it once when it has expired.
@realApi
@LazySingleton(as: ProfileRemoteDataSource)
class DioProfileRemoteDataSource implements ProfileRemoteDataSource {
  DioProfileRemoteDataSource(
    @Named('authenticatedDio') this._dio, {
    @ignoreParam this.timeout = const Duration(seconds: 15),
  });

  static const _path = 'users/me/profile';

  final Dio _dio;
  final Duration timeout;

  @override
  Future<ProfileModel> get() async => _parse(await _request('GET'));

  @override
  Future<ProfileModel> put(ProfileModel profile) async =>
      _parse(await _request('PUT', profile.toJson()));

  Future<Map<String, dynamic>?> _request(
    String method, [
    Map<String, dynamic>? body,
  ]) async {
    final Response<String> response;
    try {
      response = await _dio
          .request<String>(
            _path,
            data: body,
            // The default `validateStatus` is kept so a 401 reaches the auth
            // interceptor, which refreshes the token or ends the session.
            options: Options(method: method, responseType: ResponseType.plain),
          )
          .timeout(timeout);
    } on DioException catch (error) {
      final failed = error.response;
      if (failed == null) {
        throw const ProfileFailure(ProfileFailureCode.network);
      }
      throw _failure(_decode(failed.data as String? ?? ''));
    } on TimeoutException {
      throw const ProfileFailure(ProfileFailureCode.network);
    }
    return _decode(response.data ?? '');
  }

  ProfileModel _parse(Map<String, dynamic>? json) {
    if (json == null) throw const ProfileFailure(ProfileFailureCode.unknown);
    try {
      return ProfileModel.fromJson(json);
    } on TypeError {
      throw const ProfileFailure(ProfileFailureCode.unknown);
    } on FormatException {
      throw const ProfileFailure(ProfileFailureCode.unknown);
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

  ProfileFailure _failure(Map<String, dynamic>? body) {
    final error = body?['error'];
    if (error is! Map<String, dynamic> || error['code'] is! String) {
      return const ProfileFailure(ProfileFailureCode.unknown);
    }
    final code = ProfileFailureCode.fromWire(error['code'] as String);
    final fields = error['fields'];
    return ProfileFailure(
      code,
      fieldErrors: {
        if (code == ProfileFailureCode.validation && fields is List<dynamic>)
          for (final field in fields)
            if (field is Map<String, dynamic> &&
                field['field'] is String &&
                field['message'] is String)
              field['field'] as String: field['message'] as String,
      },
    );
  }
}
