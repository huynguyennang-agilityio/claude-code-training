# Plan 015: Golden tests in CI

Status: approved
Approved: 2026-10-22
Issues: <filled in after approval>

## Context

Plan 014 (assumption 8) expected the `alchemist` CI goldens to match on `ubuntu-latest`, because they draw text as solid blocks. They do not. The first `mobile` run of PR #45 ([run 39570941137](https://github.com/huynguyennang-agilityio/claude-code-training/actions/runs/39570941137)) failed **all 39 golden tests** by 88 to 341 pixels (0.01% to 0.02% of each image); the other 680 tests passed. So the planned fallback was applied: `mobile-ci.yml` runs `flutter test --exclude-tags golden`, and the goldens run only on the developer's Mac (the `Stop` hook runs a plain `flutter test`).

Today nothing on GitHub checks the screens. A PR that shifts a layout passes CI, and the `code-reviewer` review only sees the image diff if the author regenerated the baseline. This plan decides how golden tests come back into CI.

What we know about the difference:

- Text is not the cause: CI goldens replace it with blocks. What is left is anti-aliasing at the edges of rounded corners, icons, borders and shadows, drawn by the engine's software rasterizer in `flutter_tester`.
- The baselines were made on an Apple Silicon Mac (arm64). `ubuntu-latest` is x86_64. Skia's rasterizer has separate SIMD code paths per CPU architecture, so the most likely cause is **the architecture, not the operating system**. That is a hypothesis; issue 1 tests it.
- `CLAUDE.md` already says "generate and compare goldens on the same platform", while the UI evidence row and `flutter_test_config.dart` still say the CI goldens are "the same on every machine". The second claim is wrong and has to go.

## Open questions and assumptions

1. **The repo stays public (assumption).** Standard GitHub-hosted runners, including macOS and `ubuntu-24.04-arm`, cost nothing for public repositories; the limits are concurrency (5 macOS jobs at a time on the free plan) and queue time. If the repo becomes private, a macOS minute counts 10 times. Issue 1 confirms the current terms in GitHub's docs and notes them in its PR.
2. **The developer works on Apple Silicon (assumption).** The baselines were made there, and the user's machine is a Mac. Nobody updates goldens from Linux, Windows or an Intel Mac today.
3. **Flutter for Linux arm64 (question for issue 1).** `subosito/flutter-action` must install Flutter `3.38.5` on `ubuntu-24.04-arm`. If no Linux arm64 SDK is available for that version, the arm64 Linux candidate drops out.
4. **Which runner matches (question for issue 1).** Decided by measurement, with the rule in Approach "Decision rule", which this approval covers in advance.
5. **Tolerance numbers (question, only if needed).** If no runner matches, option C needs real numbers (largest per-pixel channel delta and pixel count on Linux). Issue 1 collects them so a revised plan can choose.

## Options

| | A. Linux x86_64 is the golden platform | B. Goldens on a macOS runner | C. Tolerant comparator | D. Goldens on an arm64 Linux runner |
| --- | --- | --- | --- | --- |
| What changes | Regenerate all baselines on `ubuntu-latest` (a `workflow_dispatch` job that uploads them as an artifact, or a pinned x86_64 Docker image) | A `goldens` job on `macos-15` runs `flutter test --tags golden`; baselines stay as they are | A `GoldenFileComparator` in `flutter_test_config.dart` that accepts a small difference; goldens run in the existing Ubuntu job | A `goldens` job on `ubuntu-24.04-arm`; baselines stay as they are |
| Developer on macOS | Cannot check or update goldens locally. Pushes, waits for the update workflow, downloads the images and commits them; or runs Docker with `--platform linux/amd64` under emulation, which is slow and may itself differ | Unchanged: `flutter test --update-goldens --tags golden` | Unchanged | Unchanged; can also reproduce CI with an arm64 Linux Docker image |
| Local `Stop` hook | Must skip the `golden` tag off Linux, or every Mac session fails 39 tests | Unchanged | Unchanged | Unchanged |
| `goldenScreen` | Code unchanged; its doc comment points to the update workflow | Unchanged | Unchanged (the comparator is global) | Unchanged |
| CLAUDE.md "same platform" rule | Holds, with Linux x86_64 as the platform; Claude can no longer produce golden evidence in a local session | Holds: the platform is macOS on Apple Silicon | Relaxed: "the same within the tolerance" | Holds: the platform is arm64 (Mac and Linux), if issue 1 confirms they match |
| Catches | Every pixel | Every pixel | Misses a change smaller than the tolerance (a 1 px border on a small button can be under 0.05% of a four-scenario image of about 1.3 M pixels) | Every pixel |
| CI cost (public repo) | Free; one extra workflow | Free; a slower job (macOS setup), 5-job concurrency limit; 10× minutes if private | Free; no extra job | Free; about the speed of the current job |
| Risk | Highest friction; baselines churn once; contributors depend on CI for every UI change | The runner image's macOS or Xcode update could change rendering; pin `macos-15` and treat an update as a deliberate change | Hides real regressions; the threshold is arbitrary until measured | Hypothesis may be wrong (arm64 Linux may still differ from arm64 macOS) |

Not considered further: keeping goldens out of CI (today's state) and per-platform baselines (`goldens/macos/`, `goldens/linux/`), which double every baseline and its review.

## Approach

Recommended: **D, then B, chosen by measurement**. Both keep the baselines and the developer's workflow exactly as they are, keep the "same platform" rule true (the platform is Apple Silicon / arm64), and compare every pixel. A is the most friction for the one developer, and C weakens what the tests catch.

### Decision rule (approved with this plan)

Issue 1 runs `flutter test --tags golden` against the committed baselines on `ubuntu-24.04-arm` and on `macos-15`, twice each.

1. If `ubuntu-24.04-arm` passes both times: choose **D**.
2. Otherwise, if `macos-15` passes both times: choose **B**.
3. Otherwise: no implementation issue starts. This plan goes back to `draft` with the measurements from issue 1, and a revised plan chooses between A and C.

### Changes (issue 2, for the chosen runner)

- `.github/workflows/mobile-ci.yml`: a second job `goldens` on the chosen runner (pinned label, never `*-latest`), with the same change check as `mobile` (`mobile/**`, `docs/api/**`, the workflow file) so it always reports, the same Flutter version and cache, `flutter pub get`, then `flutter test --tags golden`. On failure it uploads `mobile/test/**/failures/` as a workflow artifact (kept 7 days), so a reviewer can see the diff images, which are git-ignored. `permissions: contents: read`, no secrets. The `mobile` job keeps `--exclude-tags golden`, so no test runs twice. The comment above it explains why.
- `mobile/test/flutter_test_config.dart`: the doc comment no longer claims identical images on every operating system; it says the baselines are made on Apple Silicon and compared in CI on the chosen runner.
- `mobile/test/helpers/golden_screen.dart`: no code change. The doc comment adds that a baseline is generated on an Apple Silicon Mac.
- No test, baseline or `check.sh` change.
- **Required check (the user does it):** add `goldens` to the required status checks on the `develop` ruleset once it has run cleanly, as plan 014 assumption 4 describes for `backend` and `mobile`.

### Docs (issue 3)

- `CLAUDE.md`, Verification evidence: the golden bullet says baselines are generated on an Apple Silicon Mac and CI compares them on the chosen runner; the UI row drops "the same on every machine" and says where CI checks them. If the user ever updates goldens elsewhere, the rule is unchanged: generate and compare on the same platform.
- `.claude/skills/flutter-feature/SKILL.md` (golden test paragraph): the same platform note, and that a failed CI comparison leaves the diff images as a workflow artifact.
- `README.md`, the CI section from plan 014 issue 5: one line on the `goldens` job, and `goldens` in the list of checks to require.

### How a developer updates goldens afterwards

Unchanged from today, on an Apple Silicon Mac:

```bash
flutter test --update-goldens --tags golden
```

Look at the images, commit them, and the PR shows the image diff. If the `goldens` job fails, download the `failures` artifact from the run to see what differs. A developer without an Apple Silicon Mac cannot update a baseline; that is accepted for now (assumption 2).

Tooling only. No mobile feature, backend, API, schema or database change. No security boundary changes: the new job has a read-only token and no secrets. External cost: none while the repo is public (assumption 1); the approval should cover the macOS minutes if B is chosen and the repo later becomes private.

## Risks

- **The hypothesis is wrong and neither runner matches.** Contained by the decision rule: nothing is implemented, and the plan comes back with data.
- **A runner image update changes rendering.** A pinned label (`ubuntu-24.04-arm` or `macos-15`) still gets image updates. If goldens start failing on a PR that changed no UI, compare with a run on `develop`; the fix is a deliberate baseline regeneration on the Mac, or a plan change.
- **A local macOS or Flutter upgrade changes the baselines.** The Flutter version is pinned in CI; upgrading it locally means regenerating goldens in the same PR that bumps the pinned version.
- **Flaky goldens.** Contained by running each candidate twice in issue 1.
- **Slower PRs (B).** The macOS job runs in parallel with `mobile` and only when mobile files change.

## Verification

- Issue 1: links to the runs on both candidates (two each), the pass or fail of each, and for any failure the pixel counts from the log. If a run fails, a sample of the largest per-pixel channel delta from the `failures/` images, for option C.
- Issue 2: `actionlint` on `mobile-ci.yml`; a green `goldens` run on its own PR; a red run on a throwaway commit that changes one spacing token, with the `failures` artifact attached, then green after reverting it; a docs-only PR where `goldens` passes without running tests; `flutter test --exclude-tags golden` still in the `mobile` job.
- Issue 3: the diff, and `grep -n "every machine" CLAUDE.md mobile/test/flutter_test_config.dart` with no match.
- Not verified: a developer on Intel or Linux updating a baseline (out of scope, assumption 2).

## Ticket evidence

Chore for every issue: the scope is above. Behaviour that must stay unchanged: every test, every committed baseline, `goldenScreen`'s behaviour, the local `Stop` hook and the `backend` and `mobile` jobs (apart from comments). No images needed. Verification evidence is the workflow run links and artifacts.

## Issues to create

The repo has no `ci` label, so every issue uses `chore` or `docs`.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `ci: find a runner that matches the golden baselines` | chore | - [ ] A throwaway branch and PR (closed unmerged) runs `flutter test --tags golden` on Flutter 3.38.5 on `ubuntu-24.04-arm` and `macos-15`, twice each, against the committed baselines<br>- [ ] The result is posted on the issue: run links, pass or fail, pixel counts for any failure, and the choice by the decision rule (D, B, or back to the plan)<br>- [ ] If both fail: the largest per-pixel channel delta and diff pixel count on `ubuntu-latest` and on the arm64 candidates, for a revised plan<br>- [ ] Confirms GitHub's current runner pricing for public repos and whether Flutter 3.38.5 installs on Linux arm64<br>- [ ] No change merged to `develop` | none (the spike uses its own throwaway workflow; it does not need PR #45) |
| 2 | `ci: run golden tests on <runner>` | chore | - [ ] `mobile-ci.yml` has a `goldens` job on the runner chosen in issue 1, pinned label, always reporting through the same change check, `contents: read`, no secrets<br>- [ ] It runs `flutter test --tags golden`; on failure it uploads `failures/` as an artifact; the `mobile` job keeps `--exclude-tags golden`<br>- [ ] Doc comments in `flutter_test_config.dart` and `golden_screen.dart` updated; no test or baseline changed<br>- [ ] Evidence: `actionlint`; green run; red run with the artifact on a deliberate spacing change, then green; a docs-only PR passing `goldens` without tests | 1 |
| 3 | `docs: say where golden tests are generated and checked` | docs | - [ ] `CLAUDE.md` golden bullet and UI row updated as in Approach "Docs"; no "every machine" claim left<br>- [ ] `flutter-feature` skill golden paragraph updated<br>- [ ] `README.md` CI section mentions the `goldens` job and lists it as a required check<br>- [ ] Evidence: the diff and the `grep` with no match | 2 |

## Out of scope

- Per-platform baselines and golden updates from Linux, Windows or Intel Macs.
- Real-font (platform) goldens: `platformGoldensConfig` stays off.
- Changing `goldenScreen`'s sizes, text scales or scenarios.
- Note for later plans: plan 014's "Out of scope" names plans 015 and 016 for scheduled tasks and routines; those take the next free numbers instead.
