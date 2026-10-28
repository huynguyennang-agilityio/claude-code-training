import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// "Challenge starts in" before [startsAt] and "Challenge ends in" while the
/// challenge is open, with days, hours, minutes and seconds that tick every
/// second. Nothing is shown once [endsAt] has passed.
class CountdownCard extends StatefulWidget {
  const CountdownCard({
    super.key,
    required this.startsAt,
    required this.endsAt,
    this.clock = DateTime.now,
  });

  final DateTime startsAt;
  final DateTime endsAt;

  /// The current time; tests pass a fixed one.
  final DateTime Function() clock;

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard> {
  Timer? _timer;
  late DateTime _now = widget.clock();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = widget.clock());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final started = !_now.isBefore(widget.startsAt);
    final target = started ? widget.endsAt : widget.startsAt;
    if (!_now.isBefore(widget.endsAt)) return const SizedBox.shrink();
    final left = target.difference(_now);
    final theme = Theme.of(context);
    final tiles = [
      ('Days', left.inDays),
      ('Hrs', left.inHours % 24),
      ('Min', left.inMinutes % 60),
      ('Sec', left.inSeconds % 60),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          started ? 'Challenge ends in' : 'Challenge starts in',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _Tile(label: tiles[i].$1, value: tiles[i].$2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: SizedBox(
              height: AppChallengeSizes.countdownTileHeight,
              width: double.infinity,
              child: Center(
                child: FittedBox(
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
