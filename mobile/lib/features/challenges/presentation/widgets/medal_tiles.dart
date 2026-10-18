import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';
import '../format.dart';

/// The medal checkpoints (bronze, silver, gold), one tile each with the amount
/// that earns it.
class MedalTiles extends StatelessWidget {
  const MedalTiles({super.key, required this.type, required this.medals});

  final ChallengeType type;
  final List<Medal> medals;

  @override
  Widget build(BuildContext context) {
    final sorted = [...medals]
      ..sort((a, b) => a.tier.index.compareTo(b.tier.index));
    // Equal-height tiles: the row takes the height of the tallest one.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _Tile(type: type, medal: sorted[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.type, required this.medal});

  final ChallengeType type;
  final Medal medal;

  Color get _tierColor => switch (medal.tier) {
    MedalTier.bronze => AppMedalColors.bronze,
    MedalTier.silver => AppMedalColors.silver,
    MedalTier.gold => AppMedalColors.gold,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = AppChallengeSizes.medalImage;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context) * 2).round();
    return Semantics(
      container: true,
      label:
          '${medal.tier.label} medal, ${formatThreshold(type, medal.threshold)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Image.network(
                  resizedImageUrl(medal.imageUrl, pixels),
                  fit: BoxFit.contain,
                  // A medal with no picture yet is a disc in its tier's color.
                  errorBuilder: (context, error, stack) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: _tierColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                medal.tier.label,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                formatThreshold(type, medal.threshold),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
