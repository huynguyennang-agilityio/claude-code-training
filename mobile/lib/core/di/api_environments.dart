import 'package:injectable/injectable.dart';

import '../config/api_mode.dart';

/// `injectable` environments, one per [ApiMode]. A class or module member
/// without one is registered in both.
///
/// Only a remote data source that has a fake is split: its real class is
/// annotated `@realApi`, and its fake is registered `@mockApi` in
/// `MockApiModule`.
const realApi = Environment('real');
const mockApi = Environment('mock');

/// The environment name `getIt.init` takes for [mode].
String apiEnvironment(ApiMode mode) => switch (mode) {
  ApiMode.real => realApi.name,
  ApiMode.mock => mockApi.name,
};
