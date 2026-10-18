import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';
import 'package:stridequest/features/challenges/domain/repositories/challenge_repository.dart';

const coverUrl =
    'https://res.cloudinary.com/demo/image/upload/stridequest/covers/a.jpg';
const medalUrl =
    'https://res.cloudinary.com/demo/image/upload/stridequest/medals/a.png';

ChallengeSummary summary({
  int id = 1,
  String title = 'Old Quarter 50K Steps',
  ChallengeType type = ChallengeType.run,
  int target = 50000,
  int participants = 1234,
  String? city = 'Hà Nội',
  Enrollment? enrollment,
  DateTime? startsAt,
  DateTime? endsAt,
}) => ChallengeSummary(
  id: id,
  title: title,
  type: type,
  target: target,
  startsAt: startsAt ?? DateTime.utc(2026, 10, 1),
  endsAt: endsAt ?? DateTime.utc(2026, 10, 31),
  participantCount: participants,
  coverImageUrl: coverUrl,
  city: city,
  enrollment: enrollment,
);

final joinedAt = DateTime.utc(2026, 10, 5);

Enrollment enrolled([EnrollmentStatus status = EnrollmentStatus.active]) =>
    Enrollment(status: status, joinedAt: joinedAt);

const medals = [
  Medal(
    tier: MedalTier.bronze,
    name: 'Lake Walker',
    threshold: 20000,
    imageUrl: medalUrl,
  ),
  Medal(
    tier: MedalTier.silver,
    name: 'Lake Strider',
    threshold: 35000,
    imageUrl: medalUrl,
  ),
  Medal(
    tier: MedalTier.gold,
    name: 'Lake Master',
    threshold: 50000,
    imageUrl: medalUrl,
  ),
];

Challenge challenge({
  int id = 1,
  String title = 'Old Quarter 50K Steps',
  ChallengeType type = ChallengeType.run,
  int target = 50000,
  int participants = 813,
  Enrollment? enrollment,
  BlockingChallenge? blockedBy,
  DateTime? startsAt,
  DateTime? endsAt,
  String description = 'Walk or run **50,000 steps** around the lake.',
  String terms = 'Steps are read from Apple Health.',
  List<Medal> medalList = medals,
}) => Challenge(
  id: id,
  title: title,
  type: type,
  target: target,
  startsAt: startsAt ?? DateTime.utc(2026, 10, 1),
  endsAt: endsAt ?? DateTime.utc(2026, 10, 31),
  participantCount: participants,
  description: description,
  terms: terms,
  medals: medalList,
  coverImageUrl: coverUrl,
  city: 'Hà Nội',
  landmark: 'Hồ Hoàn Kiem',
  enrollment: enrollment,
  blockedBy: blockedBy,
);

/// An in-memory [ChallengeRepository]: filters and pages like the backend, and
/// can be told to fail.
class FakeChallengeRepository implements ChallengeRepository {
  FakeChallengeRepository({List<ChallengeSummary>? items, this.pageSize = 20})
    : items = items ?? [summary(), summary(id: 2, title: 'Mỹ Khê Bay 20 km')];

  List<ChallengeSummary> items;
  int pageSize;
  ChallengeFailure? failure;
  Challenge? detail;
  final calls = <({ChallengeType? type, String? query, String? cursor})>[];

  @override
  Future<ChallengePage> list({
    ChallengeType? type,
    String? query,
    String? cursor,
    int limit = 20,
  }) async {
    calls.add((type: type, query: query, cursor: cursor));
    if (failure case final failure?) throw failure;
    final matching = items.where((item) {
      final text = query?.toLowerCase() ?? '';
      return (type == null || item.type == type) &&
          (text.isEmpty || item.title.toLowerCase().contains(text));
    }).toList();
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, matching.length);
    return ChallengePage(
      items: matching.sublist(start, end),
      nextCursor: end < matching.length ? '$end' : null,
    );
  }

  @override
  Future<Challenge> get(int id) async {
    if (failure case final failure?) throw failure;
    return detail ?? challenge(id: id);
  }

  /// What the next action answers with (or `failure`, when set).
  final actions = <String>[];
  Challenge Function(String action, int id)? onAction;

  Future<Challenge> _act(String action, int id) async {
    actions.add('$action $id');
    if (failure case final failure?) throw failure;
    return onAction?.call(action, id) ?? challenge(id: id);
  }

  @override
  Future<Challenge> join(int id) => _act('join', id);

  @override
  Future<Challenge> pause(int id) => _act('pause', id);

  @override
  Future<Challenge> resume(int id) => _act('resume', id);

  @override
  Future<Challenge> leave(int id) => _act('leave', id);
}
