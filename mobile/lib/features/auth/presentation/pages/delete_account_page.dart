import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/settings_form_layout.dart';
import '../bloc/delete_account_bloc.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_text_field.dart';

/// The Delete Account form: what is deleted, a note about Apple Health and
/// Health Connect, Current Password and the Delete account button. Expects a
/// [DeleteAccountBloc]. It is pushed above the tab bar.
///
/// It never navigates: on success the session ends and the router redirect
/// shows the sign-in page.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  static const path = '/profile/delete-account';

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  DeleteAccountBloc get _bloc => context.read<DeleteAccountBloc>();

  void _submit() => _bloc.add(const DeleteAccountSubmitted());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return BlocBuilder<DeleteAccountBloc, DeleteAccountState>(
      builder: (context, state) {
        final banner = state.banner;
        return SettingsFormLayout(
          title: 'Delete Account',
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: state.canSubmit ? _submit : null,
              child: state.isSubmitting
                  ? SizedBox(
                      width: AppSpacing.md,
                      height: AppSpacing.md,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSpacing.xxs / 2,
                        color: colors.onError,
                      ),
                    )
                  : const Text('Delete account'),
            ),
          ],
          children: [
            if (banner != null) AuthBanner(message: banner, isError: true),
            Text(
              'This permanently deletes your StrideQuest account: your '
              'profile, the challenges you joined, your runs, medals, and the '
              'steps and activity synced from Apple Health or Health Connect. '
              "This can't be undone.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  'Your data in Apple Health or Health Connect stays on your '
                  'phone. We only delete our copy.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _password,
              label: 'Current Password',
              hint: 'Your current password',
              enabled: !state.isSubmitting,
              errorText: state.lengthError,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              scrollPadding: SettingsFormLayout.scrollPadding,
              onChanged: (text) =>
                  _bloc.add(DeleteAccountPasswordChanged(text)),
              // Done closes the keyboard, then deletes if a password is typed.
              onSubmitted: (_) => _submit(),
            ),
          ],
        );
      },
    );
  }
}
