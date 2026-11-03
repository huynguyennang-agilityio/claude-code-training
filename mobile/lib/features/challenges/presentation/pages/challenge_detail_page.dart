import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';
import '../bloc/challenge_detail_bloc.dart';
import '../format.dart';
import '../widgets/challenge_action_bar.dart';
import '../widgets/challenge_cover.dart';
import '../widgets/countdown_card.dart';
import '../widgets/details_card.dart';
import '../widgets/enrollment_pill.dart';
import '../widgets/leave_sheet.dart';
import '../widgets/markdown_text.dart';
import '../widgets/medal_tiles.dart';
import '../widgets/meta_item.dart';

/// One challenge: the cover, what it is, the countdown, the details, who is in
/// it, the medal checkpoints and the rules. Expects a [ChallengeDetailBloc].
class ChallengeDetailPage extends StatelessWidget {
  const ChallengeDetailPage({
    super.key,
    required this.challengeId,
    this.clock = DateTime.now,
  });

  /// The route pattern. The id is the only thing the route carries.
  static const path = '/challenges/:id';

  static String locationFor(int id) => '/challenges/$id';

  final int challengeId;

  /// The current time; tests pass a fixed one.
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChallengeDetailBloc, ChallengeDetailState>(
      // A refused action says why, once.
      listenWhen: (before, after) =>
          after is ChallengeDetailLoaded &&
          after.notice != null &&
          (before is! ChallengeDetailLoaded || before.notice != after.notice),
      listener: (context, state) {
        final notice = (state as ChallengeDetailLoaded).notice;
        if (notice == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice.message)));
      },
      builder: (context, state) => Scaffold(
        body: switch (state) {
          ChallengeDetailLoading() => const _Frame(
            child: Center(child: CircularProgressIndicator()),
          ),
          ChallengeDetailFailed(:final failure) => _Frame(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      failure.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: () => context.read<ChallengeDetailBloc>().add(
                        ChallengeDetailStarted(challengeId),
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ChallengeDetailLoaded(:final challenge) => _Detail(
            challenge: challenge,
            clock: clock,
          ),
        },
        bottomNavigationBar: switch (state) {
          ChallengeDetailLoaded(:final challenge, :final busy) =>
            ChallengeActionBar(
              challenge: challenge,
              now: clock(),
              busy: busy,
              onAction: (action) => context.read<ChallengeDetailBloc>().add(
                ChallengeActionRequested(action),
              ),
              onLeave: () async {
                final bloc = context.read<ChallengeDetailBloc>();
                if (await confirmLeave(context, challenge) && !bloc.isClosed) {
                  bloc.add(
                    const ChallengeActionRequested(ChallengeAction.leave),
                  );
                }
              },
            ),
          _ => null,
        },
      ),
    );
  }
}

/// A back button above [child], for the states that have no cover yet.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackButton(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () =>
          context.canPop() ? context.pop() : context.go('/challenges'),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.challenge, required this.clock});

  final Challenge challenge;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = challenge.landmark ?? challenge.city;
    final badge = challenge.type.countsSteps ? 'STEP GOAL' : 'DISTANCE GOAL';
    final badgeValue = challenge.type.countsSteps
        ? formatCount(challenge.target).toLowerCase()
        : '${formatKm(challenge.target)} km';
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ChallengeCover(
          type: challenge.type,
          imageUrl: challenge.coverImageUrl,
          height: AppChallengeSizes.detailCoverHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, theme.colorScheme.surface],
                  ),
                ),
              ),
              const SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _BackButton(),
                ),
              ),
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Semantics(
                  label: '$badge $badgeValue'.toLowerCase(),
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            badge,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            badgeValue,
                            style: theme.textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        MetaItem(
                          icon: iconForType(challenge.type),
                          text: challenge.type.label,
                        ),
                        const MetaItem(
                          icon: Icons.person_outline,
                          text: 'Solo',
                        ),
                        if (place != null)
                          MetaItem(icon: Icons.place_outlined, text: place),
                      ],
                    ),
                  ),
                  if (challenge.enrollment case final enrollment?) ...[
                    const SizedBox(width: AppSpacing.xs),
                    EnrollmentPill(status: enrollment.status),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(challenge.title, style: theme.textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatShortRange(challenge.startsAt, challenge.endsAt),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CountdownCard(
                startsAt: challenge.startsAt,
                endsAt: challenge.endsAt,
                clock: clock,
              ),
              const SizedBox(height: AppSpacing.lg),
              DetailsCard(challenge: challenge),
              const SizedBox(height: AppSpacing.lg),
              Text('Participants', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              _Participants(count: challenge.participantCount),
              if (challenge.medals.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Medals', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                MedalTiles(type: challenge.type, medals: challenge.medals),
              ],
              if (challenge.description.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _Rules(description: challenge.description),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }
}

/// How many joined. Other users' names and photos are not shown: that needs
/// avatars and a privacy decision, so the row has placeholders and the count.
class _Participants extends StatelessWidget {
  const _Participants({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const shown = 5;
    const size = AppChallengeSizes.avatar;
    const step = size - AppChallengeSizes.avatarOverlap;
    const stackWidth = step * (shown - 1) + size;
    return Row(
      children: [
        if (count > 0)
          ExcludeSemantics(
            child: SizedBox(
              width: stackWidth,
              height: size,
              child: Stack(
                children: [
                  for (var i = 0; i < shown; i++)
                    Positioned(
                      left: step * i,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerHighest,
                          border: Border.all(color: theme.colorScheme.surface),
                        ),
                        child: const SizedBox(width: size, height: size),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (count > 0) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            count == 0 ? 'Be the first to join' : '+${formatNumber(count)}',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Challenge rules', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              MarkdownText(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
