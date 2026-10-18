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
}
