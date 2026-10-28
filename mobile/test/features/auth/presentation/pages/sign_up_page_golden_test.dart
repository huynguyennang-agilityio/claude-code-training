import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/sign_up_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_up_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_auth_bloc.dart';

Widget _page(SignUpState state) {
  final bloc = MockSignUpBloc();
  whenListen(bloc, const Stream<SignUpState>.empty(), initialState: state);
  return BlocProvider<SignUpBloc>.value(value: bloc, child: const SignUpPage());
}

void main() {
  goldenScreen('SignUpPage', 'sign_up_page', _page(const SignUpInitial()));
  goldenScreen(
    'SignUpPage, email taken',
    'sign_up_page_email_taken',
    _page(SignUpFailed(AuthFailure(AuthFailureCode.emailTaken))),
  );
  goldenScreen(
    'SignUpPage, field errors',
    'sign_up_page_field_errors',
    _page(
      SignUpFailed(
        AuthFailure(
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
    _page(const SignUpInProgress()),
    settle: false,
  );
}
