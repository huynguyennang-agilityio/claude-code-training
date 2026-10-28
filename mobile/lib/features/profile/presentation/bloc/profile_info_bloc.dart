import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/profile.dart';
import '../../domain/failures/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/units/unit_conversion.dart';

part 'profile_info_event.dart';
part 'profile_info_state.dart';

/// The Profile info form: load, edit, switch units, save. A factory bloc
/// created in the route's `BlocProvider`.
///
/// Height and weight are kept in metric. A field the user does not touch keeps
/// the loaded value exactly, so showing it in feet and pounds and saving it
/// again never drifts.
@injectable
class ProfileInfoBloc extends Bloc<ProfileInfoEvent, ProfileInfoState> {
  ProfileInfoBloc(this._repository, {@ignoreParam DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const ProfileInfoLoading()) {
    on<ProfileInfoStarted>(_onStarted);
    on<ProfileInfoTextChanged>(_onText);
    on<ProfileInfoBirthdayChanged>(_onBirthday);
    on<ProfileInfoCountryChanged>(
      (event, emit) =>
          _edit(emit, (form) => form.copyWith(country: event.country)),
    );
    on<ProfileInfoGenderChanged>(
      (event, emit) =>
          _edit(emit, (form) => form.copyWith(gender: event.gender)),
    );
    on<ProfileInfoUnitsChanged>(_onUnits);
    on<ProfileInfoHeightChanged>(_onHeight);
    on<ProfileInfoWeightChanged>(_onWeight);
    on<ProfileInfoSaved>(_onSaved);
  }

  /// The API's limits (`docs/api/profile.md`).
  static const maxNameLength = 50;
  static const maxStateLength = 100;
  static const minHeightCm = 50.0;
  static const maxHeightCm = 272.0;
  static const minWeightKg = 20.0;
  static const maxWeightKg = 400.0;

  /// The day after which no birthday is valid (the API rejects this day too).
  static final earliestBirthday = DateTime.utc(1900);

  final ProfileRepository _repository;
  final DateTime Function() _clock;

  Future<void> _onStarted(
    ProfileInfoStarted event,
    Emitter<ProfileInfoState> emit,
  ) async {
    emit(const ProfileInfoLoading());
    try {
      emit(ProfileInfoForm.fromProfile(await _repository.getProfile()));
    } on ProfileFailure catch (failure) {
      emit(ProfileInfoLoadFailed(failure));
    }
  }

  /// Applies [change] to the form, unless it is not editable now.
  void _edit(
    Emitter<ProfileInfoState> emit,
    ProfileInfoForm Function(ProfileInfoForm form) change,
  ) {
    final current = state;
    if (current is! ProfileInfoForm || current.isSaving) return;
    emit(change(current).copyWith(saveFailure: null));
  }

  ProfileInfoForm _withError(
    ProfileInfoForm form,
    ProfileField field,
    ProfileFieldError? error,
  ) => form.copyWith(
    errors: {
      for (final entry in form.errors.entries)
        if (entry.key != field) entry.key: entry.value,
      if (error != null) field: error,
    },
  );

  void _onText(ProfileInfoTextChanged event, Emitter<ProfileInfoState> emit) {
    final limit = event.field == ProfileField.state
        ? maxStateLength
        : maxNameLength;
    final error = event.text.trim().length > limit
        ? ProfileFieldError.tooLong
        : null;
    _edit(emit, (form) {
      final next = switch (event.field) {
        ProfileField.firstName => form.copyWith(firstName: event.text),
        ProfileField.lastName => form.copyWith(lastName: event.text),
        ProfileField.state => form.copyWith(state: event.text),
        _ => form,
      };
      return _withError(next, event.field, error);
    });
  }

  void _onBirthday(
    ProfileInfoBirthdayChanged event,
    Emitter<ProfileInfoState> emit,
  ) {
    final day = event.birthday;
    final now = _clock().toUtc();
    final valid =
        day == null ||
        (day.isAfter(earliestBirthday) &&
            !day.isAfter(DateTime.utc(now.year, now.month, now.day)));
    _edit(
      emit,
      (form) => _withError(
        form.copyWith(birthday: day),
        ProfileField.birthday,
        valid ? null : ProfileFieldError.outOfRange,
      ),
    );
  }

  void _onUnits(ProfileInfoUnitsChanged event, Emitter<ProfileInfoState> emit) {
    // The fields are shown again from the stored values in the new units, so
    // an entry the user left invalid is dropped.
    _edit(
      emit,
      (form) => form.copyWith(
        unitSystem: event.unitSystem,
        errors: {
          for (final entry in form.errors.entries)
            if (entry.key != ProfileField.height &&
                entry.key != ProfileField.weight)
              entry.key: entry.value,
        },
      ),
    );
  }

  void _onHeight(
    ProfileInfoHeightChanged event,
    Emitter<ProfileInfoState> emit,
  ) {
    _edit(emit, (form) {
      final parsed = _parseHeight(form.unitSystem, event);
      return switch (parsed) {
        (:final cm, :final error) when error == null => _withError(
          form.copyWith(heightCm: cm),
          ProfileField.height,
          null,
        ),
        (:final error, cm: _) => _withError(form, ProfileField.height, error),
      };
    });
  }

  void _onWeight(
    ProfileInfoWeightChanged event,
    Emitter<ProfileInfoState> emit,
  ) {
    _edit(emit, (form) {
      final text = event.text.trim();
      if (text.isEmpty) {
        return _withError(
          form.copyWith(weightKg: null),
          ProfileField.weight,
          null,
        );
      }
      final value = _number(text);
      if (value == null || value < 0) {
        return _withError(form, ProfileField.weight, ProfileFieldError.invalid);
      }
      final kg = form.unitSystem == UnitSystem.imperial
          ? lbsToKg(value)
          : roundToTenth(value);
      if (kg < minWeightKg || kg > maxWeightKg) {
        return _withError(
          form,
          ProfileField.weight,
          ProfileFieldError.outOfRange,
        );
      }
      return _withError(form.copyWith(weightKg: kg), ProfileField.weight, null);
    });
  }

  ({double? cm, ProfileFieldError? error}) _parseHeight(
    UnitSystem unit,
    ProfileInfoHeightChanged event,
  ) {
    final primary = event.primary.trim();
    final secondary = event.secondary.trim();
    double? cm;
    if (unit == UnitSystem.metric) {
      if (primary.isEmpty) return (cm: null, error: null);
      final value = _number(primary);
      if (value == null || value < 0) {
        return (cm: null, error: ProfileFieldError.invalid);
      }
      cm = roundToTenth(value);
    } else {
      if (primary.isEmpty && secondary.isEmpty) return (cm: null, error: null);
      final feet = primary.isEmpty ? 0 : int.tryParse(primary);
      final inches = secondary.isEmpty ? 0.0 : _number(secondary);
      if (feet == null ||
          feet < 0 ||
          inches == null ||
          inches < 0 ||
          inches >= 12) {
        return (cm: null, error: ProfileFieldError.invalid);
      }
      cm = feetInchesToCm(feet, inches);
    }
    if (cm < minHeightCm || cm > maxHeightCm) {
      return (cm: null, error: ProfileFieldError.outOfRange);
    }
    return (cm: cm, error: null);
  }

  /// A decimal number typed with a point or a comma.
  static double? _number(String text) {
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  Future<void> _onSaved(
    ProfileInfoSaved event,
    Emitter<ProfileInfoState> emit,
  ) async {
    final current = state;
    if (current is! ProfileInfoForm ||
        current.isSaving ||
        current.errors.isNotEmpty) {
      return;
    }
    emit(current.copyWith(status: ProfileInfoStatus.saving, saveFailure: null));
    try {
      await _repository.saveProfile(current.toProfile());
      emit(current.copyWith(status: ProfileInfoStatus.saved));
    } on ProfileFailure catch (failure) {
      emit(
        current.copyWith(
          status: ProfileInfoStatus.editing,
          saveFailure: failure,
        ),
      );
    }
  }
}
