import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/config/api_mode.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/datasources/fake_auth_remote_data_source.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_email_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/sign_in_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/sign_up_bloc.dart';
import 'package:stridequest/features/challenges/data/datasources/challenge_remote_data_source.dart';
import 'package:stridequest/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:stridequest/features/profile/data/datasources/fake_profile_remote_data_source.dart';
import 'package:stridequest/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:stridequest/features/profile/domain/repositories/profile_repository.dart';
import 'package:stridequest/features/profile/presentation/bloc/profile_info_bloc.dart';
import 'package:stridequest/features/runs/data/datasources/runs_remote_data_source.dart';
import 'package:stridequest/features/runs/domain/repositories/health_repository.dart';
import 'package:stridequest/features/runs/domain/repositories/runs_repository.dart';
import 'package:stridequest/features/runs/presentation/bloc/my_challenges_bloc.dart';

void main() {
  for (final mode in ApiMode.values) {
    group('in $mode', () {
      setUp(() => configureDependencies(mode: mode));
      tearDown(getIt.reset);

      test('every repository resolves', () {
        expect(getIt<AuthRepository>(), isNotNull);
        expect(getIt<ChallengeRepository>(), isNotNull);
        expect(getIt<RunsRepository>(), isNotNull);
        expect(getIt<HealthRepository>(), isNotNull);
        expect(getIt<ProfileRepository>(), isNotNull);
      });

      test('the blocs the routes ask for resolve', () {
        expect(getIt<AuthBloc>(), isNotNull);
        expect(getIt<SignInBloc>(), isNotNull);
        expect(getIt<SignUpBloc>(), isNotNull);
        expect(getIt<ChangeEmailBloc>(), isNotNull);
        expect(getIt<ChallengesBloc>(), isNotNull);
        expect(getIt<MyChallengesBloc>(), isNotNull);
        expect(getIt<ProfileInfoBloc>(), isNotNull);
      });

      test('the DioProvider hands out the authenticated Dio', () {
        expect(
          getIt<DioProvider>()(),
          same(getIt<Dio>(instanceName: 'authenticatedDio')),
        );
      });

      test('challenges and runs use their real data sources', () {
        expect(
          getIt<ChallengeRemoteDataSource>(),
          isA<DioChallengeRemoteDataSource>(),
        );
        expect(getIt<RunsRemoteDataSource>(), isA<DioRunsRemoteDataSource>());
      });
    });
  }

  test('real mode signs in through the API', () {
    configureDependencies(mode: ApiMode.real);
    addTearDown(getIt.reset);

    expect(getIt<AuthRemoteDataSource>(), isA<DioAuthRemoteDataSource>());
  });

  test('mock mode signs in through the fake', () {
    configureDependencies(mode: ApiMode.mock);
    addTearDown(getIt.reset);

    expect(getIt<AuthRemoteDataSource>(), isA<FakeAuthRemoteDataSource>());
  });

  test('real mode reads the profile through the API', () {
    configureDependencies(mode: ApiMode.real);
    addTearDown(getIt.reset);

    expect(getIt<ProfileRemoteDataSource>(), isA<DioProfileRemoteDataSource>());
  });

  test('mock mode reads the profile from the fake', () {
    configureDependencies(mode: ApiMode.mock);
    addTearDown(getIt.reset);

    expect(
      getIt<ProfileRemoteDataSource>(),
      isA<FakeProfileRemoteDataSource>(),
    );
  });
}
