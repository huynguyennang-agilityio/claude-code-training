import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_up_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_auth_bloc.dart';

Widget _page(AuthState state) {
  final bloc = MockAuthBloc();
  whenListen(bloc, const Stream<AuthState>.empty(), initialState: state);
  return BlocProvider<AuthBloc>.value(value: bloc, child: const SignUpPage());
}

void main() {
  goldenScreen(
    'SignUpPage',
    'sign_up_page',
    _page(const AuthUnauthenticated()),
  );
  goldenScreen(
    'SignUpPage, email taken',
    'sign_up_page_email_taken',
    _page(
      AuthUnauthenticated(failure: AuthFailure(AuthFailureCode.emailTaken)),
    ),
  );
  goldenScreen(
    'SignUpPage, field errors',
    'sign_up_page_field_errors',
    _page(
      AuthUnauthenticated(
        failure: AuthFailure(
          AuthFailureCode.validation,
          fieldErrors: const {
            'display_name': 'Display name must be 1 to 50 characters.',
            'password': 'Password must be 8 to 128 characters.',
          },
        ),
      ),
    ),
  );
  goldenScreen(
    'SignUpPage, in progress',
    'sign_up_page_in_progress',
    _page(const AuthInProgress()),
    settle: false,
  );
}
