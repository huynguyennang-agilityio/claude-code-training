import 'package:injectable/injectable.dart';

import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../models/profile_model.dart';

@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Profile> getProfile() async => (await _remote.get()).toEntity();

  @override
  Future<Profile> saveProfile(Profile profile) async =>
      (await _remote.put(ProfileModel.fromEntity(profile))).toEntity();
}
