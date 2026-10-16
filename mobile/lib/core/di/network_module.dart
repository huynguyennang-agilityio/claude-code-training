import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../config/app_config.dart';
import '../network/auth_interceptor.dart';
import '../network/auth_token_handler.dart';
import '../network/dio_client.dart';

@module
abstract class NetworkModule {
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();

  /// For endpoints that take no access token, such as `auth/*`.
  @Named('publicDio')
  @lazySingleton
  Dio publicDio() => createDio(baseUrl: AppConfig.apiBaseUrl);

  /// For protected endpoints: adds the access token and refreshes it once on
  /// `token_expired`/`invalid_token`.
  @Named('authenticatedDio')
  @lazySingleton
  Dio authenticatedDio(AuthTokenHandler tokens) => createDio(
    baseUrl: AppConfig.apiBaseUrl,
    interceptors: [
      AuthInterceptor(
        tokens: tokens,
        retryClient: createDio(baseUrl: AppConfig.apiBaseUrl),
      ),
    ],
  );
}
