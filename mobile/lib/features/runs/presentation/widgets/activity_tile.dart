import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../challenges/presentation/format.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/health_access.dart';
import '../format.dart';

IconData _icon(HealthMetric metric) => switch (metric) {
  HealthMetric.steps => Icons.directions_walk,
  HealthMetric.calories => Icons.local_fire_department_outlined,
  HealthMetric.distance => Icons.place_outlined,
  HealthMetric.sleep => Icons.bedtime_outlined,
};

/// The figure and its unit: "5,490" "steps".
(String, String) _figure(HealthMetric metric, int value) => switch (metric) {
  HealthMetric.steps => (formatNumber(value), 'steps'),
  HealthMetric.calories => (formatNumber(value), 'kcal'),
  HealthMetric.distance => (formatDistanceKm(value), 'km'),
  HealthMetric.sleep => (formatSleepHours(value), 'hrs'),
};

/// One of the four tiles of the Active tab: the metric, today's figure, and when
/// it was read. A metric the user did not allow says so and is not sent.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.metric,
    required this.reading,
    required this.allowed,
  });

  final HealthMetric metric;
  final ActivityReading? reading;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = reading?.figure(metric);
    final shown = allowed && value != null;
    final (number, unit) = shown ? _figure(metric, value) : ('', '');
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final when = reading == null
        ? ''
        : 'Today at ${formatClock(reading!.readAt)}';
    final label = !allowed
        ? '${metric.label}, not allowed'
        : shown
        ? '${metric.label}, $number $unit, ${when.toLowerCase()}'
        : metric.label;
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _icon(metric),
                    size: AppActiveSizes.tileIcon,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      metric.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (!allowed) ...[
                Text('Not allowed', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text('Turn on in Settings', style: secondary),
              ] else if (shown) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(number, style: theme.textTheme.displaySmall),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(unit, style: secondary),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(when, style: secondary),
              ] else
                // Nothing read yet: keep the tile's height so the grid does not jump.
                Text('—', style: theme.textTheme.displaySmall),
            ],
          ),
        ),
      ),
    );
  }
}
