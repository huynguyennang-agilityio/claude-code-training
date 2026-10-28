import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/core/network/auth_interceptor.dart';
import 'package:stridequest/core/network/auth_token_handler.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/core/network/network_simulation.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_email_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_password_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/sign_in_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/sign_up_bloc.dart';

void main() {
  setUpAll(configureDependencies);
  tearDownAll(getIt.reset);

  test('resolves the auth bloc', () {
    expect(getIt<AuthBloc>(), same(getIt<AuthBloc>()));
  });

  test('each sign-in and sign-up route gets its own new bloc', () {
    expect(getIt<SignInBloc>(), isNot(same(getIt<SignInBloc>())));
    expect(getIt<SignUpBloc>(), isNot(same(getIt<SignUpBloc>())));
    expect(getIt<ChangeEmailBloc>(), isNot(same(getIt<ChangeEmailBloc>())));
    expect(
      getIt<ChangePasswordBloc>(),
      isNot(same(getIt<ChangePasswordBloc>())),
    );
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

  test('the DioProvider hands out the authenticated Dio', () {
    expect(
      getIt<DioProvider>()(),
      same(getIt<Dio>(instanceName: 'authenticatedDio')),
    );
    expect(
      getIt<DioProvider>()(),
      isNot(same(getIt<Dio>(instanceName: 'publicDio'))),
    );
  });

  test(
    'neither Dio simulates the network unless a SIMULATE_* setting is set',
    () {
      for (final name in ['publicDio', 'authenticatedDio']) {
        final dio = getIt<Dio>(instanceName: name);

        expect(
          dio.interceptors.whereType<NetworkSimulationInterceptor>(),
          isEmpty,
        );
      }
    },
  );
}
