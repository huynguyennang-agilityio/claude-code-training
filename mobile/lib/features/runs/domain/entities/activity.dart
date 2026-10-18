import 'package:equatable/equatable.dart';

import '../../../challenges/domain/entities/challenge.dart';
import 'health_access.dart';

/// What the health data says for today, as read on the device. A figure is null
/// when the metric is not allowed.
class ActivityReading extends Equatable {
  const ActivityReading({
    required this.readAt,
    this.steps,
    this.calories,
    this.distanceM,
    this.sleepMinutes,
  });

  final DateTime readAt;
  final int? steps;

  /// Active energy, in kilocalories.
  final int? calories;
  final int? distanceM;

  /// Time asleep in the night that ends today.
  final int? sleepMinutes;

  int? figure(HealthMetric metric) => switch (metric) {
    HealthMetric.steps => steps,
    HealthMetric.calories => calories,
    HealthMetric.distance => distanceM,
    HealthMetric.sleep => sleepMinutes,
  };

  @override
  List<Object?> get props => [readAt, steps, calories, distanceM, sleepMinutes];
}

/// One health record of steps (Apple Health or Health Connect), which counts
/// toward a challenge once, whatever the number of times it is synced.
class StepRecord extends Equatable {
  const StepRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.steps,
  });

  /// The id of the record on the device.
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int steps;

  @override
  List<Object?> get props => [id, startTime, endTime, steps];
}

/// The figures of one calendar day (the date on the device), as sent to the
/// backend. A null figure is left out.
class DailyFigures extends Equatable {
  const DailyFigures({
    required this.date,
    this.steps,
    this.calories,
    this.distanceM,
    this.sleepMinutes,
  });

  /// Only the year, month and day count.
  final DateTime date;
  final int? steps;
  final int? calories;
  final int? distanceM;
  final int? sleepMinutes;

  @override
  List<Object?> get props => [date, steps, calories, distanceM, sleepMinutes];
}

/// What the backend counted from a step sync.
class StepSyncResult extends Equatable {
  const StepSyncResult({required this.accepted, required this.ignored});

  final int accepted;
  final int ignored;

  @override
  List<Object?> get props => [accepted, ignored];
}

/// How far the caller is in a challenge (`docs/api/runs.md`).
class Progress extends Equatable {
  const Progress({
    required this.currentValue,
    required this.targetValue,
    required this.percent,
    required this.tracked,
    required this.started,
  });

  final int currentValue;
  final int targetValue;

  /// Whole percent of the target, at most 100.
  final int percent;

  /// False for a swim or cycle challenge: its progress is not counted yet.
  final bool tracked;

  /// The challenge's start date has passed.
  final bool started;

  @override
  List<Object?> get props => [
    currentValue,
    targetValue,
    percent,
    tracked,
    started,
  ];
}

/// A challenge the caller is in, as a card, with their progress.
class MyChallenge extends Equatable {
  const MyChallenge({required this.challenge, required this.progress});

  final ChallengeSummary challenge;
  final Progress progress;

  @override
  List<Object?> get props => [challenge, progress];
}

class MyChallengePage extends Equatable {
  const MyChallengePage({required this.items, this.nextCursor});

  final List<MyChallenge> items;

  /// Null on the last page.
  final String? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}
