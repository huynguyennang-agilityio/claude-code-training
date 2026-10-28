import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_password_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/change_password_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_auth_bloc.dart';

/// The page over a bloc stuck in [state].
Widget _page(ChangePasswordState state) {
  final bloc = MockChangePasswordBloc();
  whenListen(
    bloc,
    const Stream<ChangePasswordState>.empty(),
    initialState: state,
  );
  return BlocProvider<ChangePasswordBloc>.value(
    value: bloc,
    child: const ChangePasswordPage(),
  );
}

const _ready = ChangePasswordState(
  current: 'run4medals',
  newPassword: 'newrun5medals',
  confirm: 'newrun5medals',
);

void main() {
  goldenScreen(
    'ChangePasswordPage',
    'change_password_page',
    _page(const ChangePasswordState()),
  );

  goldenScreen(
    'ChangePasswordPage ready to save',
    'change_password_page_ready',
    _page(_ready),
  );

  goldenScreen(
    'ChangePasswordPage with mismatch',
    'change_password_page_mismatch',
    _page(
      const ChangePasswordState(
        current: 'run4medals',
        newPassword: 'newrun5medals',
        confirm: 'newrun5',
      ),
    ),
  );

  goldenScreen(
    'ChangePasswordPage with field errors',
    'change_password_page_field_errors',
    _page(
      const ChangePasswordState(
        current: 'wrong123',
        newPassword: 'run4medals',
        confirm: 'run4medals',
        currentError: 'The current password is incorrect.',
        newError: 'New password must differ from the current password.',
      ),
    ),
  );

  goldenScreen(
    'ChangePasswordPage rate limited',
    'change_password_page_rate_limited',
    _page(
      const ChangePasswordState(
        current: 'run4medals',
        newPassword: 'newrun5medals',
        confirm: 'newrun5medals',
        banner:
            'Too many attempts. Wait a few minutes and try again. '
            'Try again in 14 minutes.',
      ),
    ),
  );

  goldenScreen(
    'ChangePasswordPage saving',
    'change_password_page_saving',
    _page(
      const ChangePasswordState(
        current: 'run4medals',
        newPassword: 'newrun5medals',
        confirm: 'newrun5medals',
        status: ChangePasswordStatus.saving,
      ),
    ),
    settle: false,
  );
}
