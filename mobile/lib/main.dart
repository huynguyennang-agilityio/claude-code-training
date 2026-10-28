import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
  runApp(StrideQuestApp(authBloc: authBloc));
}
