import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/runs/data/datasources/runs_remote_data_source.dart';
import 'package:stridequest/features/runs/data/models/runs_models.dart';
import 'package:stridequest/features/runs/data/repositories/runs_repository_impl.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';

class _FakeRemote implements RunsRemoteDataSource {
  final stepRequests = <List<Map<String, Object>>>[];
  final dayRequests = <List<Map<String, Object>>>[];
  final pages = <MyChallengePageModel>[];
  final cursors = <String?>[];

  @override
  Future<StepSyncResultModel> syncSteps(
    List<Map<String, Object>> samples,
  ) async {
    stepRequests.add(samples);
    return StepSyncResultModel(accepted: samples.length - 1, ignored: 1);
  }

  @override
  Future<void> saveDailyActivity(List<Map<String, Object>> days) async =>
      dayRequests.add(days);

  @override
  Future<MyChallengePageModel> myChallenges({
    String? cursor,
    int limit = 20,
  }) async {
    cursors.add(cursor);
    return pages[cursors.length - 1];
  }
}

StepRecord _record(int number) => StepRecord(
  id: 'r$number',
  startTime: DateTime.utc(2026, 11, 2, 6),
  endTime: DateTime.utc(2026, 11, 2, 7),
  steps: number + 1,
);

Map<String, dynamic> _item(String type, String status, String joined) => {
  'challenge': {
    'id': 1,
    'title': 'T',
    'type': type,
    'metric': 'steps',
    'target_value': 100,
    'cover_image_url': null,
    'city': null,
    'landmark': null,
    'status': 'published',
    'starts_at': '2026-10-01T00:00:00Z',
    'ends_at': '2026-12-01T00:00:00Z',
    'participant_count': 1,
    'enrollment': {'status': status, 'joined_at': joined},
  },
  'progress': {
    'current_value': 0,
    'target_value': 100,
    'percent': 0,
    'tracked': type == 'run',
    'started': true,
  },
};

MyChallengePageModel _page(List<Map<String, dynamic>> items, [String? next]) =>
    MyChallengePageModel.fromJson({'items': items, 'next_cursor': next});

void main() {
  late _FakeRemote remote;
  late RunsRepositoryImpl repository;

  setUp(() {
    remote = _FakeRemote();
    repository = RunsRepositoryImpl(remote);
  });

  group('syncSteps', () {
    test(
      'sends 500 records at most per request and adds the answers up',
      () async {
        final result = await repository.syncSteps([
          for (var i = 0; i < 1201; i++) _record(i),
        ]);

        expect(remote.stepRequests.map((r) => r.length), [500, 500, 201]);
        expect((result.accepted, result.ignored), (1198, 3));
        expect(remote.stepRequests.first.first, {
          'health_record_id': 'r0',
          'start_time': '2026-11-02T06:00:00.000Z',
          'end_time': '2026-11-02T07:00:00.000Z',
          'steps': 1,
        });
      },
    );

    test('no records means no request', () async {
      await repository.syncSteps(const []);

      expect(remote.stepRequests, isEmpty);
    });
  });

  group('saveDailyActivity', () {
    test('a day carries only the figures that exist', () async {
      await repository.saveDailyActivity([
        DailyFigures(
          date: DateTime(2026, 11, 2, 15, 30),
          steps: 5,
          sleepMinutes: 400,
        ),
        DailyFigures(date: DateTime(2026, 11, 3)),
      ]);

      expect(remote.dayRequests.single, [
        {'date': '2026-11-02', 'steps': 5, 'sleep_minutes': 400},
        {'date': '2026-11-03'},
      ]);
    });

    test('at most 7 days per request', () async {
      await repository.saveDailyActivity([
        for (var i = 1; i <= 9; i++) DailyFigures(date: DateTime(2026, 11, i)),
      ]);

      expect(remote.dayRequests.map((r) => r.length), [7, 2]);
    });
  });

  group('earliestRunJoin', () {
    test('is the earliest join among active run challenges', () async {
      remote.pages.add(
        _page([
          _item('run', 'active', '2026-10-20T08:00:00Z'),
          _item('run', 'active', '2026-10-10T08:00:00Z'),
          _item('run', 'paused', '2026-09-01T08:00:00Z'),
          _item('swim', 'active', '2026-08-01T08:00:00Z'),
        ]),
      );

      expect(await repository.earliestRunJoin(), DateTime.utc(2026, 10, 10, 8));
    });

    test('follows the cursor to the next page', () async {
      remote.pages
        ..add(_page([_item('run', 'active', '2026-10-20T08:00:00Z')], 'abc'))
        ..add(_page([_item('run', 'active', '2026-10-05T08:00:00Z')]));

      expect(await repository.earliestRunJoin(), DateTime.utc(2026, 10, 5, 8));
      expect(remote.cursors, [null, 'abc']);
    });

    test('is null with no active run challenge', () async {
      remote.pages.add(
        _page([_item('swim', 'active', '2026-10-20T08:00:00Z')]),
      );

      expect(await repository.earliestRunJoin(), isNull);
    });
  });

  test('myChallenges parses the page', () async {
    remote.pages.add(
      _page([_item('run', 'active', '2026-10-20T08:00:00Z')], 'next'),
    );

    final page = await repository.myChallenges();

    expect(page.nextCursor, 'next');
    expect(page.items.single.progress.tracked, isTrue);
    expect(page.items.single.challenge.title, 'T');
  });
}
