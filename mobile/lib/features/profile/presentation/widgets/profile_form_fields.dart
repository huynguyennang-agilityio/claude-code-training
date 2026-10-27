import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/settings_form_layout.dart';

/// The label above a field's box, as in the Figma design.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The error line under a field, announced to screen readers.
class FieldErrorText extends StatelessWidget {
  const FieldErrorText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

/// A text field with its label above the box. A [suffix] (a unit such as
/// `cm`) sits inside the box at its end. The error line is [errorText].
class ProfileTextField extends StatelessWidget {
  const ProfileTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.enabled = true,
    this.errorText,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.showError = true,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final String? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// False when the caller shows [errorText] itself (two fields in a row share
  /// one error line).
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          autocorrect: false,
          style: theme.textTheme.bodyLarge,
          // Leaves room under the focused field for its error line.
          scrollPadding: SettingsFormLayout.scrollPadding,
          decoration: InputDecoration(
            hintText: hint,
            errorText: showError ? errorText : null,
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      suffix!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
            suffixIconConstraints: const BoxConstraints(),
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}

/// A field that opens a picker instead of taking text. [value] is the text
/// shown, or null for [hint]. With a value, a clear button empties it
/// (the profile fields are optional).
class ProfilePickerField extends StatelessWidget {
  const ProfilePickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onTap,
    required this.onClear,
    this.enabled = true,
    this.errorText,
  });

  final String label;
  final String hint;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        Stack(
          alignment: AlignmentDirectional.centerEnd,
          children: [
            Semantics(
              button: true,
              enabled: enabled,
              label: label,
              value: value ?? hint,
              onTap: enabled ? onTap : null,
              excludeSemantics: true,
              child: InkWell(
                onTap: enabled ? onTap : null,
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: InputDecorator(
                  decoration: InputDecoration(
                    enabled: enabled,
                    // With a value the clear button sits over this space.
                    suffixIcon: hasValue
                        ? const SizedBox(width: AppSizes.minTapTarget)
                        : Icon(
                            Icons.expand_more,
                            color: colors.onSurfaceVariant,
                          ),
                    suffixIconConstraints: const BoxConstraints(),
                  ),
                  child: Text(
                    value ?? hint,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: hasValue ? null : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            if (hasValue)
              // Out of the focus order, so Next on the keyboard goes from one
              // text field to the next, past the pickers. It is still tappable
              // and read out by screen readers.
              ExcludeFocus(
                child: IconButton(
                  tooltip: 'Clear $label',
                  onPressed: enabled ? onClear : null,
                  icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
        if (errorText != null) FieldErrorText(errorText!),
      ],
    );
  }
}
