import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/profile/domain/entities/profile.dart';
import 'package:stridequest/features/profile/domain/failures/profile_failure.dart';
import 'package:stridequest/features/profile/presentation/bloc/profile_info_bloc.dart';
import 'package:stridequest/features/profile/presentation/pages/profile_info_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/profile_fixtures.dart';

class _MockProfileInfoBloc extends MockBloc<ProfileInfoEvent, ProfileInfoState>
    implements ProfileInfoBloc {}

/// The page over a bloc stuck in [state].
Widget _page(ProfileInfoState state) {
  final bloc = _MockProfileInfoBloc();
  whenListen(bloc, const Stream<ProfileInfoState>.empty(), initialState: state);
  return BlocProvider<ProfileInfoBloc>.value(
    value: bloc,
    child: const ProfileInfoPage(),
  );
}

final _imperial = ProfileInfoForm.fromProfile(sampleProfile);

void main() {
  goldenScreen(
    'ProfileInfoPage imperial',
    'profile_info_page',
    _page(_imperial),
  );

  goldenScreen(
    'ProfileInfoPage metric',
    'profile_info_page_metric',
    _page(_imperial.copyWith(unitSystem: UnitSystem.metric)),
  );

  goldenScreen(
    'ProfileInfoPage empty',
    'profile_info_page_empty',
    _page(ProfileInfoForm.fromProfile(emptyProfile)),
  );

  goldenScreen(
    'ProfileInfoPage with errors and a save error',
    'profile_info_page_errors',
    _page(
      _imperial.copyWith(
        firstName: 'x' * 51,
        errors: {
          ProfileField.firstName: ProfileFieldError.tooLong,
          ProfileField.height: ProfileFieldError.outOfRange,
        },
        saveFailure: const ProfileFailure(ProfileFailureCode.network),
      ),
    ),
  );

  goldenScreen(
    'ProfileInfoPage saving',
    'profile_info_page_saving',
    _page(_imperial.copyWith(status: ProfileInfoStatus.saving)),
    settle: false,
  );

  goldenScreen(
    'ProfileInfoPage loading',
    'profile_info_page_loading',
    _page(const ProfileInfoLoading()),
    settle: false,
  );

  goldenScreen(
    'ProfileInfoPage load error',
    'profile_info_page_load_error',
    _page(
      const ProfileInfoLoadFailed(ProfileFailure(ProfileFailureCode.network)),
    ),
  );
}
