import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/network/auth_interceptor.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stridequest/features/auth/domain/entities/session_end_reason.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';

import '../../../helpers/auth_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/in_memory_auth_local_data_source.dart';

/// The real interceptor, repository and data source together, wired as in
/// `NetworkModule`: a protected `401` refreshes, and the refresh's error code
/// decides why the session ended.

ResponseBody _unauthorized(String code) => jsonBody({
  'error': {'code': code, 'message': 'ignored', 'fields': <Object>[]},
}, 401);

ResponseBody _example(String name) {
  final file = File('../docs/api/examples/auth/$name.json');
  return jsonBody(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    401,
  );
}

void main() {
  late InMemoryAuthLocalDataSource local;
  late AuthRepositoryImpl repository;

  void build(ResponseBody Function() refreshAnswer) {
    final adapter = FakeHttpAdapter(
      (request) async => request.path.endsWith('auth/refresh')
          ? refreshAnswer()
          : _unauthorized('token_expired'),
    );
    final public = createDio(baseUrl: 'http://api.test/', adapter: adapter);
    late final Dio authenticated;
    repository = AuthRepositoryImpl(
      DioAuthRemoteDataSource(public, DioProvider(() => authenticated)),
      local,
    );
    authenticated = createDio(
      baseUrl: 'http://api.test/',
      adapter: adapter,
      interceptors: [AuthInterceptor(tokens: repository, retryClient: public)],
    );
  }

  setUp(() => local = InMemoryAuthLocalDataSource()..session = testSession());
  tearDown(() => repository.dispose());

  Future<SessionEndReason> endReasonOfProtectedCall() async {
    final ended = repository.sessionEnded.first;
    await expectLater(
      repository.changeEmail(
        newEmail: 'new.runner@example.com',
        currentPassword: 'run4medals',
      ),
      throwsA(isA<AuthFailure>()),
    );
    expect(local.session, isNull);
    return ended;
  }

  test('a session_replaced refresh ends the session as replaced', () async {
    build(() => _example('error_session_replaced'));

    expect(await endReasonOfProtectedCall(), SessionEndReason.replaced);
  });

  test('an invalid_refresh_token refresh ends it as expired', () async {
    build(() => _unauthorized('invalid_refresh_token'));

    expect(await endReasonOfProtectedCall(), SessionEndReason.expired);
  });
}
