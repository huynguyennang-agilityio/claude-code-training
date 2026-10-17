import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const path = '/';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Home is for signed-in users. Until the stored session is read, or
        // while the router redirect to sign in runs, show progress instead of
        // content a signed-out user must not see.
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final textTheme = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            title: const Text('StrideQuest'),
            actions: const [_SignOutAction()],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome back, ${state.user.displayName}.',
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Every run is a quest.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The sign-out button, an icon so it never outgrows the app bar when the text
/// is large.
///
/// Signing out only sends the event: the router redirect handles any
/// navigation that follows.
class _SignOutAction extends StatelessWidget {
  const _SignOutAction();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () =>
          context.read<AuthBloc>().add(const AuthSignOutRequested()),
    );
  }
}
