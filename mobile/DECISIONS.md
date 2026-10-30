# Mobile decisions and gotchas

Loaded through `mobile/CLAUDE.md`, with every `mobile/decisions/<area>.md`, whenever Claude works on files under `mobile/` ([plan 019](../docs/plans/019-area-autopilot.md), [plan 037](../docs/plans/037-decisions-per-area.md)).

- One entry: at most three lines, with its date and issue or plan. Newest at the end.
- Gotchas (odd bugs and how to avoid them), conventions the AI gets wrong, small decisions. True only in one area: `mobile/decisions/<area>.md`; another area could meet it: `mobile/DECISIONS.md`; a large technical choice: an ADR in `docs/adr/`, with a one-line entry in `mobile/DECISIONS.md` linking it. No entry repeats one in another file.
- Keep each DECISIONS file under 4 KB. Remove an entry once a test or lint enforces it.
- A `/run-tasks` child session adds its own entries in its issue's last commit, lists them under `## Decisions added` in its PR, and keeps both sides' entries when it merges `develop`. The parent never edits this file ([plan 037](../docs/plans/037-decisions-per-area.md)).

## Entries

- **2026-10-23, plan 002.** On `authenticatedDio`, never send `validateStatus: (_) => true`: a `401` then arrives as a normal response, `AuthInterceptor.onError` never runs, and the token is never refreshed. Test the interceptor together with the data source.
- **2026-10-23, skill `flutter-feature`.** `protectedPaths` matches the concrete location (`/challenges/abc`), not the route pattern. Adding `'/challenges/:id'` protects nothing.
- **2026-10-23, CLAUDE.md.** The theme tokens guard reads source text, so a raw color or size passed through a variable slips past it. The rule still applies: add the value to `app_tokens.dart`.
- **2026-10-23, plan 015.** Golden baselines only match on macOS (Apple Silicon). Generate them there with `flutter test --update-goldens --tags golden`; CI checks them in the `goldens` job on `macos-15`.
- **2026-10-23, plan 009.** A `Fake<Feature>RemoteDataSource` fixture must equal its file in `docs/api/examples/`; `flutter test test/contract` checks it. Change the example first, then the fixture.
- **2026-10-23, CLAUDE.md.** Regenerate `freezed` and `json_serializable` code with `dart run build_runner build --force-jit` and commit the generated files.
- **2026-10-26, #125.** A screen without the tab bar is a top-level `GoRoute` above the `StatefulShellRoute` (like `ChallengeDetailPage`), not a `parentNavigatorKey` route: the app has no navigator keys.
- **2026-10-26, #125.** A text field inside `SettingsFormLayout` passes `scrollPadding: SettingsFormLayout.scrollPadding`, or its error line can end up under the keyboard.
- **2026-10-27, #127.** `AuthRemoteDataSource` reaches the authenticated Dio through `DioProvider`, resolved on first use: injecting `authenticatedDio` directly makes a DI cycle (Dio → token handler → repository → data source) that crashes `injectable_generator`.
- **2026-10-27, #127.** In `AuthRepositoryImpl`, an API call that can hit a `401` runs outside `_serialized`; only the local write and the announcement run inside it, or the token refresh waits on the same queue and deadlocks.
- **2026-10-27, #129.** In an integration test, hide the snackbar left by a previous save before reopening a form: it can cover the next form's Save button.
- **2026-10-29, #190.** A test that builds a real `AuthBloc` over a mocktail `AuthRepository` stubs every repository stream, `accountDeleted` included, or the `AuthBloc` constructor throws.
- **2026-10-29, #191.** `colorScheme.onError` is dark, not white: white on the error red is 3.8:1 and fails `expectAccessible`. Use `onError` for text on an error-filled button.
- **2026-10-29, #192.** The simulator panel's typing drops characters sent before a Flutter text field has focus: tap the field, wait about 2 seconds, then type.
