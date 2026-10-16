import 'package:stridequest/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:stridequest/features/auth/data/models/auth_session_model.dart';

/// [AuthLocalDataSource] kept in memory, for tests.
class InMemoryAuthLocalDataSource implements AuthLocalDataSource {
  AuthSessionModel? session;

  @override
  Future<AuthSessionModel?> readSession() async => session;

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async => session = null;
}
