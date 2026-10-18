import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../challenges/domain/entities/challenge.dart';
import '../../../challenges/presentation/format.dart';
import '../../../challenges/presentation/widgets/challenge_cover.dart';
import '../../../challenges/presentation/widgets/cover_tag.dart';
import '../../../challenges/presentation/widgets/enrollment_pill.dart';
import '../../../challenges/presentation/widgets/meta_item.dart';
import '../../domain/entities/activity.dart';

/// A challenge the caller is in: the cover, the title, the dates, and where they
/// stand.
///
/// - a run in progress: a bar, "Goal n%" and the amount;
/// - not started yet: "Starts Nov 1", with no progress;
/// - a swim or a ride: a note, because their progress is not counted yet;
/// - paused: the **Paused** pill.
class MyChallengeCard extends StatelessWidget {
  const MyChallengeCard({super.key, required this.item, required this.onOpen});

  final MyChallenge item;

  /// The card was tapped: open the detail.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenge = item.challenge;
    final progress = item.progress;
    final place = challenge.city;
    final paused = challenge.enrollment?.status == EnrollmentStatus.paused;
    final showsBar = progress.tracked && progress.started;
    return Semantics(
      container: true,
      button: true,
      label: [
        challenge.title,
        if (paused) 'paused',
        if (!progress.started) 'starts ${formatDay(challenge.startsAt)}',
        if (showsBar) 'goal ${progress.percent} percent',
      ].join(', '),
      excludeSemantics: true,
      onTap: onOpen,
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
                        const MetaItem(
                          icon: Icons.person_outline,
                          text: 'Solo',
                        ),
                      ],
                    ),
                    if (showsBar) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _Bar(progress: progress, type: challenge.type),
                    ],
                    if (paused || !progress.started || !progress.tracked) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _Status(
                        paused: paused,
                        startsAt: progress.started ? null : challenge.startsAt,
                        note: progress.tracked
                            ? null
                            : 'Progress for ${challenge.type.label.toLowerCase()} '
                                  'comes soon',
                      ),
                    ],
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

class _Bar extends StatelessWidget {
  const _Bar({required this.progress, required this.type});

  final Progress progress;
  final ChallengeType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: progress.percent / 100,
            minHeight: AppChallengeSizes.progressBar,
            backgroundColor: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              'Goal ${progress.percent}%',
              style: theme.textTheme.labelSmall,
            ),
            const Spacer(),
            Flexible(
              child: Text(
                '${formatNumber(progress.currentValue)} / '
                '${formatGoal(type, progress.targetValue)}',
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Paused", "Starts Nov 1", and the note for a type that is not counted yet.
class _Status extends StatelessWidget {
  const _Status({required this.paused, this.startsAt, this.note});

  final bool paused;
  final DateTime? startsAt;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (paused) const EnrollmentPill(status: EnrollmentStatus.paused),
        if (startsAt != null) _StartsPill(startsAt: startsAt!),
        if (note != null)
          Text(
            note!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _StartsPill extends StatelessWidget {
  const _StartsPill({required this.startsAt});

  final DateTime startsAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          'Starts ${formatDay(startsAt)}',
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}
