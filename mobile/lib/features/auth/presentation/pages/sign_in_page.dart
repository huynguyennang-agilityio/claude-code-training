import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../domain/failures/auth_failure.dart';
import '../bloc/auth_bloc.dart';

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
  var _showPassword = false;

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
    context.read<AuthBloc>().add(
      AuthSignInRequested(email: _email.text.trim(), password: _password.text),
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
    final theme = Theme.of(context);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final busy = state is AuthInProgress;
        final unauthenticated = state is AuthUnauthenticated ? state : null;
        _adoptFailure(unauthenticated?.failure);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sign in'),
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              // The page was reached with `go`, so there is nothing to pop.
              onPressed: () => context.go(HomePage.path),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.formMaxWidth,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome back',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (unauthenticated?.failure case final failure?)
                          _Banner(
                            message: _failureMessage(failure),
                            isError: true,
                          )
                        else if (unauthenticated?.sessionExpired ?? false)
                          const _Banner(
                            message: 'Your session has expired. Sign in again.',
                            isError: false,
                          ),
                        TextFormField(
                          controller: _email,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            errorText: _fieldErrors['email'],
                          ),
                          validator: _validateEmail,
                          onChanged: (_) => _clearFieldError('email'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _password,
                          enabled: !busy,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            errorText: _fieldErrors['password'],
                            suffixIcon: IconButton(
                              tooltip: _showPassword
                                  ? 'Hide password'
                                  : 'Show password',
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                            ),
                          ),
                          validator: _validatePassword,
                          onChanged: (_) => _clearFieldError('password'),
                          onFieldSubmitted: (_) => busy ? null : _submit(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
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

/// A message above the form. Errors are announced to screen readers.
class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isError ? colors.errorContainer : colors.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isError
                    ? colors.onErrorContainer
                    : colors.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
