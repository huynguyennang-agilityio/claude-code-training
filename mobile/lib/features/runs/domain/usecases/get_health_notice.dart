import 'package:injectable/injectable.dart';

import '../entities/health_access.dart';
import '../failures/runs_failure.dart';
import '../repositories/health_repository.dart';
import '../repositories/runs_repository.dart';

/// Decides which [HealthNotice] the user should see about health access. It
/// spans the health data and the backend, so it is a use case.
///
/// The status alone decides most notices (plan 030, assumption 12). Where the
/// platform cannot confirm access (iOS after the dialog), the notice is
/// [HealthNotice.noSteps] only when an active challenge has counted steps
/// for at least [quietDays] days and every one of the last [quietDays] days read 0 steps
/// (assumption 16), today included: once access is fixed, today's first steps
/// clear the notice. When that cannot be checked, nothing is shown.
@injectable
class GetHealthNotice {
  GetHealthNotice(this._health, this._runs);

  /// How many days of 0 steps point to a refused read.
  static const quietDays = 3;

  /// How long the user must have been in a challenge before 0 steps count.
  static const quietSpan = Duration(days: quietDays);

  final HealthRepository _health;
  final RunsRepository _runs;

  Future<HealthNotice> call({DateTime Function() clock = DateTime.now}) async {
    final access = await _health.checkAccess();
    switch (access.status) {
      case HealthAccessStatus.unavailable:
        return HealthNotice.install;
      case HealthAccessStatus.permanentlyDenied:
        return HealthNotice.settings;
      case HealthAccessStatus.denied:
        return HealthNotice.askable;
      case HealthAccessStatus.granted:
        return access.confirmed ? HealthNotice.none : _noSteps(clock);
    }
  }

  Future<HealthNotice> _noSteps(DateTime Function() clock) async {
    try {
      final counting = await _runs.earliestRunCounting();
      if (counting == null || clock().difference(counting) < quietSpan) {
        return HealthNotice.none;
      }
      final days = await _health.readDays({
        HealthMetric.steps,
      }, days: quietDays);
      final quiet =
          days.length == quietDays && days.every((d) => (d.steps ?? 0) == 0);
      return quiet ? HealthNotice.noSteps : HealthNotice.none;
    } on RunsFailure {
      return HealthNotice.none;
    } on HealthFailure {
      return HealthNotice.none;
    }
  }
}
