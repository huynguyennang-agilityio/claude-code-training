import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/runs/data/health_sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
  getIt<HealthSyncService>().start();
  runApp(StrideQuestApp(authBloc: authBloc));
}
