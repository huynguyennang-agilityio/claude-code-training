import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';
import '../bloc/challenges_bloc.dart';
import '../widgets/challenge_card.dart';
import '../widgets/type_filter_chips.dart';
import 'challenge_detail_page.dart';

/// The Challenges tab: search, the type chips and the list of challenge cards.
/// Expects a [ChallengesBloc] above it.
class ChallengesPage extends StatefulWidget {
  const ChallengesPage({
    super.key,
    this.searchDelay = const Duration(milliseconds: 350),
  });

  static const path = '/challenges';

  /// How long to wait after the last keystroke before searching.
  final Duration searchDelay;

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _filter(ChallengeType? type, String query) => context
      .read<ChallengesBloc>()
      .add(ChallengesFilterChanged(type: type, query: query));

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final type = context.read<ChallengesBloc>().state.type;
    _debounce = Timer(widget.searchDelay, () => _filter(type, value));
  }

  Future<void> _open(ChallengeSummary challenge) async {
    final bloc = context.read<ChallengesBloc>();
    await context.push(ChallengeDetailPage.locationFor(challenge.id));
    // What the user did there (joined, paused) shows on the card.
    if (!bloc.isClosed) bloc.add(const ChallengesRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Challenges')),
      body: BlocListener<ChallengesBloc, ChallengesState>(
        // A refused Join says why, once.
        listenWhen: (before, after) => before.noticeCount != after.noticeCount,
        listener: (context, state) {
          final message = state.notice?.message;
          if (message == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        child: Column(
          // Stretch, so the chip row starts at the left edge instead of shrinking and centring.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _search,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search challenges',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ValueListenableBuilder(
                    valueListenable: _search,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _debounce?.cancel();
                              _filter(
                                context.read<ChallengesBloc>().state.type,
                                '',
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
            BlocSelector<ChallengesBloc, ChallengesState, ChallengeType?>(
              selector: (state) => state.type,
              builder: (context, type) => TypeFilterChips(
                selected: type,
                onSelected: (selected) => _filter(selected, _search.text),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: BlocBuilder<ChallengesBloc, ChallengesState>(
                builder: (context, state) => switch (state.status) {
                  ChallengesStatus.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  ChallengesStatus.failed => _Message(
                    text: state.failure?.message ?? 'Something went wrong.',
                    actionLabel: 'Try again',
                    onAction: () => context.read<ChallengesBloc>().add(
                      const ChallengesStarted(),
                    ),
                  ),
                  ChallengesStatus.ready when state.items.isEmpty => _Message(
                    text: state.isFiltered
                        ? 'No challenges match your search.'
                        : 'No challenges are open yet. Check back soon.',
                    textStyle: theme.textTheme.bodyLarge,
                  ),
                  ChallengesStatus.ready => _List(state: state, onOpen: _open),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state, required this.onOpen});

  final ChallengesState state;
  final ValueChanged<ChallengeSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ChallengesBloc>();
    final items = state.items;
    final hasFooter =
        state.nextCursor != null || state.loadingMore || state.moreFailed;
    return RefreshIndicator(
      onRefresh: () async {
        bloc.add(const ChallengesRefreshed());
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.lg,
        ),
        itemCount: items.length + (hasFooter ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == items.length) {
            if (state.moreFailed) {
              return Center(
                child: TextButton(
                  onPressed: () => bloc.add(const ChallengesMoreRequested()),
                  child: const Text('Could not load more. Try again'),
                ),
              );
            }
            // The footer is built when the user scrolls to the end: ask for more.
            if (!state.loadingMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!bloc.isClosed) bloc.add(const ChallengesMoreRequested());
              });
            }
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final challenge = items[index];
          return ChallengeCard(
            challenge: challenge,
            onOpen: () => onOpen(challenge),
            joining: state.joiningId == challenge.id,
            onJoin: () => bloc.add(ChallengesJoinRequested(challenge.id)),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.actionLabel,
    this.onAction,
    this.textStyle,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: (textStyle ?? theme.textTheme.bodyLarge)?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
