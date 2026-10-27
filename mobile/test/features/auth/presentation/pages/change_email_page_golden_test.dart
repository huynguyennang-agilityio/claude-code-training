import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_email_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/change_email_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_auth_bloc.dart';

/// The page over a bloc stuck in [state].
Widget _page(ChangeEmailState state) {
  final bloc = MockChangeEmailBloc();
  whenListen(bloc, const Stream<ChangeEmailState>.empty(), initialState: state);
  return BlocProvider<ChangeEmailBloc>.value(
    value: bloc,
    child: const ChangeEmailPage(),
  );
}

const _initial = ChangeEmailForm(
  currentEmail: 'runner@example.com',
  newEmail: 'runner@example.com',
);

const _ready = ChangeEmailForm(
  currentEmail: 'runner@example.com',
  newEmail: 'new.runner@example.com',
  password: 'run4medals',
);

void main() {
  goldenScreen('ChangeEmailPage', 'change_email_page', _page(_initial));

  goldenScreen(
    'ChangeEmailPage ready to save',
    'change_email_page_ready',
    _page(_ready),
  );

  goldenScreen(
    'ChangeEmailPage with field errors',
    'change_email_page_field_errors',
    _page(
      const ChangeEmailForm(
        currentEmail: 'runner@example.com',
        newEmail: 'taken@example.com',
        password: 'wrong123',
        emailError: 'An account with this email already exists.',
        passwordError: 'The current password is incorrect.',
      ),
    ),
  );

  goldenScreen(
    'ChangeEmailPage rate limited',
    'change_email_page_rate_limited',
    _page(
      const ChangeEmailForm(
        currentEmail: 'runner@example.com',
        newEmail: 'new.runner@example.com',
        password: 'run4medals',
        banner:
            'Too many attempts. Wait a few minutes and try again. '
            'Try again in 14 minutes.',
      ),
    ),
  );

  goldenScreen(
    'ChangeEmailPage saving',
    'change_email_page_saving',
    _page(
      const ChangeEmailForm(
        currentEmail: 'runner@example.com',
        newEmail: 'new.runner@example.com',
        password: 'run4medals',
        status: ChangeEmailStatus.saving,
      ),
    ),
    settle: false,
  );

  goldenScreen(
    'ChangeEmailPage loading',
    'change_email_page_loading',
    _page(const ChangeEmailLoading()),
    settle: false,
  );

  goldenScreen(
    'ChangeEmailPage load error',
    'change_email_page_load_error',
    _page(ChangeEmailLoadFailed(AuthFailure(AuthFailureCode.notAuthenticated))),
  );
}
