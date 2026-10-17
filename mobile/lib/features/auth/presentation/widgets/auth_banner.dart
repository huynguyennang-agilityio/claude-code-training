import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// A message above an auth form. Errors are announced to screen readers.
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, required this.message, required this.isError});

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
