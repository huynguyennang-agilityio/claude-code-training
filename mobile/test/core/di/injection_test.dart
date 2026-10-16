import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/core/network/auth_interceptor.dart';
import 'package:stridequest/core/network/auth_token_handler.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  setUpAll(configureDependencies);
  tearDownAll(getIt.reset);

  test('resolves the auth bloc', () {
    expect(getIt<AuthBloc>(), same(getIt<AuthBloc>()));
  });

  test('one session object backs the repository and the token handler', () {
    expect(getIt<AuthRepository>(), same(getIt<AuthTokenHandler>()));
  });

  test('only the authenticated Dio carries the auth interceptor', () {
    final public = getIt<Dio>(instanceName: 'publicDio');
    final authenticated = getIt<Dio>(instanceName: 'authenticatedDio');

    expect(public.interceptors.whereType<AuthInterceptor>(), isEmpty);
    expect(
      authenticated.interceptors.whereType<AuthInterceptor>(),
      hasLength(1),
    );
    expect(authenticated.options.baseUrl, endsWith('/api/v1/'));
  });
}
