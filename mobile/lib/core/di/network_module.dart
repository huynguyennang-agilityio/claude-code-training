import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../config/app_config.dart';
import '../network/auth_interceptor.dart';
import '../network/auth_token_handler.dart';
import '../network/dio_client.dart';
import '../network/network_simulation.dart';
import 'injection.dart';

@module
abstract class NetworkModule {
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();

  /// For endpoints that take no access token, such as `auth/*`.
  @Named('publicDio')
  @lazySingleton
  Dio publicDio() => createDio(
    baseUrl: AppConfig.apiBaseUrl,
    interceptors: [..._simulation()],
  );

  /// For protected endpoints: adds the access token and refreshes it once on
  /// `token_expired`/`invalid_token`.
  @Named('authenticatedDio')
  @lazySingleton
  Dio authenticatedDio(AuthTokenHandler tokens) => createDio(
    baseUrl: AppConfig.apiBaseUrl,
    interceptors: [
      ..._simulation(),
      AuthInterceptor(
        tokens: tokens,
        retryClient: createDio(baseUrl: AppConfig.apiBaseUrl),
      ),
    ],
  );

  /// The authenticated [Dio], resolved on first use. `AuthRemoteDataSource`
  /// needs it for `PUT /users/me/email`, but the authenticated [Dio] needs the
  /// auth repository (its token handler), which needs `AuthRemoteDataSource`.
  @lazySingleton
  DioProvider get authenticatedDioProvider =>
      DioProvider(() => getIt<Dio>(instanceName: 'authenticatedDio'));

  /// The dev-only network simulation, only in debug builds and only when a
  /// `SIMULATE_*` setting is given, so release builds can never carry it.
  static List<Interceptor> _simulation() => [
    if (kDebugMode && AppConfig.networkSimulation.isActive)
      NetworkSimulationInterceptor(AppConfig.networkSimulation),
  ];
}
