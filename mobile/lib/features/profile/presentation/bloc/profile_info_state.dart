part of 'profile_info_bloc.dart';

/// The fields that can show an error.
enum ProfileField { firstName, lastName, birthday, state, height, weight }

enum ProfileFieldError { tooLong, invalid, outOfRange }

enum ProfileInfoStatus { editing, saving, saved }

sealed class ProfileInfoState extends Equatable {
  const ProfileInfoState();

  @override
  List<Object?> get props => [];
}

final class ProfileInfoLoading extends ProfileInfoState {
  const ProfileInfoLoading();
}

final class ProfileInfoLoadFailed extends ProfileInfoState {
  const ProfileInfoLoadFailed(this.failure);

  final ProfileFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// The form. [firstName], [lastName] and [state] are the text as typed;
/// [heightCm] and [weightKg] are always metric, and stay exactly as loaded
/// until the user edits that field. [errors] hold the fields the user left
/// invalid; Save does nothing while there is one. [saveFailure] is the last
/// refused save, for a banner.
final class ProfileInfoForm extends ProfileInfoState {
  const ProfileInfoForm({
    this.firstName = '',
    this.lastName = '',
    this.birthday,
    this.country,
    this.state = '',
    this.gender,
    this.unitSystem = UnitSystem.metric,
    this.heightCm,
    this.weightKg,
    this.errors = const {},
    this.status = ProfileInfoStatus.editing,
    this.saveFailure,
  });

  factory ProfileInfoForm.fromProfile(Profile profile) => ProfileInfoForm(
    firstName: profile.firstName ?? '',
    lastName: profile.lastName ?? '',
    birthday: profile.birthday,
    country: profile.country,
    state: profile.state ?? '',
    gender: profile.gender,
    unitSystem: profile.unitSystem,
    heightCm: profile.heightCm,
    weightKg: profile.weightKg,
  );

  final String firstName;
  final String lastName;
  final DateTime? birthday;
  final String? country;
  final String state;
  final Gender? gender;
  final UnitSystem unitSystem;
  final double? heightCm;
  final double? weightKg;
  final Map<ProfileField, ProfileFieldError> errors;
  final ProfileInfoStatus status;
  final ProfileFailure? saveFailure;

  bool get isSaving => status == ProfileInfoStatus.saving;

  /// The form as a [Profile]: text trimmed, and an empty text sent as null.
  Profile toProfile() => Profile(
    firstName: _orNull(firstName),
    lastName: _orNull(lastName),
    birthday: birthday,
    country: country,
    state: _orNull(state),
    gender: gender,
    unitSystem: unitSystem,
    heightCm: heightCm,
    weightKg: weightKg,
  );

  /// `birthday`, `country`, `gender`, `heightCm` and `weightKg` can be set to
  /// null on purpose, so they are passed as objects.
  ProfileInfoForm copyWith({
    String? firstName,
    String? lastName,
    Object? birthday = _keep,
    Object? country = _keep,
    String? state,
    Object? gender = _keep,
    UnitSystem? unitSystem,
    Object? heightCm = _keep,
    Object? weightKg = _keep,
    Map<ProfileField, ProfileFieldError>? errors,
    ProfileInfoStatus? status,
    Object? saveFailure = _keep,
  }) => ProfileInfoForm(
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    birthday: identical(birthday, _keep)
        ? this.birthday
        : birthday as DateTime?,
    country: identical(country, _keep) ? this.country : country as String?,
    state: state ?? this.state,
    gender: identical(gender, _keep) ? this.gender : gender as Gender?,
    unitSystem: unitSystem ?? this.unitSystem,
    heightCm: identical(heightCm, _keep) ? this.heightCm : heightCm as double?,
    weightKg: identical(weightKg, _keep) ? this.weightKg : weightKg as double?,
    errors: errors ?? this.errors,
    status: status ?? this.status,
    saveFailure: identical(saveFailure, _keep)
        ? this.saveFailure
        : saveFailure as ProfileFailure?,
  );

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
    errors,
    status,
    saveFailure,
  ];
}

const Object _keep = Object();

String? _orNull(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}
