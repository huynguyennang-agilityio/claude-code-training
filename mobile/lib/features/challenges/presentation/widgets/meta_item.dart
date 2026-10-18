import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// A small icon and a short line of secondary text: dates, goal, participants.
class MetaItem extends StatelessWidget {
  const MetaItem({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppChallengeSizes.metaIcon, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
