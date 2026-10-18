import 'package:equatable/equatable.dart';

/// What a challenge counts: a run counts steps, a swim or a ride counts distance.
enum ChallengeType {
  run('run', 'Run'),
  swim('swim', 'Swim'),
  cycle('cycle', 'Cycle');

  const ChallengeType(this.wire, this.label);

  /// The value the API sends and takes.
  final String wire;
  final String label;

  /// The metric of the type: steps for a run, metres otherwise.
  bool get countsSteps => this == run;

  static ChallengeType fromWire(String value) =>
      values.firstWhere((type) => type.wire == value);
}

enum MedalTier {
  bronze('bronze', 'Bronze'),
  silver('silver', 'Silver'),
  gold('gold', 'Gold');

  const MedalTier(this.wire, this.label);

  final String wire;
  final String label;

  static MedalTier fromWire(String value) =>
      values.firstWhere((tier) => tier.wire == value);
}

/// The caller's own place in a challenge. A challenge they left is "not joined".
enum EnrollmentStatus {
  active('active'),
  paused('paused');

  const EnrollmentStatus(this.wire);

  final String wire;

  static EnrollmentStatus fromWire(String value) =>
      values.firstWhere((status) => status.wire == value);
}

class Enrollment extends Equatable {
  const Enrollment({required this.status, required this.joinedAt});

  final EnrollmentStatus status;
  final DateTime joinedAt;

  @override
  List<Object?> get props => [status, joinedAt];
}

/// A medal checkpoint: reached at [threshold] steps or metres.
class Medal extends Equatable {
  const Medal({
    required this.tier,
    required this.name,
    required this.threshold,
    required this.imageUrl,
  });

  final MedalTier tier;
  final String name;
  final int threshold;
  final String imageUrl;

  @override
  List<Object?> get props => [tier, name, threshold, imageUrl];
}

/// The challenge that stops the caller joining another one that overlaps it.
class BlockingChallenge extends Equatable {
  const BlockingChallenge({required this.id, required this.title});

  final int id;
  final String title;

  @override
  List<Object?> get props => [id, title];
}

/// A challenge as a card in the list.
class ChallengeSummary extends Equatable {
  const ChallengeSummary({
    required this.id,
    required this.title,
    required this.type,
    required this.target,
    required this.startsAt,
    required this.endsAt,
    required this.participantCount,
    this.coverImageUrl,
    this.city,
    this.landmark,
    this.enrollment,
  });

  final int id;
  final String title;
  final ChallengeType type;

  /// Steps for a run, metres for a swim or a ride.
  final int target;
  final DateTime startsAt;
  final DateTime endsAt;
  final int participantCount;
  final String? coverImageUrl;
  final String? city;
  final String? landmark;

  /// Null when the caller has not joined.
  final Enrollment? enrollment;

  bool hasEndedAt(DateTime now) => !now.isBefore(endsAt);

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    target,
    startsAt,
    endsAt,
    participantCount,
    coverImageUrl,
    city,
    landmark,
    enrollment,
  ];
}

/// One challenge with everything the detail shows.
class Challenge extends ChallengeSummary {
  const Challenge({
    required super.id,
    required super.title,
    required super.type,
    required super.target,
    required super.startsAt,
    required super.endsAt,
    required super.participantCount,
    required this.description,
    required this.terms,
    required this.medals,
    super.coverImageUrl,
    super.city,
    super.landmark,
    super.enrollment,
    this.blockedBy,
  });

  /// Markdown.
  final String description;

  /// Markdown.
  final String terms;
  final List<Medal> medals;

  /// Set when an active challenge of the same type overlaps this one.
  final BlockingChallenge? blockedBy;

  @override
  List<Object?> get props => [
    ...super.props,
    description,
    terms,
    medals,
    blockedBy,
  ];
}

/// One page of the list.
class ChallengePage extends Equatable {
  const ChallengePage({required this.items, this.nextCursor});

  final List<ChallengeSummary> items;

  /// Null on the last page.
  final String? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}
