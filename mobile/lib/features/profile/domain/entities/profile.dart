import 'package:equatable/equatable.dart';

/// How the app shows height and weight. The stored values are always metric.
enum UnitSystem {
  imperial('imperial'),
  metric('metric');

  const UnitSystem(this.wire);

  final String wire;

  static UnitSystem fromWire(String? value) => values.firstWhere(
    (unit) => unit.wire == value,
    orElse: () => UnitSystem.metric,
  );
}

enum Gender {
  female('female', 'Female'),
  male('male', 'Male'),
  nonBinary('non_binary', 'Non-binary'),
  preferNotToSay('prefer_not_to_say', 'Prefer not to say');

  const Gender(this.wire, this.label);

  final String wire;
  final String label;

  static Gender? fromWire(String? value) {
    for (final gender in values) {
      if (gender.wire == value) return gender;
    }
    return null;
  }
}

/// The optional personal details of the signed-in user (`docs/api/profile.md`).
/// Every field except [unitSystem] can be null. [heightCm] and [weightKg] are
/// metric whatever [unitSystem] says.
class Profile extends Equatable {
  const Profile({
    this.firstName,
    this.lastName,
    this.birthday,
    this.country,
    this.state,
    this.gender,
    this.unitSystem = UnitSystem.metric,
    this.heightCm,
    this.weightKg,
  });

  final String? firstName;
  final String? lastName;

  /// A calendar date (UTC midnight).
  final DateTime? birthday;

  /// An ISO 3166-1 alpha-2 code.
  final String? country;
  final String? state;
  final Gender? gender;
  final UnitSystem unitSystem;
  final double? heightCm;
  final double? weightKg;

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    birthday,
    country,
    state,
    gender,
    unitSystem,
    heightCm,
    weightKg,
  ];
}
