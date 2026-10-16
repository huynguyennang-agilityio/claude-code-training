/// Build-time settings, passed with `--dart-define`.
abstract final class AppConfig {
  /// The StrideQuest API base, including the `/api/v1/` prefix
  /// (see `docs/api/auth.md`).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1/',
  );
}
