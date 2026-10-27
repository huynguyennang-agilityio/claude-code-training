/// The examples of `docs/api/examples/profile/` as Dart maps, used by
/// `FakeProfileRemoteDataSource`. `test/contract/profile_examples_test.dart`
/// checks each equals its file: change the example first, then this.
library;

/// `profile.json`
const profileFixture = <String, dynamic>{
  'first_name': 'Max',
  'last_name': 'Darsonval',
  'birthday': '1991-06-24',
  'country': 'US',
  'state': 'California',
  'gender': 'male',
  'unit_system': 'imperial',
  'height_cm': 180.3,
  'weight_kg': 84.4,
};

/// `profile_empty.json`
const profileEmptyFixture = <String, dynamic>{
  'first_name': null,
  'last_name': null,
  'birthday': null,
  'country': null,
  'state': null,
  'gender': null,
  'unit_system': 'metric',
  'height_cm': null,
  'weight_kg': null,
};

/// `error_validation.json`
const errorValidationFixture = <String, dynamic>{
  'error': {
    'code': 'validation_error',
    'message': 'Request is invalid.',
    'fields': [
      {
        'field': 'country',
        'message': 'Country must be a two-letter code in capitals.',
      },
      {
        'field': 'height_cm',
        'message': 'Height must be between 50.0 and 272.0 cm.',
      },
    ],
  },
};
