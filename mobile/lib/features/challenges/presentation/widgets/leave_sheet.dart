import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';

/// Asks whether to leave [challenge]. Completes with true when the user
/// confirms, and false (or null) when they keep it.
Future<bool> confirmLeave(BuildContext context, Challenge challenge) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    // Tall text sizes need more than the default half of the screen.
    isScrollControlled: true,
    builder: (context) => _LeaveSheet(type: challenge.type),
  );
  return confirmed ?? false;
}

class _LeaveSheet extends StatelessWidget {
  const _LeaveSheet({required this.type});

  final ChallengeType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Leave this challenge?', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You can join again while it is open, if no other '
                '${type.label.toLowerCase()} challenge overlaps it.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(true),
                // The sheet is lighter than the page: the plain error red would not
                // reach a contrast of 4.5 on it, so the label uses the light red.
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
                child: const Text('Leave challenge'),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                child: const Text('Keep it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
