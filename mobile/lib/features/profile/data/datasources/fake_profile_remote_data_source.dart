import '../../domain/failures/profile_failure.dart';
import '../models/profile_model.dart';
import 'profile_fixtures.dart';
import 'profile_remote_data_source.dart';

/// In-memory [ProfileRemoteDataSource] for tests and for debug builds run with
/// `--dart-define=API_MODE=mock` (registered in `MockApiModule`). `get`
/// answers with `profile.json` until `put` saves something; `put` checks the
/// field rules of the contract and answers `validation_error` like the backend.
class FakeProfileRemoteDataSource implements ProfileRemoteDataSource {
  FakeProfileRemoteDataSource({
    this.latency = Duration.zero,
    ProfileModel? initial,
    DateTime Function()? now,
  }) : _profile = initial ?? ProfileModel.fromJson(profileFixture),
       _now = now ?? DateTime.now;

  /// Delay added to every call, so loading states can be seen in the UI.
  final Duration latency;

  final DateTime Function() _now;
  ProfileModel _profile;

  @override
  Future<ProfileModel> get() async {
    await Future<void>.delayed(latency);
    return _profile;
  }

  @override
  Future<ProfileModel> put(ProfileModel profile) async {
    await Future<void>.delayed(latency);
    final errors = _validate(profile);
    if (errors.isNotEmpty) {
      throw ProfileFailure(ProfileFailureCode.validation, fieldErrors: errors);
    }
    return _profile = profile;
  }

  Map<String, String> _validate(ProfileModel p) {
    // Both sides are UTC calendar dates, like the backend's check.
    final birthday = p.birthday == null
        ? null
        : DateTime.tryParse('${p.birthday}T00:00:00Z');
    final now = _now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return {
      if (!_name(p.firstName))
        'first_name': 'First name is 1 to 50 characters.',
      if (!_name(p.lastName)) 'last_name': 'Last name is 1 to 50 characters.',
      if (p.birthday != null &&
          (birthday == null ||
              !birthday.isAfter(DateTime.utc(1900)) ||
              birthday.isAfter(today)))
        'birthday': 'Birthday must be after 1900-01-01 and not in the future.',
      if (p.country != null && !RegExp(r'^[A-Z]{2}$').hasMatch(p.country!))
        'country': 'Country must be a two-letter code in capitals.',
      if (p.state != null &&
          (p.state!.trim().isEmpty || p.state!.trim().length > 100))
        'state': 'State is 1 to 100 characters.',
      if (p.heightCm != null && (p.heightCm! < 50 || p.heightCm! > 272))
        'height_cm': 'Height must be between 50.0 and 272.0 cm.',
      if (p.weightKg != null && (p.weightKg! < 20 || p.weightKg! > 400))
        'weight_kg': 'Weight must be between 20.0 and 400.0 kg.',
    };
  }

  bool _name(String? value) =>
      value == null || (value.trim().isNotEmpty && value.trim().length <= 50);
}
