import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/health_access.dart';
import '../bloc/activity_bloc.dart';
import '../format.dart';
import 'activity_tile.dart';

/// The Active tab: the four tiles, what was last sent, and the Refresh data
/// button. Expects an [ActivityBloc].
class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ActivityBloc, ActivityState>(
      builder: (context, state) {
        final refused = [
          for (final metric in HealthMetric.values)
            if (!state.allowed.contains(metric)) metric.label.toLowerCase(),
        ];
        final note = state.isLoading
            ? 'Reading your health data and syncing it to StrideQuest.'
            : refused.isNotEmpty
            ? '${_list(refused)} ${refused.length == 1 ? 'is' : 'are'} not '
                  'allowed, so ${refused.length == 1 ? 'it is' : 'they are'} '
                  'not sent. Turn ${refused.length == 1 ? 'it' : 'them'} on in '
                  'Settings to see ${refused.length == 1 ? 'it' : 'them'} here.'
            : state.syncedAt != null
            ? 'Synced to StrideQuest at ${formatClock(state.syncedAt!)}. Tap '
                  'Refresh data to read your health data again.'
            : null;
        // The figures scroll (large text, a banner); the button stays in view.
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.error != null) ...[
                      _ErrorBanner(message: state.error!),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _Grid(state: state),
                    if (note != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        note,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: FilledButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => context.read<ActivityBloc>().add(
                          const ActivityRefreshRequested(),
                        ),
                  icon: const Icon(Icons.sync, size: AppActiveSizes.tileIcon),
                  label: Text(state.busy ? 'Syncing…' : 'Refresh data'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// "calories", "calories and sleep time", "calories, distance and sleep time".
  static String _list(List<String> names) {
    final text = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.state});

  final ActivityState state;

  @override
  Widget build(BuildContext context) {
    Widget tile(HealthMetric metric) => Expanded(
      child: ActivityTile(
        metric: metric,
        reading: state.reading,
        allowed: state.allowed.contains(metric),
      ),
    );
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(HealthMetric.steps),
              const SizedBox(width: AppSpacing.sm),
              tile(HealthMetric.calories),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(HealthMetric.distance),
              const SizedBox(width: AppSpacing.sm),
              tile(HealthMetric.sleep),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
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
