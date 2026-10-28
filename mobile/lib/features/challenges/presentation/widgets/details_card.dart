import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';
import '../format.dart';
import 'markdown_text.dart';

/// The dates, the goal, and the Terms and Conditions that open in place.
class DetailsCard extends StatefulWidget {
  const DetailsCard({super.key, required this.challenge});

  final Challenge challenge;

  @override
  State<DetailsCard> createState() => _DetailsCardState();
}

class _DetailsCardState extends State<DetailsCard> {
  bool _termsOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenge = widget.challenge;
    final goalLabel = challenge.type.countsSteps
        ? 'Steps goal'
        : 'Distance goal';
    final hasTerms = challenge.terms.trim().isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          _Row(
            icon: Icons.calendar_today_outlined,
            text: formatFullRange(challenge.startsAt, challenge.endsAt),
          ),
          const Divider(height: 1),
          _Row(
            icon: Icons.flag_outlined,
            text:
                '$goalLabel: ${formatThreshold(challenge.type, challenge.target)}',
          ),
          if (hasTerms) ...[
            const Divider(height: 1),
            _Row(
              icon: Icons.assignment_outlined,
              text: 'Terms and Conditions',
              trailing: Icon(
                _termsOpen ? Icons.expand_less : Icons.chevron_right,
              ),
              onTap: () => setState(() => _termsOpen = !_termsOpen),
              expanded: _termsOpen,
            ),
            if (_termsOpen)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                ),
                child: MarkdownText(
                  challenge.terms,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.text,
    this.trailing,
    this.onTap,
    this.expanded,
  });

  final IconData icon;
  final String text;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
            ?trailing,
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
