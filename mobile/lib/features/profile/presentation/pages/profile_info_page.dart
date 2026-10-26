import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/settings_form_layout.dart';
import '../../../auth/presentation/widgets/auth_banner.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/profile.dart';
import '../../domain/units/unit_conversion.dart';
import '../bloc/profile_info_bloc.dart';
import '../widgets/profile_form_fields.dart';
import '../widgets/profile_pickers.dart';

/// The Profile info form (Figma `1:100`): names, birthday, country, state,
/// gender, units, height and weight. Expects a [ProfileInfoBloc]. It is pushed
/// above the tab bar, so the back button returns to the tab.
class ProfileInfoPage extends StatelessWidget {
  const ProfileInfoPage({super.key});

  static const path = '/profile/info';

  static const _title = 'Profile';

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileInfoBloc, ProfileInfoState>(
      listenWhen: (before, after) =>
          after is ProfileInfoForm &&
          after.status == ProfileInfoStatus.saved &&
          !(before is ProfileInfoForm &&
              before.status == ProfileInfoStatus.saved),
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Profile saved')));
        Navigator.of(context).maybePop();
      },
      builder: (context, state) => switch (state) {
        ProfileInfoLoading() => const SettingsFormLayout(
          title: _title,
          actions: [],
          children: [
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        ProfileInfoLoadFailed(:final failure) => SettingsFormLayout(
          title: _title,
          actions: const [],
          children: [
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => context.read<ProfileInfoBloc>().add(
                const ProfileInfoStarted(),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
        final ProfileInfoForm form => _ProfileForm(form: form),
      },
    );
  }
}

/// The loaded form. It owns the text controllers and focus order; what the
/// user types goes to the bloc, and the bloc state is what gets saved.
class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.form});

  final ProfileInfoForm form;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _firstName = TextEditingController(text: widget.form.firstName);
  late final _lastName = TextEditingController(text: widget.form.lastName);
  late final _state = TextEditingController(text: widget.form.state);
  final _heightMain = TextEditingController();
  final _heightInches = TextEditingController();
  final _weight = TextEditingController();

  @override
  void initState() {
    super.initState();
    _showMeasurements(widget.form);
  }

  @override
  void didUpdateWidget(_ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New units: show the stored metric values again in them.
    if (oldWidget.form.unitSystem != widget.form.unitSystem) {
      _showMeasurements(widget.form);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _state,
      _heightMain,
      _heightInches,
      _weight,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showMeasurements(ProfileInfoForm form) {
    final cm = form.heightCm;
    final kg = form.weightKg;
    if (form.unitSystem == UnitSystem.imperial) {
      final height = cm == null ? null : cmToFeetInches(cm);
      _heightMain.text = height == null ? '' : '${height.feet}';
      _heightInches.text = height == null ? '' : '${height.inches}';
      _weight.text = kg == null ? '' : formatNumber(kgToLbs(kg));
    } else {
      _heightMain.text = cm == null ? '' : formatNumber(cm);
      _heightInches.clear();
      _weight.text = kg == null ? '' : formatNumber(kg);
    }
  }

  ProfileInfoBloc get _bloc => context.read<ProfileInfoBloc>();

  void _save() => _bloc.add(const ProfileInfoSaved());

  void _heightChanged() =>
      _bloc.add(ProfileInfoHeightChanged(_heightMain.text, _heightInches.text));

  Future<void> _chooseBirthday() async {
    final picked = await pickBirthday(context, widget.form.birthday);
    if (picked != null && mounted) {
      _bloc.add(ProfileInfoBirthdayChanged(picked));
    }
  }

  Future<void> _chooseCountry() async {
    final picked = await pickCountry(context, widget.form.country);
    if (picked != null && mounted) {
      _bloc.add(ProfileInfoCountryChanged(picked));
    }
  }

  Future<void> _chooseGender() async {
    final picked = await pickGender(context, widget.form.gender);
    if (picked != null && mounted) {
      _bloc.add(ProfileInfoGenderChanged(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final editable = !form.isSaving;
    final imperial = form.unitSystem == UnitSystem.imperial;
    final errors = form.errors;
    const gap = SizedBox(height: AppSpacing.md);

    return SettingsFormLayout(
      title: ProfileInfoPage._title,
      actions: [
        OutlinedButton(
          onPressed: editable ? _save : null,
          child: form.isSaving
              ? const SizedBox(
                  width: AppSpacing.md,
                  height: AppSpacing.md,
                  child: CircularProgressIndicator(
                    strokeWidth: AppSpacing.xxs / 2,
                  ),
                )
              : const Text('Save'),
        ),
      ],
      children: [
        if (form.saveFailure != null)
          AuthBanner(message: form.saveFailure!.message, isError: true),
        ProfileTextField(
          label: 'First Name',
          hint: 'Your first name',
          controller: _firstName,
          enabled: editable,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          errorText: _error(
            errors[ProfileField.firstName],
            ProfileField.firstName,
            form,
          ),
          onChanged: (text) =>
              _bloc.add(ProfileInfoTextChanged(ProfileField.firstName, text)),
        ),
        gap,
        ProfileTextField(
          label: 'Last Name',
          hint: 'Your last name',
          controller: _lastName,
          enabled: editable,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          errorText: _error(
            errors[ProfileField.lastName],
            ProfileField.lastName,
            form,
          ),
          onChanged: (text) =>
              _bloc.add(ProfileInfoTextChanged(ProfileField.lastName, text)),
        ),
        gap,
        ProfilePickerField(
          label: 'Birthday',
          hint: 'Select your birthday',
          value: form.birthday == null ? null : formatDate(form.birthday!),
          enabled: editable,
          errorText: _error(
            errors[ProfileField.birthday],
            ProfileField.birthday,
            form,
          ),
          onTap: _chooseBirthday,
          onClear: () => _bloc.add(const ProfileInfoBirthdayChanged(null)),
        ),
        gap,
        ProfilePickerField(
          label: 'Country',
          hint: 'Select your country',
          value: Country.byCode(form.country)?.name ?? form.country,
          enabled: editable,
          onTap: _chooseCountry,
          onClear: () => _bloc.add(const ProfileInfoCountryChanged(null)),
        ),
        gap,
        ProfileTextField(
          label: 'State',
          hint: 'Your state or region',
          controller: _state,
          enabled: editable,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          errorText: _error(
            errors[ProfileField.state],
            ProfileField.state,
            form,
          ),
          onChanged: (text) =>
              _bloc.add(ProfileInfoTextChanged(ProfileField.state, text)),
        ),
        gap,
        ProfilePickerField(
          label: 'Gender',
          hint: 'Select your gender',
          value: form.gender?.label,
          enabled: editable,
          onTap: _chooseGender,
          onClear: () => _bloc.add(const ProfileInfoGenderChanged(null)),
        ),
        gap,
        _UnitsRow(
          unitSystem: form.unitSystem,
          onChanged: editable
              ? (unit) => _bloc.add(ProfileInfoUnitsChanged(unit))
              : null,
        ),
        gap,
        if (imperial)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ProfileTextField(
                  label: 'Height (ft)',
                  hint: '5',
                  controller: _heightMain,
                  enabled: editable,
                  suffix: 'ft',
                  showError: false,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _heightChanged(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ProfileTextField(
                  label: 'Height (in)',
                  hint: '11',
                  controller: _heightInches,
                  enabled: editable,
                  suffix: 'in',
                  showError: false,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _heightChanged(),
                ),
              ),
            ],
          )
        else
          ProfileTextField(
            label: 'Height',
            hint: '180',
            controller: _heightMain,
            enabled: editable,
            suffix: 'cm',
            showError: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (_) => _heightChanged(),
          ),
        if (errors[ProfileField.height] case final error?)
          FieldErrorText(_error(error, ProfileField.height, form)!),
        gap,
        ProfileTextField(
          label: 'Weight',
          hint: imperial ? '185' : '84',
          controller: _weight,
          enabled: editable,
          suffix: imperial ? 'lbs' : 'kg',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          errorText: _error(
            errors[ProfileField.weight],
            ProfileField.weight,
            form,
          ),
          onChanged: (text) => _bloc.add(ProfileInfoWeightChanged(text)),
          // Done closes the keyboard, then saves if the form is valid.
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}

/// "Imperial (US)" ⟷ switch ⟷ "Metric". The switch is on for metric.
class _UnitsRow extends StatelessWidget {
  const _UnitsRow({required this.unitSystem, required this.onChanged});

  final UnitSystem unitSystem;
  final ValueChanged<UnitSystem>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metric = unitSystem == UnitSystem.metric;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Units',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // A Wrap, so large text puts the labels on their own lines.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            Text('Imperial (US)', style: theme.textTheme.bodyLarge),
            // Out of the focus order, like the pickers: Next on the keyboard
            // goes from text field to text field.
            ExcludeFocus(
              child: Semantics(
                label: 'Use metric units',
                child: Switch(
                  value: metric,
                  onChanged: onChanged == null
                      ? null
                      : (on) => onChanged!(
                          on ? UnitSystem.metric : UnitSystem.imperial,
                        ),
                ),
              ),
            ),
            Text('Metric', style: theme.textTheme.bodyLarge),
          ],
        ),
      ],
    );
  }
}

/// The message of a field's [error], in the units the form shows.
String? _error(
  ProfileFieldError? error,
  ProfileField field,
  ProfileInfoForm form,
) {
  if (error == null) return null;
  final imperial = form.unitSystem == UnitSystem.imperial;
  return switch ((field, error)) {
    (ProfileField.firstName, _) => 'First name is at most 50 characters.',
    (ProfileField.lastName, _) => 'Last name is at most 50 characters.',
    (ProfileField.state, _) => 'State is at most 100 characters.',
    (ProfileField.birthday, _) =>
      'Pick a date after 1900 that is not in the future.',
    (ProfileField.height, ProfileFieldError.invalid) =>
      imperial
          ? 'Enter feet, and inches under 12.'
          : 'Enter the height in centimetres.',
    (ProfileField.height, _) =>
      imperial ? _imperialHeightRange : _metricHeightRange,
    (ProfileField.weight, ProfileFieldError.invalid) =>
      'Enter the weight as a number.',
    (ProfileField.weight, _) =>
      imperial ? _imperialWeightRange : _metricWeightRange,
  };
}

String get _metricHeightRange =>
    'Height must be between ${formatNumber(ProfileInfoBloc.minHeightCm)} and '
    '${formatNumber(ProfileInfoBloc.maxHeightCm)} cm.';

String get _imperialHeightRange {
  final low = cmToFeetInches(ProfileInfoBloc.minHeightCm);
  final high = cmToFeetInches(ProfileInfoBloc.maxHeightCm);
  return 'Height must be between ${low.feet} ft ${low.inches} in and '
      '${high.feet} ft ${high.inches} in.';
}

String get _metricWeightRange =>
    'Weight must be between ${formatNumber(ProfileInfoBloc.minWeightKg)} and '
    '${formatNumber(ProfileInfoBloc.maxWeightKg)} kg.';

String get _imperialWeightRange =>
    'Weight must be between '
    '${formatNumber(kgToLbs(ProfileInfoBloc.minWeightKg))} and '
    '${formatNumber(kgToLbs(ProfileInfoBloc.maxWeightKg))} lbs.';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `Jun 24, 1991`.
String formatDate(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';
