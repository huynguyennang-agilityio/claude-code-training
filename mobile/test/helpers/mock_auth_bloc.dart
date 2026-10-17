import 'package:bloc_test/bloc_test.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
