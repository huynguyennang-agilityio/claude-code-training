import '../entities/profile.dart';

/// The signed-in user's profile. Every method throws `ProfileFailure` on error.
abstract interface class ProfileRepository {
  /// A user who never saved gets an empty profile in metric, not an error.
  Future<Profile> getProfile();

  /// Replaces the whole profile and answers with what was saved.
  Future<Profile> saveProfile(Profile profile);
}
