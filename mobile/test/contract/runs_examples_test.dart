import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/runs/data/models/runs_models.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';

/// The shared examples of `docs/api/runs.md`. The backend tests compare their
/// responses with the same files, so a field that drifts on either side fails.
const _examplesDir = '../docs/api/examples/runs';

Map<String, dynamic> _example(String name) =>
    jsonDecode(File('$_examplesDir/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('the examples directory is found from the mobile folder', () {
    expect(Directory(_examplesDir).existsSync(), isTrue);
  });

  test('my_challenge_page parses into cards with progress', () {
    final page = MyChallengePageModel.fromJson(
      _example('my_challenge_page'),
    ).toEntity();

    expect(page.nextCursor, isNull);
    expect(page.items.map((item) => item.challenge.title), [
      'Hoan Kiem 50K Steps',
      'My Khe Bay 20 km',
    ]);
    final run = page.items.first;
    expect(run.challenge.enrollment?.status, EnrollmentStatus.active);
    expect(
      run.progress,
      const Progress(
        currentValue: 9000,
        targetValue: 50000,
        percent: 18,
        tracked: true,
        started: true,
      ),
    );
    final swim = page.items.last;
    expect(swim.challenge.enrollment?.status, EnrollmentStatus.paused);
    expect(swim.progress.tracked, isFalse);
    expect(swim.progress.started, isFalse);
  });

  test('step_sync_result parses its counts', () {
    final result = StepSyncResultModel.fromJson(
      _example('step_sync_result'),
    ).toEntity();

    expect((result.accepted, result.ignored), (2, 0));
  });

  test('a step record is sent as the request example shows', () {
    final example =
        (_example('step_sync_request')['samples'] as List).first
            as Map<String, dynamic>;
    final record = StepRecord(
      id: example['health_record_id'] as String,
      startTime: DateTime.parse(example['start_time'] as String),
      endTime: DateTime.parse(example['end_time'] as String),
      steps: example['steps'] as int,
    );

    expect(stepRecordJson(record).keys, example.keys);
    expect(stepRecordJson(record)['steps'], example['steps']);
  });

  test('a day is sent as the daily activity example shows', () {
    final days = (_example('daily_activity_request')['days'] as List)
        .cast<Map<String, dynamic>>();
    final full = days.first;
    final day = DailyFigures(
      date: DateTime.parse(full['date'] as String),
      steps: full['steps'] as int,
      calories: full['calories_kcal'] as int,
      distanceM: full['distance_m'] as int,
      sleepMinutes: full['sleep_minutes'] as int,
    );

    expect(dailyFiguresJson(day), full);
    expect(
      dailyFiguresJson(DailyFigures(date: DateTime(2026, 11, 3), steps: 5490)),
      days.last,
    );
  });
}
