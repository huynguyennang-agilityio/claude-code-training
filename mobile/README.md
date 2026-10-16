# StrideQuest mobile app

Flutter app for StrideQuest. See the [root README](../README.md) for setup and [`docs/architecture.md`](../docs/architecture.md) for the diagrams.

Code is organised by feature (Clean Architecture). `features/auth` is the reference implementation; `features/home` holds the home page.

- `lib/core/`: app-wide setup: DI (`get_it` + `injectable`), `go_router` config and auth redirect, Dio client, errors, theme, config.
- `lib/shared/`: widgets, extensions and utils used by several features.
- `lib/features/<feature>/` (`auth`, `challenges`, `runs`, `medals`), each with three layers:
  - `data/`: data sources (API, secure storage, Apple Health / Health Connect), Freezed models, repository implementations.
  - `domain/`: pure Dart entities, repository interfaces and optional use cases.
  - `presentation/`: blocs, pages and widgets.

Dependencies point inward: `presentation` and `data` depend on `domain`, and `domain` depends on neither.

Auth today:
- **Session:** `AuthRepositoryImpl` keeps it (user and tokens) in secure storage.
- **Networking:** the `authenticatedDio` instance adds the access token and refreshes it once on `token_expired` / `invalid_token`. Requests that fail together share one refresh. Only a rejected refresh token (`invalid_refresh_token`) signs the user out; a network or server error during refresh keeps the session.
- **Session changes:** `AuthRepositoryImpl` runs sign-in, sign-out, refresh and expiry one at a time, so a refresh in flight can't bring back a session after sign-out.
- **Redirects:** the router redirects to `/sign-in` for paths in `protectedPaths`. Home is public, and `/sign-in` is a placeholder until the sign-in screen has its own issue.

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/core/di/injection.config.dart`) are committed. Regenerate them with `dart run build_runner build --force-jit`.
