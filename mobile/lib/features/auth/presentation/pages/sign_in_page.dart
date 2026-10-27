import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/failures/auth_failure.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/sign_in_bloc.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_form_layout.dart';
import '../widgets/auth_switch_link.dart';
import '../widgets/auth_text_field.dart';
import 'sign_up_page.dart';

/// The sign-in form. Sign in goes through the app-wide [AuthBloc]; on success
/// the router redirect leaves this page, so it never navigates itself.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  static const path = '/sign-in';

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Shown under a field until the user edits it, so a server message about
  /// the old value doesn't linger.
  Map<String, String> _fieldErrors = const {};
  AuthFailure? _lastFailure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SignInBloc>().add(
      SignInSubmitted(email: _email.text.trim(), password: _password.text),
    );
  }

  /// Takes the field messages of a new failure, once.
  void _adoptFailure(AuthFailure? failure) {
    if (identical(failure, _lastFailure)) return;
    _lastFailure = failure;
    _fieldErrors = failure?.fieldErrors ?? const {};
  }

  void _clearFieldError(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
    }
  }

  @override
  Widget build(BuildContext context) {
    // The session notice comes from the session bloc, not from this form.
    final sessionExpired = context.select<AuthBloc, bool>(
      (bloc) => switch (bloc.state) {
        AuthUnauthenticated(:final sessionExpired) => sessionExpired,
        _ => false,
      },
    );
    return BlocBuilder<SignInBloc, SignInState>(
      builder: (context, state) {
        final busy = state is SignInInProgress;
        final failure = state is SignInFailed ? state.failure : null;
        _adoptFailure(failure);

        return Form(
          key: _formKey,
          child: AuthFormLayout(
            title: 'Sign in',
            heading: 'Welcome back',
            subtitle: 'Sign in to continue your quests.',
            actions: [
              FilledButton(
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(
                        width: AppSpacing.md,
                        height: AppSpacing.md,
                        child: CircularProgressIndicator(
                          strokeWidth: AppSpacing.xxs / 2,
                        ),
                      )
                    : const Text('Sign in'),
              ),
              AuthSwitchLink(
                lead: 'New to StrideQuest?',
                action: 'Sign up',
                onPressed: busy ? null : () => context.go(SignUpPage.path),
              ),
            ],
            children: [
              if (failure != null)
                AuthBanner(message: failure.messageWithWait, isError: true)
              else if (sessionExpired)
                const AuthBanner(
                  message: 'Your session has expired. Sign in again.',
                  isError: false,
                ),
              AuthTextField(
                label: 'Email',
                hint: 'you@example.com',
                controller: _email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                errorText: _fieldErrors['email'],
                validator: _validateEmail,
                onChanged: (_) => _clearFieldError('email'),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _password,
                hint: 'Your password',
                enabled: !busy,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                errorText: _fieldErrors['password'],
                validator: _validatePassword,
                onChanged: (_) => _clearFieldError('password'),
                onSubmitted: (_) => busy ? null : _submit(),
              ),
            ],
          ),
        );
      },
    );
  }

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!_emailShape.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  static String? _validatePassword(String? value) {
    return (value == null || value.isEmpty) ? 'Enter your password.' : null;
  }
}
