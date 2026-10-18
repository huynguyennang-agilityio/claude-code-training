import 'package:injectable/injectable.dart';

import '../../domain/entities/challenge.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../datasources/challenge_remote_data_source.dart';

@LazySingleton(as: ChallengeRepository)
class ChallengeRepositoryImpl implements ChallengeRepository {
  ChallengeRepositoryImpl(this._remote);

  final ChallengeRemoteDataSource _remote;

  @override
  Future<ChallengePage> list({
    ChallengeType? type,
    String? query,
    String? cursor,
    int limit = 20,
  }) async {
    final page = await _remote.list(
      type: type,
      query: query,
      cursor: cursor,
      limit: limit,
    );
    return page.toEntity();
  }

  @override
  Future<Challenge> get(int id) async => (await _remote.get(id)).toEntity();

  @override
  Future<Challenge> join(int id) async => (await _remote.join(id)).toEntity();

  @override
  Future<Challenge> pause(int id) async => (await _remote.pause(id)).toEntity();

  @override
  Future<Challenge> resume(int id) async =>
      (await _remote.resume(id)).toEntity();

  @override
  Future<Challenge> leave(int id) async => (await _remote.leave(id)).toEntity();
}
