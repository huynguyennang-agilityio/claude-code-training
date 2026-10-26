import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/change_email_page.dart';
import '../../../auth/presentation/pages/change_password_page.dart';
import 'profile_info_page.dart';

/// The Profile tab: the user's initials in a round avatar, the list of account
/// screens (Profile, Email, Password) and Sign out under it.
///
/// Each row pushes its screen on the root navigator, above the tab bar.
/// Signing out only sends the event: the router redirect handles the
/// navigation that follows.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const path = '/profile';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AuthBloc>().state;
    final user = state is AuthAuthenticated ? state.user : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const SizedBox(height: AppSpacing.md),
                Center(child: _InitialsAvatar(initials: _initials(user))),
                const SizedBox(height: AppSpacing.lg),
                Material(
                  color: theme.colorScheme.surfaceContainerHighest,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Column(
                    children: [
                      _ProfileRow(
                        label: 'Profile',
                        onTap: () => context.push(ProfileInfoPage.path),
                      ),
                      const Divider(height: 1),
                      _ProfileRow(
                        label: 'Email',
                        onTap: () => context.push(ChangeEmailPage.path),
                      ),
                      const Divider(height: 1),
                      _ProfileRow(
                        label: 'Password',
                        onTap: () => context.push(ChangePasswordPage.path),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: () => context.read<AuthBloc>().add(
                    const AuthSignOutRequested(),
                  ),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Up to two capital letters from the display name (first letters of its
  /// first and last words), or the first letter of the email when the name is
  /// blank. Empty when nobody is signed in.
  static String _initials(AuthUser? user) {
    if (user == null) return '';
    final words = user.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      final email = user.email.trim();
      return email.isEmpty ? '' : email.substring(0, 1).toUpperCase();
    }
    final first = words.first.substring(0, 1);
    final last = words.length > 1 ? words.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: AppProfileSizes.avatar,
      height: AppProfileSizes.avatar,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primaryContainer,
      ),
      child: initials.isEmpty
          ? Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer)
          // The circle has a fixed size, so large text scales shrink the
          // initials to fit instead of clipping them.
          : ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FittedBox(
                  child: Text(
                    initials,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
