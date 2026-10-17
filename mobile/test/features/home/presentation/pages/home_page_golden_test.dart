import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/home/presentation/pages/home_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_auth_bloc.dart';

Widget _home(AuthState state) {
  final bloc = MockAuthBloc();
  whenListen(bloc, const Stream<AuthState>.empty(), initialState: state);
  return BlocProvider<AuthBloc>.value(value: bloc, child: const HomePage());
}

void main() {
  goldenScreen(
    'HomePage, signed in',
    'home_page_signed_in',
    _home(
      AuthAuthenticated(
        AuthUser(
          id: 'user-1',
          email: 'runner@example.com',
          displayName: 'Lan Runner',
          createdAt: DateTime.utc(2026, 10, 13, 9, 55),
        ),
      ),
    ),
  );
}
