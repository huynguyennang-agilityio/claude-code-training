import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';

/// The filter row: All, Run, Swim, Cycle. A null [selected] is All.
class TypeFilterChips extends StatelessWidget {
  const TypeFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ChallengeType? selected;
  final ValueChanged<ChallengeType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(String label, ChallengeType? type) {
      final isSelected = type == selected;
      return Semantics(
        button: true,
        selected: isSelected,
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onSelected(type),
          showCheckmark: false,
          labelStyle: theme.textTheme.labelMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
          selectedColor: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surfaceContainerLow,
          side: BorderSide(color: theme.colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          chip('All', null),
          for (final type in ChallengeType.values) ...[
            const SizedBox(width: AppSpacing.xs),
            chip(type.label, type),
          ],
        ],
      ),
    );
  }
}
