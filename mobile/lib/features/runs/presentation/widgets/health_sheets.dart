import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import 'health_gate_view.dart';
import 'health_metric_list.dart';

/// Shows [HealthExplainerSheet]. Completes with true when the user tapped
/// **Continue**, and false when they tapped **Not now** or dismissed it.
///
/// The sheet only asks; it never requests access itself. The caller does that,
/// either from the result or from [onContinue] (called once the sheet has
/// closed, so the system dialog does not stack on it). For example, with a
/// `HealthNoticeBloc` in scope:
/// `showHealthExplainer(context, onContinue: () => bloc.add(const HealthNoticeAccessRequested()))`.
/// Recording that it was shown (`HealthRepository.recordExplainerShown`) is
/// also the caller's job.
Future<bool> showHealthExplainer(
  BuildContext context, {
  VoidCallback? onContinue,
}) async {
  final accepted = await _showSheet(context, const HealthExplainerSheet());
  if (accepted) onContinue?.call();
  return accepted;
}

/// Shows [HealthSettingsSheet]. Completes with true when the user tapped
/// **Open settings**; [onOpenSettings] is then called once the sheet is closed.
Future<bool> showHealthSettings(
  BuildContext context, {
  VoidCallback? onOpenSettings,
}) async {
  final accepted = await _showSheet(context, const HealthSettingsSheet());
  if (accepted) onOpenSettings?.call();
  return accepted;
}

Future<bool> _showSheet(BuildContext context, Widget sheet) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    // Tall text sizes need more than the default half of the screen.
    isScrollControlled: true,
    builder: (context) => sheet,
  );
  return accepted ?? false;
}

/// Why the app wants health data and exactly what it asks for. Pops with true
/// on **Continue** and false on **Not now**.
class HealthExplainerSheet extends StatelessWidget {
  const HealthExplainerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SheetBody(
      title: 'Track your steps',
      message:
          'StrideQuest counts your steps toward your challenges. It asks for '
          'these figures; steps are required, the others are optional.',
      children: [
        const HealthMetricList(),
        const SizedBox(height: AppSpacing.md),
        Text(
          healthConsentNote,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SecondaryButton(
          label: 'Not now',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// Tells the user that only the Settings app can turn steps on. Pops with true
/// on **Open settings**.
class HealthSettingsSheet extends StatelessWidget {
  const HealthSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return _SheetBody(
      title: 'Check health access',
      message:
          'StrideQuest needs to read your steps to track your progress in '
          'challenges. Open Settings and make sure steps are allowed for '
          'StrideQuest.',
      children: [
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open settings'),
        ),
      ],
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.message,
    required this.children,
  });

  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      child: Text(label),
    );
  }
}
