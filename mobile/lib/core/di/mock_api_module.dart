import 'package:injectable/injectable.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/fake_auth_remote_data_source.dart';
import '../../features/profile/data/datasources/fake_profile_remote_data_source.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../config/app_config.dart';
import 'api_environments.dart';

/// The fake remote data sources used with `--dart-define=API_MODE=mock`.
///
/// The fakes carry no DI annotations (their constructors take test-only
/// parameters), so they are built here. A feature without a fake keeps its
/// real data source in mock mode, and its screens show their error state.
@module
abstract class MockApiModule {
  /// Waits `SIMULATE_LATENCY_MS` per call, so loading states can be seen.
  @mockApi
  @lazySingleton
  AuthRemoteDataSource get fakeAuthRemoteDataSource =>
      FakeAuthRemoteDataSource(latency: AppConfig.networkSimulation.latency);

  @mockApi
  @lazySingleton
  ProfileRemoteDataSource get fakeProfileRemoteDataSource =>
      FakeProfileRemoteDataSource(latency: AppConfig.networkSimulation.latency);
}
