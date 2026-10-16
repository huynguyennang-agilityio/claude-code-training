---
name: flutter-feature
description: Step-by-step guide for adding or extending a StrideQuest Flutter feature under mobile/lib/features/ (domain, data, presentation, routing, DI and tests), following the patterns of features/auth. Use when creating a new feature, screen, bloc, repository, data source or model in the mobile app.
---

# Flutter feature

How to build a feature in `mobile/lib/features/<feature>/` the way `features/auth` is built. The rules themselves live in [`CLAUDE.md`](../../../CLAUDE.md) and [`docs/architecture.md`](../../../docs/architecture.md). This skill shows how to apply them and points to the code that already does. If this file and CLAUDE.md disagree, CLAUDE.md wins; fix this file.

Paths below are relative to `mobile/` unless they start with `docs/` or `.claude/`. Examples use a `challenges` feature; swap in your own names.

## Before you start

1. Make sure the issue has its ticket evidence and acceptance criteria (CLAUDE.md, Phase 1).
2. Read the API contract in `docs/api/<feature>.md`. If it doesn't exist yet, the contract comes first (CLAUDE.md, Phase 2).
3. Read the reference files listed under each step below. Copy their shape, not just the snippets here.

## Build order

Build inside out: domain, then data, then presentation, then routing. Add the tests for each layer as you go.

```text
lib/features/challenges/
├── challenges_module.dart          # only if one class is exposed under several interfaces
├── domain/                         # pure Dart
│   ├── entities/challenge.dart
│   ├── failures/challenge_failure.dart
│   ├── repositories/challenge_repository.dart
│   └── usecases/                   # optional, see step 1
├── data/
│   ├── datasources/challenge_remote_data_source.dart
│   ├── models/challenge_model.dart
│   └── repositories/challenge_repository_impl.dart
└── presentation/
    ├── bloc/challenge_detail_{bloc,event,state}.dart
    ├── pages/challenge_detail_page.dart
    └── widgets/
```

There are no barrel files. Import each file directly.

### 1. Domain (pure Dart)

Reference: `lib/features/auth/domain/`.

- **Imports:** only `equatable`, `freezed_annotation` and `lib/core/error/failure.dart`. No Flutter, Dio or storage.
- **Entities** extend `Equatable` and have `const` constructors with `final` fields. See `entities/auth_user.dart`.
- **Failure:** one typed failure per feature, shaped like `failures/auth_failure.dart`:
  - a code enum whose values carry the backend `wireCode` (the `error.code` of `ErrorResponse`) and a `defaultMessage` that is safe to show the user;
  - `fromWire()` that falls back to `unknown`;
  - always a `network` and an `unknown` code;
  - a class that extends `Failure` and keeps extra details (`fieldErrors`, `retryAfter`) when the API sends them.
- **Repository interface:** an `abstract interface class` whose doc comment says which failure every method throws. Return entities, never models or DTOs. See `repositories/auth_repository.dart`.
- **Use cases** are optional. Add one only when logic spans several repositories or is reused (CLAUDE.md). Otherwise the bloc calls the repository interface.

```dart
/// Lists and reads challenges.
///
/// Every method throws [ChallengeFailure] on error.
abstract interface class ChallengeRepository {
  Future<List<Challenge>> list();

  Future<Challenge> byId(String id);
}
```

### 2. Data

References: `lib/features/auth/data/`, `lib/core/di/network_module.dart` and `mobile/build.yaml`.

**Models** are Freezed classes with `fromJson` and `toEntity()`. `build.yaml` sets `field_rename: snake`, so Dart fields stay camelCase without `@JsonKey`. See `models/auth_user_model.dart`.

```dart
@freezed
abstract class ChallengeModel with _$ChallengeModel {
  const factory ChallengeModel({required String id, required String title}) =
      _ChallengeModel;

  const ChallengeModel._();

  factory ChallengeModel.fromJson(Map<String, dynamic> json) =>
      _$ChallengeModelFromJson(json);

  Challenge toEntity() => Challenge(id: id, title: title);
}
```

**Remote data source:** an interface plus a Dio implementation registered with `@LazySingleton(as: ...)`. See `datasources/auth_remote_data_source.dart`.

- Inject the right `Dio` by name:
  - `@Named('authenticatedDio')` for endpoints that need a signed-in user. Its `AuthInterceptor` adds the token and, on a 401 `token_expired`/`invalid_token`, refreshes it once and retries.
  - `@Named('publicDio')` only for endpoints that take no token.
- Request paths are relative (`challenges/$id`), with no leading slash.
- Map every error to the feature's failure. Never let a raw `DioException`, `TypeError` or `FormatException` escape. How you get there depends on the `Dio`, because the interceptor only sees errors that Dio raises.

**On `publicDio`**, follow auth's `_post`/`_parse`/`_failure` structure in `auth_remote_data_source.dart`. It accepts every status (`validateStatus: (_) => true`) and decodes the body itself (`ResponseType.plain`):

- `DioException` and `TimeoutException` are transport errors and become `network`;
- a non-2xx response with an `ErrorResponse` body becomes `fromWire(error.code)`. Any other non-2xx body (a proxy error page, for example) becomes `unknown`, unless the status alone says more: auth maps a bare 429 to `rate_limited`;
- a missing or malformed success body becomes `unknown`. Catch `TypeError` explicitly, because a failed cast is an `Error`, not an `Exception`.

**On `authenticatedDio`, don't copy `_post`.** With `validateStatus: (_) => true` a 401 never reaches `AuthInterceptor.onError`, and with `ResponseType.plain` its `_isExpiredToken` can't read the body. Either way the token is never refreshed. No feature uses `authenticatedDio` yet, so this pattern comes from reading `lib/core/network/auth_interceptor.dart`, not from working code:

- keep Dio's default `validateStatus` and JSON response type, so a 401 raises a `DioException` that the interceptor can refresh and retry;
- an error that is still raised after that is a `DioException`. Map it in this order:
  1. `type == DioExceptionType.badResponse` with a response: go through `fromWire` (or `unknown`/429) like the `publicDio` case, using `err.response`. Never map a `badResponse` to `network`.
  2. `err.error is FormatException`: becomes `unknown`. Dio decodes a JSON body before it checks the status, so a malformed body, on a 2xx or an error status, arrives as type `unknown` with this error and no response. It is a server or proxy fault, not a connection problem.
  3. Everything else becomes `network`: timeouts, `connectionError`, `badCertificate`, `cancel`, and `unknown` wrapping a socket error.
- a body that decodes but doesn't fit the model still fails in `fromJson` and becomes `unknown`, as on `publicDio`;
- after a refresh is rejected or fails, the interceptor passes the original 401 on, so the feature still sees `token_expired`/`invalid_token`. Give the feature's failure enum `not_authenticated`, `token_expired` and `invalid_token` codes, with the same messages as `AuthFailureCode`. Otherwise the user sees "Something went wrong". Signing the user out is not the feature's job: `AuthBloc` and the router redirect handle that.

If a second feature needs the same helpers, propose moving them to `lib/core/network/` in their own issue instead of copying them.

**Repository implementation** implements the domain interface and is registered with `@LazySingleton(as: ChallengeRepository)`. It calls data sources, maps models to entities and holds no UI state. See `repositories/auth_repository_impl.dart`.

- Use a `@module` file (like `auth_module.dart`) only when one class must be exposed under several interfaces.
- Local storage goes through its own data source (see `auth_local_data_source.dart`), never directly from the repository.

### 3. Presentation

Reference: `lib/features/auth/presentation/bloc/`.

**Events and states** are `sealed` base classes with `final class` subtypes, all `Equatable` and `const`. They live in `part` files of the bloc. Name them after what happened (`ChallengeDetailRequested`) and what the screen shows (`ChallengeDetailLoaded`), not with generic names like `Success`. Don't add a loading state when the initial state already means "loading", as `AuthUnknown` does.

**The bloc** depends on the repository interface, and catches only the feature's failure:

```dart
@injectable // a factory; see "Route-scoped blocs" below
class ChallengeDetailBloc
    extends Bloc<ChallengeDetailEvent, ChallengeDetailState> {
  ChallengeDetailBloc(this._repository)
    : super(const ChallengeDetailLoading()) {
    on<ChallengeDetailRequested>(_onRequested);
  }

  final ChallengeRepository _repository;

  Future<void> _onRequested(
    ChallengeDetailRequested event,
    Emitter<ChallengeDetailState> emit,
  ) async {
    emit(const ChallengeDetailLoading());
    try {
      emit(ChallengeDetailLoaded(await _repository.byId(event.id)));
    } on ChallengeFailure catch (failure) {
      emit(ChallengeDetailFailed(failure));
    }
  }
}
```

- Never `catch (e)` and never show `e.toString()`. Show `failure.message`, which is safe for users.
- Cancel stream subscriptions in `close()`. `AuthBloc` does this for `sessionExpired`.

**Route-scoped blocs (from CLAUDE.md; `features/auth` has no example).** `AuthBloc` is the only app-wide bloc (`@lazySingleton`). Every other bloc is a factory (`@injectable`, which `injectable` registers with `registerFactory`). It is created in the route's `BlocProvider`, so it closes with the route. Don't add another app-wide bloc without the user's approval.

**Pages and widgets:**

- Keep business logic in the bloc. Widgets dispatch events and render states, using `switch` on the sealed state.
- Use `BlocListener` for one-off effects such as a `SnackBar` with `failure.message`, and `BlocBuilder` for rendering.
- Take colors and text styles from `Theme.of(context)` (`colorScheme`, `textTheme`). No `Color(0x…)`, `Colors.*` or inline `TextStyle(fontSize: …)` in features. The app has no design tokens yet; adding them is a separate Phase 0 issue.
- Give each page a `static const path`, like `HomePage.path`.
- Prefer `const` constructors and small widgets in `presentation/widgets/`. A widget used by several features goes in `lib/shared/widgets/`, which CLAUDE.md plans but nobody has created yet. Create it the first time it's needed.
- If the ticket needs a design reference and has none, ask for it before writing UI (CLAUDE.md ticket evidence gate). Build a placeholder page like `sign_in_page.dart` only when the issue explicitly scopes the UI out.

### 4. Routing

Reference: `lib/core/router/app_router.dart`.

- Add a `GoRoute` to `appRoutes`. Routes carry IDs only (`/challenges/:id`), never objects in `state.extra`.
- Create the page's bloc in the route and send its first event there:

```dart
GoRoute(
  path: ChallengeDetailPage.path, // '/challenges/:id'
  builder: (context, state) => BlocProvider(
    create: (_) => getIt<ChallengeDetailBloc>()
      ..add(ChallengeDetailRequested(state.pathParameters['id']!)),
    child: const ChallengeDetailPage(),
  ),
),
```

- If the page needs a signed-in user, add its path to `protectedPaths`. Never navigate on sign-in or sign-out from a widget; the router redirect does that.
- **`protectedPaths` only matches exact, static locations.** `authRedirect` checks `protected.contains(state.matchedLocation)`, and `matchedLocation` is the concrete location (`/challenges/abc`), not the pattern. Adding `'/challenges/:id'` protects nothing: a signed-out user can still open the page. Before protecting a route with path parameters, `authRedirect` has to change. That is a security boundary, so it needs its own issue and the user's approval (CLAUDE.md, Phase 2). Stop and say so; don't work around it in the feature.

### 5. Tests

`test/` mirrors `lib/`. Every feature needs tests (CLAUDE.md), and failure paths count as much as success paths.

| Layer | Pattern | Reference |
| --- | --- | --- |
| Bloc | `blocTest` with a `mocktail` mock of the repository interface; assert the ordered states, including the failure state | `test/features/auth/presentation/bloc/auth_bloc_test.dart` |
| Remote data source | A real `Dio` from `createDio(baseUrl: 'http://api.test/', adapter: FakeHttpAdapter(...))`, so no network is used; cover success, each mapped error code, a non-`ErrorResponse` body, a malformed body and a transport error. On `authenticatedDio`, also: a 401 `token_expired` is refreshed and retried, a 4xx `ErrorResponse` doesn't become `network`, and a malformed JSON body (on 200 and on 400) becomes `unknown` | `test/features/auth/data/datasources/auth_remote_data_source_test.dart`, `test/helpers/fake_http_adapter.dart` |
| Repository | Mocked data sources; check the model-to-entity mapping and that failures pass through | `test/features/auth/data/repositories/auth_repository_impl_test.dart` |
| Page | `MockBloc` from `bloc_test`; the page renders each state, and taps add the right events | `docs/architecture.md`, section on tests |
| Route | The path builds the page; a protected path redirects to sign in when signed out, using a concrete location (`/challenges/abc`), not the pattern | `test/core/router/app_router_test.dart` |
| DI | `getIt` resolves the new repository, and returns a new bloc instance on each call (a factory, unlike `AuthBloc`) | `test/core/di/injection_test.dart` |

Put shared test data in `test/helpers/<feature>_fixtures.dart`, like `auth_fixtures.dart`.

### 6. Generate, check and record evidence

From `mobile/`:

```bash
dart run build_runner build --force-jit
flutter analyze
flutter test
```

Commit the generated `*.freezed.dart`, `*.g.dart` and `injection.config.dart` files. Then record the results as verification evidence (CLAUDE.md, Phase 3), using the "Bloc / logic" and "UI" rows.

## Checklist before reporting done

- [ ] `domain/` imports nothing from Flutter, Dio or storage.
- [ ] The bloc depends on the repository interface, not the implementation.
- [ ] Every data source error becomes the feature's typed failure; no catch-all in the bloc.
- [ ] Data sources on `authenticatedDio` keep the default `validateStatus`, so the token refresh still runs. A malformed body becomes `unknown`, not `network`, and the failure enum has the session codes.
- [ ] No path with parameters was added to `protectedPaths`.
- [ ] Events and states are sealed/final, `const` and `Equatable`.
- [ ] The bloc is `@injectable` and created in the route's `BlocProvider`; routes pass IDs only.
- [ ] No hard-coded colors or text styles in the feature.
- [ ] Tests cover the bloc, data source, repository and page, including failure paths.
- [ ] Code generation is re-run and committed; `flutter analyze` and `flutter test` pass.
- [ ] The `## Evidence` section is drafted.
