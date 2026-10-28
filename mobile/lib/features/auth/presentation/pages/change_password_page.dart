import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/settings_form_layout.dart';
import '../bloc/change_password_bloc.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_text_field.dart';

/// The Password form (Figma `1:137`), without the "Forgot Password?" link:
/// password reset is out of scope for the MVP. Expects a
/// [ChangePasswordBloc]. It is pushed above the tab bar, so the back button
/// returns to the tab.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  static const path = '/profile/password';

  /// Where Save goes when the page is the only one on the stack (a deep link).
  static const _profilePath = '/profile';

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  // Seeded from the bloc, so a rebuilt page shows what was typed.
  late final _current = TextEditingController(text: _bloc.state.current);
  late final _new = TextEditingController(text: _bloc.state.newPassword);
  late final _confirm = TextEditingController(text: _bloc.state.confirm);

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  ChangePasswordBloc get _bloc => context.read<ChangePasswordBloc>();

  void _save() => _bloc.add(const ChangePasswordSubmitted());

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChangePasswordBloc, ChangePasswordState>(
      listenWhen: (before, after) =>
          after.status == ChangePasswordStatus.saved &&
          before.status != ChangePasswordStatus.saved,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Password changed')));
        // Pop through the router: the session update refreshes it, which
        // would rebuild a route that Navigator.maybePop had removed.
        context.canPop()
            ? context.pop()
            : context.go(ChangePasswordPage._profilePath);
      },
      builder: (context, form) {
        final editable = !form.isSaving;
        return SettingsFormLayout(
          title: 'Password',
          actions: [
            OutlinedButton(
              onPressed: form.canSave ? _save : null,
              child: form.isSaving
                  ? const SizedBox(
                      width: AppSpacing.md,
                      height: AppSpacing.md,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSpacing.xxs / 2,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
          children: [
            if (form.banner != null)
              AuthBanner(message: form.banner!, isError: true),
            PasswordField(
              controller: _current,
              label: 'Current Password',
              hint: 'Your current password',
              enabled: editable,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              scrollPadding: SettingsFormLayout.scrollPadding,
              errorText: form.currentError,
              onChanged: (text) =>
                  _bloc.add(ChangePasswordCurrentChanged(text)),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _new,
              label: 'New Password',
              hint: 'Your new password',
              helperText: ChangePasswordState.rule,
              enabled: editable,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              scrollPadding: SettingsFormLayout.scrollPadding,
              errorText: form.newError ?? form.ruleError,
              onChanged: (text) => _bloc.add(ChangePasswordNewChanged(text)),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _confirm,
              label: 'Confirm Password',
              hint: 'Repeat your new password',
              enabled: editable,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              scrollPadding: SettingsFormLayout.scrollPadding,
              errorText: form.mismatchError,
              onChanged: (text) =>
                  _bloc.add(ChangePasswordConfirmChanged(text)),
              // Done closes the keyboard, then saves if the form is valid.
              onSubmitted: (_) => _save(),
            ),
          ],
        );
      },
    );
  }
}
