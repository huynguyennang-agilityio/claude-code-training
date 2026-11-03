part of 'health_notice_bloc.dart';

/// Which reminder about health access to show. [busy] while the system dialog
/// is up. [explainerCount] grows each time the bloc asks the screen to open the
/// explainer after a join, so the screen reacts once to each signal.
class HealthNoticeState extends Equatable {
  const HealthNoticeState({
    this.notice = HealthNotice.none,
    this.busy = false,
    this.explainerCount = 0,
  });

  final HealthNotice notice;
  final bool busy;
  final int explainerCount;

  HealthNoticeState copyWith({
    HealthNotice? notice,
    bool? busy,
    int? explainerCount,
  }) => HealthNoticeState(
    notice: notice ?? this.notice,
    busy: busy ?? this.busy,
    explainerCount: explainerCount ?? this.explainerCount,
  );

  @override
  List<Object?> get props => [notice, busy, explainerCount];
}
