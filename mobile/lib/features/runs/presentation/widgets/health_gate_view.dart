import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/health_access.dart';

/// What the user is told, and offered, for a status that stops the Active tab.
class _GateText {
  const _GateText(this.title, this.message, this.button);

  final String title;
  final String message;
  final String button;
}

const _texts = {
  HealthAccessStatus.denied: _GateText(
    'Allow health access',
    'Without health data StrideQuest cannot track your progress in '
        'challenges. Steps are required; the others are optional.',
    'Allow access',
  ),
  HealthAccessStatus.permanentlyDenied: _GateText(
    'Health access is off',
    'Steps are blocked for StrideQuest. Turn them on in Settings, or the app '
        'cannot track your progress in challenges.',
    'Open settings',
  ),
  HealthAccessStatus.unavailable: _GateText(
    'Health Connect needed',
    'Install Health Connect so StrideQuest can read your steps and track your '
        'progress in challenges.',
    'Install Health Connect',
  ),
};

/// Said under the button: that the figures are sent, which is the consent.
const healthConsentNote =
    'Your steps, calories, distance and sleep time are sent to StrideQuest to '
    'track your challenges. You can change this in Settings at any time.';

/// The Active tab while health data is not allowed: why, what is asked and the
/// one action that fixes it. Scrolls, so large text never overflows.
class HealthGateView extends StatelessWidget {
  const HealthGateView({
    super.key,
    required this.status,
    required this.busy,
    required this.onAction,
  });

  /// Never [HealthAccessStatus.granted]: the gate is not shown then.
  final HealthAccessStatus status;

  /// The system dialog is up: the button waits.
  final bool busy;

  /// The button: ask, open settings or install, by [status].
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _texts[status] ?? _texts[HealthAccessStatus.denied]!;
    return Scaffold(
      appBar: AppBar(title: const Text('Active')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.formMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerLow,
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: SizedBox(
                          width: AppActiveSizes.gateCircle,
                          height: AppActiveSizes.gateCircle,
                          child: Icon(
                            Icons.favorite_border,
                            size: AppActiveSizes.gateIcon,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      text.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    text.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _MetricList(),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: busy ? null : onAction,
                    child: busy
                        ? const SizedBox(
                            width: AppChallengeSizes.metaIcon,
                            height: AppChallengeSizes.metaIcon,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(text.button),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    healthConsentNote,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The four figures, and which of them is required.
class _MetricList extends StatelessWidget {
  const _MetricList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          for (final (index, metric) in HealthMetric.values.indexed) ...[
            if (index > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(metric.label, style: theme.textTheme.bodyLarge),
                  ),
                  Text(
                    metric.isRequired ? 'Required' : 'Optional',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
