# StrideQuest mobile app

Flutter app for StrideQuest. See the [root README](../README.md) for setup and [`docs/architecture.md`](../docs/architecture.md) for the diagrams.

Code is organised by feature (Clean Architecture). Older code under `lib/ui`, `lib/data` and `lib/logic` is being moved to this layout.

- `lib/core/`: app-wide setup: DI (`get_it` + `injectable`), `go_router` config and auth redirect, Dio client, errors, theme, config.
- `lib/shared/`: widgets, extensions and utils used by several features.
- `lib/features/<feature>/` (`auth`, `challenges`, `runs`, `medals`), each with three layers:
  - `data/`: data sources (API, secure storage, Apple Health / Health Connect), Freezed models, repository implementations.
  - `domain/`: pure Dart entities, repository interfaces and optional use cases.
  - `presentation/`: blocs, pages and widgets.

Dependencies point inward: `presentation` and `data` depend on `domain`, and `domain` depends on neither.
