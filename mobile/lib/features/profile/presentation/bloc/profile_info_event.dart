part of 'profile_info_bloc.dart';

sealed class ProfileInfoEvent extends Equatable {
  const ProfileInfoEvent();

  @override
  List<Object?> get props => [];
}

/// Load the profile (also the Try again of the error state).
final class ProfileInfoStarted extends ProfileInfoEvent {
  const ProfileInfoStarted();
}

/// A text field changed. Height and weight have their own events.
final class ProfileInfoTextChanged extends ProfileInfoEvent {
  const ProfileInfoTextChanged(this.field, this.text);

  final ProfileField field;
  final String text;

  @override
  List<Object?> get props => [field, text];
}

final class ProfileInfoBirthdayChanged extends ProfileInfoEvent {
  const ProfileInfoBirthdayChanged(this.birthday);

  final DateTime? birthday;

  @override
  List<Object?> get props => [birthday];
}

final class ProfileInfoCountryChanged extends ProfileInfoEvent {
  const ProfileInfoCountryChanged(this.country);

  final String? country;

  @override
  List<Object?> get props => [country];
}

final class ProfileInfoGenderChanged extends ProfileInfoEvent {
  const ProfileInfoGenderChanged(this.gender);

  final Gender? gender;

  @override
  List<Object?> get props => [gender];
}

/// The Units switch. Only the display changes; stored values stay metric.
final class ProfileInfoUnitsChanged extends ProfileInfoEvent {
  const ProfileInfoUnitsChanged(this.unitSystem);

  final UnitSystem unitSystem;

  @override
  List<Object?> get props => [unitSystem];
}

/// The height field(s) changed, as typed. In metric [primary] is centimetres;
/// in imperial it is feet and [secondary] is inches.
final class ProfileInfoHeightChanged extends ProfileInfoEvent {
  const ProfileInfoHeightChanged(this.primary, [this.secondary = '']);

  final String primary;
  final String secondary;

  @override
  List<Object?> get props => [primary, secondary];
}

/// The weight field changed, as typed: kilograms or pounds per the units.
final class ProfileInfoWeightChanged extends ProfileInfoEvent {
  const ProfileInfoWeightChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// The user tapped Save (or Done on the last field).
final class ProfileInfoSaved extends ProfileInfoEvent {
  const ProfileInfoSaved();
}
