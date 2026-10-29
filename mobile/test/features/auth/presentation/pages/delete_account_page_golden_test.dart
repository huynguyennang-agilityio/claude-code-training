import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/delete_account_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/delete_account_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_auth_bloc.dart';

/// The page over a bloc stuck in [state].
Widget _page(DeleteAccountState state) {
  final bloc = MockDeleteAccountBloc();
  whenListen(
    bloc,
    const Stream<DeleteAccountState>.empty(),
    initialState: state,
  );
  return BlocProvider<DeleteAccountBloc>.value(
    value: bloc,
    child: const DeleteAccountPage(),
  );
}

void main() {
  goldenScreen(
    'DeleteAccountPage',
    'delete_account_page',
    _page(const DeleteAccountState()),
  );

  goldenScreen(
    'DeleteAccountPage ready',
    'delete_account_page_ready',
    _page(const DeleteAccountState(password: 'run4medals')),
  );

  goldenScreen(
    'DeleteAccountPage submitting',
    'delete_account_page_submitting',
    _page(
      const DeleteAccountState(
        password: 'run4medals',
        status: DeleteAccountStatus.submitting,
      ),
    ),
    settle: false,
  );

  goldenScreen(
    'DeleteAccountPage too long',
    'delete_account_page_too_long',
    _page(DeleteAccountState(password: 'a' * 129)),
  );

  goldenScreen(
    'DeleteAccountPage incorrect password',
    'delete_account_page_incorrect_password',
    _page(
      DeleteAccountState(
        password: 'wrong123',
        status: DeleteAccountStatus.failure,
        failure: AuthFailure(AuthFailureCode.incorrectPassword),
      ),
    ),
  );

  goldenScreen(
    'DeleteAccountPage last admin',
    'delete_account_page_last_admin',
    _page(
      DeleteAccountState(
        password: 'run4medals',
        status: DeleteAccountStatus.failure,
        failure: AuthFailure(AuthFailureCode.lastAdmin),
      ),
    ),
  );

  goldenScreen(
    'DeleteAccountPage rate limited',
    'delete_account_page_rate_limited',
    _page(
      DeleteAccountState(
        password: 'run4medals',
        status: DeleteAccountStatus.failure,
        failure: AuthFailure(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 14),
        ),
      ),
    ),
  );
}
