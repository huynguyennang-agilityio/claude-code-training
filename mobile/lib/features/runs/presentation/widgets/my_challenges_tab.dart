import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../challenges/presentation/pages/challenge_detail_page.dart';
import '../../../challenges/presentation/pages/challenges_page.dart';
import '../bloc/my_challenges_bloc.dart';
import 'my_challenge_card.dart';

/// The My Challenges tab: the challenges the caller is in, with progress.
/// Expects a [MyChallengesBloc].
class MyChallengesTab extends StatelessWidget {
  const MyChallengesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyChallengesBloc, MyChallengesState>(
      builder: (context, state) => switch (state.status) {
        MyChallengesStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        MyChallengesStatus.failed => _Message(
          icon: Icons.error_outline,
          title: state.failure?.message ?? 'Something went wrong. Try again.',
          actionLabel: 'Try again',
          onAction: () =>
              context.read<MyChallengesBloc>().add(const MyChallengesStarted()),
        ),
        MyChallengesStatus.ready when state.items.isEmpty => _Message(
          icon: Icons.flag_outlined,
          title: 'No challenge in progress',
          text: 'Join a challenge and your progress will show up here.',
          actionLabel: 'Browse challenges',
          filled: true,
          onAction: () => context.go(ChallengesPage.path),
        ),
        MyChallengesStatus.ready => _List(state: state),
      },
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state});

  final MyChallengesState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MyChallengesBloc>();
    final items = state.items;
    final hasFooter =
        state.nextCursor != null || state.loadingMore || state.moreFailed;
    return RefreshIndicator(
      onRefresh: () async {
        bloc.add(const MyChallengesRefreshed());
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length + (hasFooter ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == items.length) {
            if (state.moreFailed) {
              return Center(
                child: TextButton(
                  onPressed: () => bloc.add(const MyChallengesMoreRequested()),
                  child: const Text('Could not load more. Try again'),
                ),
              );
            }
            // The footer is built when the user scrolls to the end: ask for more.
            if (!state.loadingMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!bloc.isClosed) bloc.add(const MyChallengesMoreRequested());
              });
            }
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = items[index];
          return MyChallengeCard(
            item: item,
            onOpen: () => context.push(
              ChallengeDetailPage.locationFor(item.challenge.id),
            ),
          );
        },
      ),
    );
  }
}

/// The empty and the error state: an icon, a title, a line, one button.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.text,
    required this.actionLabel,
    required this.onAction,
    this.filled = false,
  });

  final IconData icon;
  final String title;
  final String? text;
  final String actionLabel;
  final VoidCallback onAction;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: AppActiveSizes.gateIcon,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (text != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              filled
                  ? FilledButton(onPressed: onAction, child: Text(actionLabel))
                  : OutlinedButton(
                      onPressed: onAction,
                      child: Text(actionLabel),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
