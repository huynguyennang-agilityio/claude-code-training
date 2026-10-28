import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/profile/data/datasources/profile_fixtures.dart';
import 'package:stridequest/features/profile/data/models/profile_model.dart';
import 'package:stridequest/features/profile/domain/entities/profile.dart';

/// The shared examples of `docs/api/profile.md`. Each fixture the fake data
/// source uses must equal its file, and the backend tests compare their
/// responses with the same files.
const _examplesDir = '../docs/api/examples/profile';

Object? _example(String name) =>
    jsonDecode(File('$_examplesDir/$name.json').readAsStringSync());

void main() {
  test('the examples directory is found from the mobile folder', () {
    expect(Directory(_examplesDir).existsSync(), isTrue);
  });

  test('profileFixture equals profile.json', () {
    expect(profileFixture, _example('profile'));
  });

  test('profileEmptyFixture equals profile_empty.json', () {
    expect(profileEmptyFixture, _example('profile_empty'));
  });

  test('errorValidationFixture equals error_validation.json', () {
    expect(errorValidationFixture, _example('error_validation'));
  });

  test('profile.json parses into the entity', () {
    final profile = ProfileModel.fromJson(
      _example('profile')! as Map<String, dynamic>,
    ).toEntity();

    expect(profile.firstName, 'Max');
    expect(profile.birthday, DateTime.utc(1991, 6, 24));
    expect(profile.country, 'US');
    expect(profile.gender, Gender.male);
    expect(profile.unitSystem, UnitSystem.imperial);
    expect(profile.heightCm, 180.3);
    expect(profile.weightKg, 84.4);
  });

  test('profile_empty.json parses into an empty metric profile', () {
    final profile = ProfileModel.fromJson(
      _example('profile_empty')! as Map<String, dynamic>,
    ).toEntity();

    expect(profile, const Profile());
  });

  test('the PUT body of a saved profile equals profile_put_request.json', () {
    final profile = ProfileModel.fromJson(
      _example('profile')! as Map<String, dynamic>,
    ).toEntity();

    expect(
      ProfileModel.fromEntity(profile).toJson(),
      _example('profile_put_request'),
    );
  });

  test('the PUT body of an empty profile has all nine keys, as null', () {
    final body = ProfileModel.fromEntity(const Profile()).toJson();

    expect(body, profileEmptyFixture);
    expect(body.length, 9);
  });
}
