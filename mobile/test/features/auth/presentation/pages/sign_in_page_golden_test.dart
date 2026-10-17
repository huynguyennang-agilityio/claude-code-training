import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_in_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_auth_bloc.dart';

Widget _page(AuthState state) {
  final bloc = MockAuthBloc();
  whenListen(bloc, const Stream<AuthState>.empty(), initialState: state);
  return BlocProvider<AuthBloc>.value(value: bloc, child: const SignInPage());
}

void main() {
  goldenScreen(
    'SignInPage',
    'sign_in_page',
    _page(const AuthUnauthenticated()),
  );
  goldenScreen(
    'SignInPage, invalid credentials',
    'sign_in_page_invalid_credentials',
    _page(
      AuthUnauthenticated(
        failure: AuthFailure(AuthFailureCode.invalidCredentials),
      ),
    ),
  );
  goldenScreen(
    'SignInPage, field errors',
    'sign_in_page_field_errors',
    _page(
      AuthUnauthenticated(
        failure: AuthFailure(
          AuthFailureCode.validation,
          fieldErrors: const {'email': 'Enter a valid email address.'},
        ),
      ),
    ),
  );
  goldenScreen(
    'SignInPage, rate limited',
    'sign_in_page_rate_limited',
    _page(
      AuthUnauthenticated(
        failure: AuthFailure(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 15),
        ),
      ),
    ),
  );
  goldenScreen(
    'SignInPage, in progress',
    'sign_in_page_in_progress',
    _page(const AuthInProgress()),
    settle: false,
  );
}
