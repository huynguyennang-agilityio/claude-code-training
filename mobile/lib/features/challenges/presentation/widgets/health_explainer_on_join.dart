import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../runs/presentation/bloc/health_notice_bloc.dart';
import '../../../runs/presentation/widgets/health_sheets.dart';
import '../bloc/challenge_detail_bloc.dart';
import '../bloc/challenges_bloc.dart';

/// True when [after] is the moment a Join from a card succeeded.
bool challengesJoined(ChallengesState before, ChallengesState after) =>
    after.joinedCount != before.joinedCount;

/// True when [after] is the moment a Join on the detail screen succeeded.
bool challengeDetailJoined(
  ChallengeDetailState before,
  ChallengeDetailState after,
) =>
    before is ChallengeDetailLoaded &&
    after is ChallengeDetailLoaded &&
    before.challenge.enrollment == null &&
    after.challenge.enrollment != null &&
    after.notice == null;

/// Opens the health explainer after a successful Join. Needs a [B] (the bloc
/// that joins) and a [HealthNoticeBloc] above it.
///
/// A join only tells [HealthNoticeBloc] (`HealthNoticeJoinPrompted`); the join
/// never waits for the answer. When the bloc decides the explainer is due it
/// signals, and this opens the sheet if the route is still on top. **Continue**
/// asks for access through the same bloc, like the banner does.
class HealthExplainerOnJoin<B extends StateStreamable<S>, S>
    extends StatelessWidget {
  const HealthExplainerOnJoin({
    super.key,
    required this.joined,
    required this.child,
  });

  /// Whether the change from `before` to `after` is a successful join.
  final bool Function(S before, S after) joined;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<B, S>(
          listenWhen: joined,
          listener: (context, _) => context.read<HealthNoticeBloc>().add(
            const HealthNoticeJoinPrompted(),
          ),
        ),
        BlocListener<HealthNoticeBloc, HealthNoticeState>(
          listenWhen: (before, after) =>
              before.explainerCount != after.explainerCount,
          listener: (context, _) => _onSignal(context),
        ),
      ],
      child: child,
    );
  }

  void _onSignal(BuildContext context) {
    final bloc = context.read<HealthNoticeBloc>();
    // The checks took a moment: the user may have gone to another screen.
    if (!_onTop(context)) {
      bloc.add(const HealthNoticeExplainerSkipped());
      return;
    }
    // Record it as shown now, so dismissing it by any means counts.
    bloc.add(const HealthNoticeExplainerShown());
    unawaited(_ask(context, bloc));
  }

  /// Whether the route of [context] is on top in every navigator around it:
  /// the list sits in a tab's navigator, while the detail screen is pushed on
  /// the root one above the whole shell.
  static bool _onTop(BuildContext context) {
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    var navigator = Navigator.maybeOf(context);
    while (navigator != null) {
      final outer = navigator.context;
      if (ModalRoute.of(outer)?.isCurrent == false) return false;
      // Not `Navigator.maybeOf(outer)`: from a navigator's own context it
      // returns that same navigator, and the loop would never end.
      navigator = outer.findAncestorStateOfType<NavigatorState>();
    }
    return true;
  }

  Future<void> _ask(BuildContext context, HealthNoticeBloc bloc) async {
    final accepted = await showHealthExplainer(context);
    // Use only the bloc after the sheet: the route, and its bloc, may have
    // closed while the sheet was up.
    if (accepted && !bloc.isClosed) {
      bloc.add(const HealthNoticeAccessRequested());
    }
  }
}
