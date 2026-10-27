import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/settings_form_layout.dart';
import '../bloc/change_email_bloc.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_text_field.dart';

/// The Email form (Figma `1:163`) with a Current Password field. Expects a
/// [ChangeEmailBloc]. It is pushed above the tab bar, so the back button
/// returns to the tab.
class ChangeEmailPage extends StatelessWidget {
  const ChangeEmailPage({super.key});

  static const path = '/profile/email';

  static const _title = 'Email';

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChangeEmailBloc, ChangeEmailState>(
      listenWhen: (before, after) =>
          after is ChangeEmailForm &&
          after.status == ChangeEmailStatus.saved &&
          !(before is ChangeEmailForm &&
              before.status == ChangeEmailStatus.saved),
      listener: (context, state) {
        final email = (state as ChangeEmailForm).trimmedEmail.toLowerCase();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Email changed to $email')));
        GoRouter.of(context).pop();
      },
      builder: (context, state) => switch (state) {
        ChangeEmailLoading() => const SettingsFormLayout(
          title: _title,
          actions: [],
          children: [
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        ChangeEmailLoadFailed(:final failure) => SettingsFormLayout(
          title: _title,
          actions: const [],
          children: [
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => context.read<ChangeEmailBloc>().add(
                const ChangeEmailStarted(),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
        final ChangeEmailForm form => _EmailForm(form: form),
      },
    );
  }
}

/// The loaded form. It owns the text controllers; what the user types goes to
/// the bloc, which decides when Save is on.
class _EmailForm extends StatefulWidget {
  const _EmailForm({required this.form});

  final ChangeEmailForm form;

  @override
  State<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<_EmailForm> {
  late final _email = TextEditingController(text: widget.form.newEmail);
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  ChangeEmailBloc get _bloc => context.read<ChangeEmailBloc>();

  void _save() => _bloc.add(const ChangeEmailSubmitted());

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final editable = !form.isSaving;
    final theme = Theme.of(context);

    return SettingsFormLayout(
      title: ChangeEmailPage._title,
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
        Text(
          'This will change the account email you use to sign in with '
          'StrideQuest and where you receive notifications.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'Email address',
          hint: 'you@example.com',
          controller: _email,
          enabled: editable,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          scrollPadding: SettingsFormLayout.scrollPadding,
          errorText: form.emailError ?? form.formatError,
          onChanged: (text) => _bloc.add(ChangeEmailEmailChanged(text)),
        ),
        const SizedBox(height: AppSpacing.md),
        PasswordField(
          controller: _password,
          label: 'Current Password',
          hint: 'Your current password',
          enabled: editable,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          scrollPadding: SettingsFormLayout.scrollPadding,
          errorText: form.passwordError,
          onChanged: (text) => _bloc.add(ChangeEmailPasswordChanged(text)),
          // Done closes the keyboard, then saves if the form is valid.
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}
