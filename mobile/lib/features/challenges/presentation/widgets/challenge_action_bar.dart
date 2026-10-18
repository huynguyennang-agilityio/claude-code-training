import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';
import '../bloc/challenge_detail_bloc.dart';

/// The words shown when something stops the caller joining or resuming.
String blockedMessage(BlockingChallenge other) =>
    'You are already in “${other.title}”, which runs at the same time as this '
    'challenge. Finish, pause or leave it to join this one.';

const endedMessage = 'This challenge has ended.';

/// The fixed bar at the bottom of the detail: what the caller can do now.
///
/// - not in it: **Join Challenge**, disabled with the reason when it has ended
///   or an overlapping challenge is active;
/// - active: **Pause** and **Leave**;
/// - paused: **Resume** (disabled with the reason when it has ended or another
///   challenge is active now) and **Leave**.
class ChallengeActionBar extends StatelessWidget {
  const ChallengeActionBar({
    super.key,
    required this.challenge,
    required this.now,
    required this.busy,
    required this.onAction,
    required this.onLeave,
  });

  final Challenge challenge;
  final DateTime now;

  /// An action is running: every button waits.
  final bool busy;
  final ValueChanged<ChallengeAction> onAction;

  /// Leave asks for confirmation first, so the screen owns it.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enrollment = challenge.enrollment;
    final ended = challenge.hasEndedAt(now);
    final blocker = challenge.blockedBy;
    final reason = switch ((enrollment?.status, ended, blocker)) {
      (EnrollmentStatus.active, _, _) => null,
      (_, true, _) => endedMessage,
      (_, _, final BlockingChallenge other?) => blockedMessage(other),
      _ => null,
    };

    final Widget buttons;
    switch (enrollment?.status) {
      case null:
        buttons = FilledButton(
          onPressed: busy || reason != null
              ? null
              : () => onAction(ChallengeAction.join),
          child: _label(busy, 'Join Challenge'),
        );
      case EnrollmentStatus.active:
        buttons = Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => onAction(ChallengeAction.pause),
                child: const Text('Pause'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _leaveButton(theme)),
          ],
        );
      case EnrollmentStatus.paused:
        buttons = Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy || reason != null
                    ? null
                    : () => onAction(ChallengeAction.resume),
                child: const Text('Resume'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _leaveButton(theme)),
          ],
        );
    }

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reason != null) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.sizeOf(context).height *
                        AppChallengeSizes.actionBarReasonShare,
                  ),
                  child: SingleChildScrollView(child: _Reason(message: reason)),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              buttons,
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(bool busy, String text) => busy
      ? const SizedBox(
          width: AppChallengeSizes.metaIcon,
          height: AppChallengeSizes.metaIcon,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Text(text);

  Widget _leaveButton(ThemeData theme) => OutlinedButton(
    onPressed: busy ? null : onLeave,
    style: OutlinedButton.styleFrom(
      foregroundColor: theme.colorScheme.error,
      side: BorderSide(color: theme.colorScheme.error),
    ),
    child: const Text('Leave'),
  );
}

class _Reason extends StatelessWidget {
  const _Reason({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
    );
  }
}
