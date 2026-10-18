import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/features/auth/data/datasources/fake_auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';

import 'helpers/in_memory_auth_local_data_source.dart';

void main() {
  testWidgets('a signed-out app opens on sign in', (tester) async {
    final repository = AuthRepositoryImpl(
      FakeAuthRemoteDataSource(),
      InMemoryAuthLocalDataSource(),
    );
    final authBloc = AuthBloc(repository)..add(const AuthStarted());
    addTearDown(authBloc.close);
    addTearDown(repository.dispose);

    await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
