part of 'health_notice_bloc.dart';

/// Which reminder about health access to show. [busy] while the system dialog
/// is up.
class HealthNoticeState extends Equatable {
  const HealthNoticeState({this.notice = HealthNotice.none, this.busy = false});

  final HealthNotice notice;
  final bool busy;

  @override
  List<Object?> get props => [notice, busy];
}
