import 'package:flutter/material.dart';

/// "New to StrideQuest? Sign up": a line of text and the action that opens the
/// other auth screen.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.lead,
    required this.action,
    required this.onPressed,
  });

  final String lead;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          lead,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            textStyle: theme.textTheme.labelSmall?.copyWith(
              decoration: TextDecoration.underline,
            ),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}
