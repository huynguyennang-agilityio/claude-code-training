import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';

/// "Joined" or "Paused": the caller's place in a challenge, as a small label.
class EnrollmentPill extends StatelessWidget {
  const EnrollmentPill({super.key, required this.status});

  final EnrollmentStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paused = status == EnrollmentStatus.paused;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          paused ? 'Paused' : 'Joined',
          style: theme.textTheme.labelSmall?.copyWith(
            color: paused
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
