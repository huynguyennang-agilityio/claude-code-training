import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

class StrideQuestApp extends StatefulWidget {
  const StrideQuestApp({required this.authBloc, super.key});

  final AuthBloc authBloc;

  @override
  State<StrideQuestApp> createState() => _StrideQuestAppState();
}

class _StrideQuestAppState extends State<StrideQuestApp> {
  late final GoRouter _router = createAppRouter(authBloc: widget.authBloc);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.authBloc,
      child: MaterialApp.router(
        title: 'StrideQuest',
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
