import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/sign_in_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/sign_up_bloc.dart';

import 'challenges_di.dart';

/// Registers the form blocs the sign-in and sign-up routes ask `getIt` for,
/// built on [repository]. The caller resets `getIt` when the test ends
/// (`addTearDown(getIt.reset)`).
///
/// The routes create their bloc with `getIt`, as the app does; tests that
/// build the real router call this instead of `configureDependencies`, which
/// would also build the real network layer.
void registerAuthFormBlocs(AuthRepository repository) {
  getIt
    ..registerFactory<SignInBloc>(() => SignInBloc(repository))
    ..registerFactory<SignUpBloc>(() => SignUpBloc(repository));
  // The app routes also open the Challenges tab once the user is signed in.
  registerChallengeBlocs();
}
