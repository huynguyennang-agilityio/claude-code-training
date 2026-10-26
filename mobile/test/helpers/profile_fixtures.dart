import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/profile/domain/entities/profile.dart';
import 'package:stridequest/features/profile/domain/repositories/profile_repository.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

/// The profile of `docs/api/examples/profile/profile.json`.
final sampleProfile = Profile(
  firstName: 'Max',
  lastName: 'Darsonval',
  birthday: DateTime.utc(1991, 6, 24),
  country: 'US',
  state: 'California',
  gender: Gender.male,
  unitSystem: UnitSystem.imperial,
  heightCm: 180.3,
  weightKg: 84.4,
);

/// What `getProfile` answers for a user who never saved.
const emptyProfile = Profile();

/// Registers a `registerFallbackValue` for [Profile], for `any()`.
void registerProfileFallback() => registerFallbackValue(const Profile());
