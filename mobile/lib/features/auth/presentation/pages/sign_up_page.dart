import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/failures/auth_failure.dart';
import '../bloc/sign_up_bloc.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_form_layout.dart';
import '../widgets/auth_switch_link.dart';
import '../widgets/auth_text_field.dart';
import 'sign_in_page.dart';

/// The sign-up form. Sign up goes through the app-wide [AuthBloc], which signs
/// the new user in; the router redirect then leaves this page, so it never
/// navigates itself after success.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  static const path = '/sign-up';

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Shown under a field until the user edits it, so a server message about
  /// the old value doesn't linger. Keys are the API field names.
  Map<String, String> _fieldErrors = const {};
  AuthFailure? _lastFailure;

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SignUpBloc>().add(
      SignUpSubmitted(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _displayName.text.trim(),
      ),
    );
  }

  /// Takes the field messages of a new failure, once. A taken email is shown
  /// on the email field, not in the banner.
  void _adoptFailure(AuthFailure? failure) {
    if (identical(failure, _lastFailure)) return;
    _lastFailure = failure;
    _fieldErrors = switch (failure) {
      null => const {},
      AuthFailure(code: AuthFailureCode.emailTaken) => {
        'email': failure.message,
      },
      _ => failure.fieldErrors,
    };
  }

  void _clearFieldError(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SignUpBloc, SignUpState>(
      builder: (context, state) {
        final busy = state is SignUpInProgress;
        final failure = state is SignUpFailed ? state.failure : null;
        _adoptFailure(failure);

        return Form(
          key: _formKey,
          child: AuthFormLayout(
            title: 'Sign up',
            // The page was reached with `go`, so there is nothing to pop.
            onBack: () => context.go(SignInPage.path),
            heading: 'Create your account',
            subtitle: 'Start your first quest in under a minute.',
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
                    : const Text('Create account'),
              ),
              AuthSwitchLink(
                lead: 'Already have an account?',
                action: 'Sign in',
                onPressed: busy ? null : () => context.go(SignInPage.path),
              ),
            ],
            children: [
              if (failure != null && failure.code != AuthFailureCode.emailTaken)
                AuthBanner(message: _failureMessage(failure), isError: true),
              AuthTextField(
                label: 'Display name',
                hint: 'How runners will see you',
                controller: _displayName,
                enabled: !busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.nickname],
                errorText: _fieldErrors['display_name'],
                validator: _validateDisplayName,
                onChanged: (_) => _clearFieldError('display_name'),
              ),
              const SizedBox(height: AppSpacing.md),
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
                hint: '8–128 characters',
                helperText: 'Use at least one letter and one number.',
                enabled: !busy,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
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
  static final _letter = RegExp('[A-Za-z]');
  static final _digit = RegExp('[0-9]');
  static final _controlCharacter = RegExp(r'[\x00-\x1f\x7f]');

  static String? _validateDisplayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter a name.';
    if (name.length > 50 || _controlCharacter.hasMatch(name)) {
      return 'Use up to 50 characters, with no control characters.';
    }
    return null;
  }

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (email.length > 254 || !_emailShape.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter a password.';
    if (password.length < 8 ||
        password.length > 128 ||
        !password.contains(_letter) ||
        !password.contains(_digit)) {
      return 'Use 8–128 characters with a letter and a number.';
    }
    return null;
  }

  /// The failure's message, plus how long to wait when the backend said so.
  static String _failureMessage(AuthFailure failure) {
    final wait = failure.retryAfter;
    if (failure.code != AuthFailureCode.rateLimited || wait == null) {
      return failure.message;
    }
    final minutes = (wait.inSeconds / 60).ceil();
    return '${failure.message} Try again in $minutes '
        '${minutes == 1 ? 'minute' : 'minutes'}.';
  }
}
