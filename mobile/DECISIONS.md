# Mobile decisions and gotchas

Loaded through `mobile/CLAUDE.md` whenever Claude works on files under `mobile/` ([plan 019](../docs/plans/019-area-autopilot.md)).

- One entry: at most three lines, with its date and issue or plan. Newest at the end.
- Gotchas (odd bugs and how to avoid them), conventions the AI gets wrong, small decisions. A large decision is an ADR in `docs/adr/`; the entry only links to it.
- Keep this file under 4 KB. Remove an entry once a test or lint enforces it.
- Claude never edits this file during `/run-tasks`. It proposes entries in the PR description, and the user picks them.

## Entries

- **2026-10-23, plan 002.** On `authenticatedDio`, never send `validateStatus: (_) => true`: a `401` then arrives as a normal response, `AuthInterceptor.onError` never runs, and the token is never refreshed. Test the interceptor together with the data source.
- **2026-10-23, skill `flutter-feature`.** `protectedPaths` matches the concrete location (`/challenges/abc`), not the route pattern. Adding `'/challenges/:id'` protects nothing.
- **2026-10-23, CLAUDE.md.** The theme tokens guard reads source text, so a raw color or size passed through a variable slips past it. The rule still applies: add the value to `app_tokens.dart`.
- **2026-10-23, plan 015.** Golden baselines only match on macOS (Apple Silicon). Generate them there with `flutter test --update-goldens --tags golden`; CI checks them in the `goldens` job on `macos-15`.
- **2026-10-23, plan 009.** A `Fake<Feature>RemoteDataSource` fixture must equal its file in `docs/api/examples/`; `flutter test test/contract` checks it. Change the example first, then the fixture.
- **2026-10-23, CLAUDE.md.** Regenerate `freezed` and `json_serializable` code with `dart run build_runner build --force-jit` and commit the generated files.
- **2026-10-26, #125.** A screen without the tab bar is a top-level `GoRoute` above the `StatefulShellRoute` (like `ChallengeDetailPage`), not a `parentNavigatorKey` route: the app has no navigator keys.
- **2026-10-26, #125.** A text field inside `SettingsFormLayout` passes `scrollPadding: SettingsFormLayout.scrollPadding`, or its error line can end up under the keyboard.
