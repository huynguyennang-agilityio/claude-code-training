import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/sign_in_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const path = '/';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final textTheme = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            title: const Text('StrideQuest'),
            actions: [_AccountAction(state)],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state is AuthAuthenticated) ...[
                    Text(
                      'Welcome back, ${state.user.displayName}.',
                      style: textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
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

/// "Sign in" when signed out, a sign-out button when signed in. The sign-out
/// button is an icon, so it never outgrows the app bar when the text is large.
///
/// Signing out only sends the event: the router redirect handles any
/// navigation that follows.
class _AccountAction extends StatelessWidget {
  const _AccountAction(this.state);

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    if (state is AuthAuthenticated) {
      return IconButton(
        tooltip: 'Sign out',
        icon: const Icon(Icons.logout),
        onPressed: () =>
            context.read<AuthBloc>().add(const AuthSignOutRequested()),
      );
    }
    return TextButton(
      onPressed: state is AuthInProgress
          ? null
          // `go`, not `push`: after a successful sign in the router redirect goes to
          // Home, and it can't pop a page that was pushed on top of Home.
          : () => context.go(SignInPage.path),
      child: const Text('Sign in'),
    );
  }
}
