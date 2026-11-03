import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../runs/domain/entities/health_access.dart';
import '../../../runs/domain/repositories/health_repository.dart';
import '../../../runs/domain/usecases/get_health_notice.dart';
import '../../../runs/presentation/bloc/health_notice_bloc.dart';
import '../../../runs/presentation/widgets/health_sheets.dart';
import '../bloc/challenge_detail_bloc.dart';
import '../bloc/challenges_bloc.dart';

/// True when [after] is the moment a Join from a card succeeded: the card's
/// request finished with no refusal and that challenge is now joined.
bool challengesJoined(ChallengesState before, ChallengesState after) {
  final id = before.joiningId;
  if (id == null || after.joiningId != null) return false;
  if (after.noticeCount != before.noticeCount) return false;
  return after.items.any((item) => item.id == id && item.enrollment != null);
}

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

/// Runs [promptHealthExplainer] once each time [joined] says a Join succeeded
/// in the [B] above it. The prompt starts after the join has finished and
/// nothing waits for it, so the answer never affects the join.
class HealthExplainerOnJoin<B extends StateStreamable<S>, S>
    extends StatelessWidget {
  const HealthExplainerOnJoin({
    super.key,
    required this.joined,
    required this.child,
  });

  final bool Function(S before, S after) joined;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<B, S>(
      listenWhen: joined,
      listener: (context, _) => unawaited(promptHealthExplainer(context)),
      child: child,
    );
  }
}

/// Opens the health explainer when the notice is askable and the explainer is
/// due, and records that it was shown the moment it opens. **Continue** asks
/// for access through [HealthNoticeBloc], like the banner does. Never throws:
/// a failing check just means no sheet.
Future<void> promptHealthExplainer(BuildContext context) async {
  try {
    final notice = await getIt<GetHealthNotice>()();
    if (notice != HealthNotice.askable) return;
    final health = getIt<HealthRepository>();
    if (!await health.explainerDue()) return;
    // The user may have left the screen while the checks ran.
    if (!context.mounted) return;
    await health.recordExplainerShown();
    if (!context.mounted) return;
    await showHealthExplainer(context, onContinue: _requestAccess);
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
  }
}

/// Runs the access request on a bloc of its own (the route has none), and
/// closes it once the system dialog is answered.
Future<void> _requestAccess() async {
  final bloc = getIt<HealthNoticeBloc>()
    ..add(const HealthNoticeAccessRequested());
  try {
    await bloc.stream.firstWhere((state) => !state.busy);
  } finally {
    await bloc.close();
  }
}
