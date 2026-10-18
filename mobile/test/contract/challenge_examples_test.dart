import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/challenges/data/models/challenge_models.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';

/// The shared examples of `docs/api/challenges.md`. The backend tests compare
/// their responses with the same files, so a field that drifts on either side
/// fails.
const _examplesDir = '../docs/api/examples/challenges';

Map<String, dynamic> _example(String name) =>
    jsonDecode(File('$_examplesDir/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('the examples directory is found from the mobile folder', () {
    expect(Directory(_examplesDir).existsSync(), isTrue);
  });

  test('challenge_page parses into cards', () {
    final page = ChallengePageModel.fromJson(
      _example('challenge_page'),
    ).toEntity();

    expect(page.nextCursor, 'OQ');
    expect(page.items.map((c) => c.title), [
      'Hoan Kiem 50K Steps',
      'My Khe Bay 20 km',
    ]);
    final run = page.items.first;
    expect(run.type, ChallengeType.run);
    expect(run.target, 50000);
    expect(run.participantCount, 813);
    expect(run.enrollment, isNull);
    expect(page.items.last.type, ChallengeType.swim);
  });

  test('challenge_detail parses with its checkpoints', () {
    final challenge = ChallengeModel.fromJson(
      _example('challenge_detail'),
    ).toEntity();

    expect(challenge.title, 'Hoan Kiem 50K Steps');
    expect(challenge.medals.map((m) => m.tier), [
      MedalTier.bronze,
      MedalTier.gold,
    ]);
    expect(challenge.medals.last.threshold, 50000);
    expect(challenge.description, contains('50,000 steps'));
    expect(challenge.endsAt, DateTime.utc(2026, 11, 30, 23, 59, 59));
    expect(challenge.enrollment, isNull);
    expect(challenge.blockedBy, isNull);
  });

  test('challenge_detail_joined has the callers enrollment', () {
    final challenge = ChallengeModel.fromJson(
      _example('challenge_detail_joined'),
    ).toEntity();

    expect(challenge.enrollment?.status, EnrollmentStatus.active);
    expect(challenge.enrollment?.joinedAt, DateTime.utc(2026, 10, 20, 8, 30));
    expect(challenge.participantCount, 814);
  });

  test('challenge_detail_blocked names the other challenge', () {
    final challenge = ChallengeModel.fromJson(
      _example('challenge_detail_blocked'),
    ).toEntity();

    expect(challenge.blockedBy?.id, 4);
    expect(challenge.blockedBy?.title, 'September 30K Steps');
  });
}
