import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_tokens.dart';

/// A form field with its label above the box, as in the Figma design. A
/// [trailing] widget sits inside the box at its end.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.enabled = true,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.trailing,
    this.helperText,
    this.inputFormatters,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? trailing;

  /// A hint under the box, shown while there is no error.
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: !obscureText,
          inputFormatters: inputFormatters,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helperText,
            // Figma colors this like a placeholder (#5F5E60), but that is
            // 2.97:1 on the background, below the 4.5:1 guideline.
            helperStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            // `suffix` is hidden until the field has focus; `suffixIcon` is not.
            suffixIcon: trailing,
            suffixIconConstraints: const BoxConstraints(),
          ),
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
        ),
      ],
    );
  }
}

/// A password field with a Show/Hide action.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.hint,
    this.label = 'Password',
    this.enabled = true,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.helperText,
  });

  final TextEditingController controller;
  final String hint;
  final String label;
  final bool enabled;
  final String? errorText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? helperText;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  var _visible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthTextField(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      enabled: widget.enabled,
      errorText: widget.errorText,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      helperText: widget.helperText,
      obscureText: !_visible,
      trailing: TextButton(
        onPressed: widget.enabled
            ? () => setState(() => _visible = !_visible)
            : null,
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          textStyle: theme.textTheme.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          minimumSize: const Size.square(AppSizes.minTapTarget),
        ),
        child: Text(_visible ? 'Hide' : 'Show'),
      ),
    );
  }
}
