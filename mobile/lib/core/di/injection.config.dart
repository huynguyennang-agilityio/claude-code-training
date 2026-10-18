// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:dio/dio.dart' as _i361;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:stridequest/core/di/network_module.dart' as _i245;
import 'package:stridequest/core/network/auth_token_handler.dart' as _i713;
import 'package:stridequest/features/auth/auth_module.dart' as _i670;
import 'package:stridequest/features/auth/data/datasources/auth_local_data_source.dart'
    as _i851;
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart'
    as _i397;
import 'package:stridequest/features/auth/data/repositories/auth_repository_impl.dart'
    as _i663;
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart'
    as _i231;
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart'
    as _i649;
import 'package:stridequest/features/auth/presentation/bloc/sign_in_bloc.dart'
    as _i696;
import 'package:stridequest/features/auth/presentation/bloc/sign_up_bloc.dart'
    as _i43;
import 'package:stridequest/features/challenges/data/datasources/challenge_remote_data_source.dart'
    as _i216;
import 'package:stridequest/features/challenges/data/repositories/challenge_repository_impl.dart'
    as _i743;
import 'package:stridequest/features/challenges/domain/repositories/challenge_repository.dart'
    as _i756;
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart'
    as _i530;
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart'
    as _i909;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final networkModule = _$NetworkModule();
    final authModule = _$AuthModule();
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => networkModule.secureStorage,
    );
    gh.lazySingleton<_i361.Dio>(
      () => networkModule.publicDio(),
      instanceName: 'publicDio',
    );
    gh.lazySingleton<_i851.AuthLocalDataSource>(
      () => _i851.SecureAuthLocalDataSource(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i397.AuthRemoteDataSource>(
      () => _i397.DioAuthRemoteDataSource(
        gh<_i361.Dio>(instanceName: 'publicDio'),
      ),
    );
    gh.lazySingleton<_i663.AuthRepositoryImpl>(
      () => _i663.AuthRepositoryImpl(
        gh<_i397.AuthRemoteDataSource>(),
        gh<_i851.AuthLocalDataSource>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i231.AuthRepository>(
      () => authModule.authRepository(gh<_i663.AuthRepositoryImpl>()),
    );
    gh.lazySingleton<_i713.AuthTokenHandler>(
      () => authModule.authTokenHandler(gh<_i663.AuthRepositoryImpl>()),
    );
    gh.factory<_i696.SignInBloc>(
      () => _i696.SignInBloc(gh<_i231.AuthRepository>()),
    );
    gh.factory<_i43.SignUpBloc>(
      () => _i43.SignUpBloc(gh<_i231.AuthRepository>()),
    );
    gh.lazySingleton<_i649.AuthBloc>(
      () => _i649.AuthBloc(gh<_i231.AuthRepository>()),
    );
    gh.lazySingleton<_i361.Dio>(
      () => networkModule.authenticatedDio(gh<_i713.AuthTokenHandler>()),
      instanceName: 'authenticatedDio',
    );
    gh.lazySingleton<_i216.ChallengeRemoteDataSource>(
      () => _i216.DioChallengeRemoteDataSource(
        gh<_i361.Dio>(instanceName: 'authenticatedDio'),
      ),
    );
    gh.lazySingleton<_i756.ChallengeRepository>(
      () =>
          _i743.ChallengeRepositoryImpl(gh<_i216.ChallengeRemoteDataSource>()),
    );
    gh.factory<_i530.ChallengeDetailBloc>(
      () => _i530.ChallengeDetailBloc(gh<_i756.ChallengeRepository>()),
    );
    gh.factory<_i909.ChallengesBloc>(
      () => _i909.ChallengesBloc(gh<_i756.ChallengeRepository>()),
    );
    return this;
  }
}

class _$NetworkModule extends _i245.NetworkModule {}

class _$AuthModule extends _i670.AuthModule {}
