/// Which remote data sources the app talks to (see `AppConfig.apiMode`).
enum ApiMode {
  /// The StrideQuest API at `AppConfig.apiBaseUrl`.
  real,

  /// The in-memory `Fake…RemoteDataSource` classes, for building screens
  /// before the backend exists. Debug builds only.
  mock,
}

/// The mode the `API_MODE` setting [raw] asks for.
///
/// Only a debug build ([isDebug]) can use [ApiMode.mock]; anything else,
/// including an unknown or empty value, is [ApiMode.real]. Takes [isDebug]
/// instead of reading `kDebugMode`, which is always true under `flutter test`.
ApiMode resolveApiMode(String raw, {required bool isDebug}) =>
    isDebug && raw.trim().toLowerCase() == ApiMode.mock.name
    ? ApiMode.mock
    : ApiMode.real;
