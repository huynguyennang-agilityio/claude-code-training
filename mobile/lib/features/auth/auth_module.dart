import 'package:injectable/injectable.dart';

import '../../core/network/auth_token_handler.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';

/// Exposes the single [AuthRepositoryImpl] under both of its interfaces.
@module
abstract class AuthModule {
  @lazySingleton
  AuthRepository authRepository(AuthRepositoryImpl impl) => impl;

  @lazySingleton
  AuthTokenHandler authTokenHandler(AuthRepositoryImpl impl) => impl;
}
