import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';
import '../format.dart';
import 'challenge_cover.dart';
import 'cover_tag.dart';
import 'meta_item.dart';

/// One challenge in the list: the cover with the type and the city, the title,
/// the dates and goal, how many joined, and the Join button (or Joined or
/// Paused when the caller is in it).
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onOpen,
    required this.onJoin,
  });

  final ChallengeSummary challenge;

  /// The card was tapped: open the detail.
  final VoidCallback onOpen;

  /// The Join button was tapped.
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = challenge.city;
    return Semantics(
      container: true,
      label: challenge.title,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChallengeCover(
                type: challenge.type,
                imageUrl: challenge.coverImageUrl,
                height: AppChallengeSizes.cardCoverHeight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      children: [
                        CoverTag(
                          icon: iconForType(challenge.type),
                          label: challenge.type.label,
                        ),
                        const Spacer(),
                        if (place != null)
                          Flexible(
                            child: CoverTag(
                              icon: Icons.place_outlined,
                              label: place,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        MetaItem(
                          icon: Icons.calendar_today_outlined,
                          text: formatShortRange(
                            challenge.startsAt,
                            challenge.endsAt,
                          ),
                        ),
                        MetaItem(
                          icon: Icons.flag_outlined,
                          text: formatGoal(challenge.type, challenge.target),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: MetaItem(
                            icon: Icons.person_outline,
                            text:
                                '${formatCount(challenge.participantCount)} joined',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _Action(challenge: challenge, onJoin: onJoin),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.challenge, required this.onJoin});

  final ChallengeSummary challenge;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enrollment = challenge.enrollment;
    if (enrollment != null) {
      final paused = enrollment.status == EnrollmentStatus.paused;
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
    return FilledButton(
      onPressed: onJoin,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppSizes.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        textStyle: theme.textTheme.labelSmall,
      ),
      child: const Text('Join'),
    );
  }
}
