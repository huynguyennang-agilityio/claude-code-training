import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/profile/presentation/pages/profile_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_auth_bloc.dart';

Widget _page() {
  final bloc = MockAuthBloc();
  whenListen(
    bloc,
    const Stream<AuthState>.empty(),
    initialState: AuthAuthenticated(
      AuthUser(
        id: 'user-1',
        email: 'runner@example.com',
        displayName: 'Lan Runner',
        createdAt: DateTime.utc(2026, 10, 13, 9, 55),
      ),
    ),
  );
  return BlocProvider<AuthBloc>.value(value: bloc, child: const ProfilePage());
}

void main() {
  goldenScreen('ProfilePage', 'profile_page', _page());
}
