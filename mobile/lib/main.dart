import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/runs/domain/services/health_sync.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
  getIt<HealthSync>().start();
  runApp(StrideQuestApp(authBloc: authBloc));
}
