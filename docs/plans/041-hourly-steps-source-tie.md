# Plan 041: Source ties in hourly steps on Android (fix for PR #279 of #256)

Status: approved
Approved: 2026-11-02, by the user in chat: "/approve-plan 041"
Issues: <filled in after approval>
Draft: https://claude.ai/artifact/AD3qtYRpGFCka7x3cGJWTj, version 1793610084-5db3

## Context

Areas: area:health · 1 task.

Based on: [plan 030](https://claude.ai/artifact/LKcS1jRj4Mq8V1zwMVhTNC) (`docs/plans/030-health-sync-single-session.md`, task 7), [PR #279](https://github.com/huynguyennang-agilityio/claude-code-training/pull/279), issue #256.

The run `/run-tasks 256 257 258 259` of 2026-11-02 stopped all 4 issues. #256 stopped because the second (final) `claude-review` run on PR #279, commit `457de6c`, requested changes. #257, #258 and #259 stopped at their wait gate because they depend on #256 (directly or through #257).

The final review raised two Low findings about the same bug:

- **Correctness**, `mobile/lib/features/runs/data/datasources/health_data_source.dart:321-325`: in `stepHoursFromSlices` (the Android path), when two sources have the same whole-hour total (`whole`), the source is chosen by `inside`, and `inside` changes with the range `[from, to)`. Two ranges that meet inside an hour can choose two different sources, which contradicts the doc comments at `:39-42` and `:262-268`. Example: a +05:30 zone (day boundary at 18:30Z), source `a` has 60 steps from 18:00 to 18:30Z, source `b` has 60 steps from 18:30 to 19:00Z. Day 1 chooses `a` (60), day 2 chooses `b` (60), the two days add up to 120, while `stepHours` over the whole range gives that hour 60.
- **Tests**, `mobile/test/features/runs/data/health_data_source_test.dart:207-239`: the split-hour test gives `b` 50 steps, so it never reaches the tie branch.

Security scan: no findings. The required checks are green on `457de6c`. The review checked the rest of the PR (iOS, `readDays`, `_hourCeil`, the read window on whole hours) and found nothing.

## Open questions and assumptions

You can answer by number, for example "change 1".

1. **Replace #256 with a new issue (task 1)**, as plan 040 did with #253: an issue's body is the spec a child session reads, and Claude does not edit issue bodies. The new issue has every criterion of #256 plus the criterion about source ties. After `/approve-plan 041`, #256 is closed with the comment `Superseded by #<task 1> (plan 041)`; by CLAUDE.md, closing #256 needs your own authorization.
2. **Continue on PR #279**, without opening a new PR: the child session creates the local branch `feat/256-read-hourly-steps-rerun-<run-id>` from `origin/feat/256-read-hourly-steps`, merges `origin/develop`, and every push is `git push origin HEAD:feat/256-read-hourly-steps` (as in the "Rerun" section of `/run-tasks`). The PR description changes `Closes #256` to `Closes #<task 1>`, and `Plan:` points to plan 041. The PR gets a new budget of two reviews; the first is asked for by `@claude review` after the first push.
3. **Tie rule:** for each hour, choose the source with the largest `whole`; when `whole` is equal, choose the source whose name (the map key) comes first in string order (`String.compareTo`). Drop `inside` from the comparison; `inside` is only used to count the steps inside the range. The result no longer depends on `[from, to)`.
4. **The dependent issues:** #257 depends on #256; that dependency is read as a dependency on task 1, and `/approve-plan` writes a comment saying so on #257. #258 and #259 depend on #257, so they don't change. After approval, rerun the whole group in one command: `/run-tasks <task 1> 257 258 259`.
5. **The existing evidence is reused:** the comparison on a real iPhone in PR #279 (the hourly sum equals HealthKit's daily statistics on 8 days, reading 30 days takes 61 ms) still holds, because the iOS path does not change. The `Not verified` lines keep their reasons: a visual comparison with the Health app screen, leaving out manual entries on the device (the phone has no manual entries), Android (no Android device), several sources on iOS (no Apple Watch).
6. **Out of scope:** the run's process lesson (a Low finding in an edge case in the second review stopped the issue; such a finding could go under `## Nits left`). Changing the review rules needs its own `area:infra` plan.

## Approach

- `health_data_source.dart`: in the reducer of `stepHoursFromSlices`, iterate over `bySource.entries`; keep the entry with the larger `whole`, or, when they are equal, the entry with the smaller key. Update the doc comments at `:39-42` and `:262-268` to state the tie rule by source name.
- `health_data_source_test.dart`: add the review's 60/60 test (a +05:30 zone, boundary at 18:30Z): `first + second == 60`, equal to that hour's value in `stepHours` over the whole range. Keep the existing 60/50 test. Add a tie test within a single range: the result is the source whose name comes first.
- No change to the iOS path, `readDays`, the domain, the API or the schema.

### Changes the approval must cover (Phase 2 risk categories)

None: no public API, schema, auth, architecture, real data or cost is affected. Replacing #256 with a new issue and closing #256 (assumption 1) is the only process change.

## Risks

- **Health Connect may return only the records that lie fully inside the read window** (noted by the review under "Not checked"). Then a record that starts before the whole hour and runs into the split hour could be seen by one read and not the other, so the two reads compute different `whole` totals. Containment: the read window is already widened to whole hours `[_hourFloor(from), _hourCeil(to))`, so two adjacent reads both see the whole split hour. The rest cannot be checked on a real device: `Not verified: no Android device`.
- **Choosing by source name may differ** from the "right" source when two sources tie. Accepted: in a tie, both sources give the same number of steps, so that hour's figure does not change.
- **Changing `Closes` on PR #279** may be forgotten, so #256 closes by itself while the new issue stays open. Containment: task 1's criteria require the PR description to have `Closes #<task 1>`.

## Verification

- `flutter test test/features/runs/data/health_data_source_test.dart`: the 60/60 test fails on `457de6c` and passes after the fix.
- `flutter analyze` and the full `flutter test` are clean; the `mobile` and `goldens` checks are green on the PR.
- Cannot be checked here: Android and Health Connect on a real device (`Not verified: no Android device`), several sources on iOS (`Not verified: no Apple Watch`).

## Ticket evidence

- Type: a bug in an unmerged PR (task 7 of plan 030). The failure scenario is in the `## Claude review · 457de6c` comment on PR #279 (the data, the step counts, the 18:30Z boundary and the result 120 instead of 60).
- Reproduction: the 60/60 test above, run on `457de6c`, gives `first + second == 120`.

## Task breakdown

One task is one issue.

### Phase 1: Finish reading steps by hour

#### Task 1: `[health] feat: read hourly steps without duplicates, source tie by name (mobile)`

**Description:** Replaces #256 (plan 030, task 7) by assumption 1, continuing on PR #279 (branch `feat/256-read-hourly-steps`) by assumption 2. Keep what PR #279 has done (`StepHour`, `HealthRepository.readStepHours`, the iOS path, `readDays` without manual entries, the read window on whole hours) and fix the final review's two findings: in `stepHoursFromSlices`, a `whole` tie is broken by source name instead of `inside` (assumption 3), and add a 60/60 tie test in a split hour. The description of PR #279 changes to `Closes #<task 1>` with `Plan: docs/plans/041-hourly-steps-source-tie.md`.

**Acceptance criteria:**
- [ ] `HealthRepository.readStepHours` returns one `StepHour` per UTC hour with steps, without manual entries
- [ ] Test: two overlapping sources in one hour give the larger source's total, not the sum
- [ ] On Android, when two sources have the same whole-hour total, `stepHoursFromSlices` chooses the source whose name comes first, independent of the range `[from, to)`; test: in a +05:30 zone, source `a` has 60 steps from 18:00 to 18:30Z and source `b` has 60 steps from 18:30 to 19:00Z, the sum of the two days on either side of the 18:30Z boundary is 60, equal to that hour's value in `stepHours` over the whole range
- [ ] `HealthRepository.readDays` counts steps without manual entries, by the same rule as `readStepHours`: a test day with a manual entry gives the same steps as the sum of that day's `readStepHours` (whole-hour time zone); calories, distance and sleep are unchanged
- [ ] Evidence: on a real iPhone, the day's hourly sum matches the Health app's daily total, and reading 30 days takes under 3 s; Android: `Not verified: no Android device`
- [ ] The description of PR #279 has `Closes #<task 1>` and `Plan: docs/plans/041-hourly-steps-source-tie.md`, and no longer `Closes #256`
- [ ] `flutter analyze` and `flutter test` pass

**Verification:**
- [ ] Tests pass: `flutter test` in `mobile/`
- [ ] Lint and type checks: `flutter analyze`
- [ ] Manual check: the 60/60 test fails when run on `457de6c` (sum 120) and passes after the fix
- [ ] Evidence section filled in, reusing the iPhone comparison of PR #279 (assumption 5)

**Dependencies:** None

**Files likely touched:**
- `mobile/lib/features/runs/data/datasources/health_data_source.dart`
- `mobile/test/features/runs/data/health_data_source_test.dart`
- `mobile/PROGRESS.md` (the line of PR #279 uses the new issue number)

**Estimated scope:** XS: 2–3 files, about 40 lines beyond what PR #279 already has

#### Checkpoint: Reading by hour merged
- [ ] PR #279 merged with `Closes #<task 1>`; checks on `develop` green
- [ ] #256 closed with a "Superseded" comment (when you authorize it)
- [ ] Suggested command: `/run-tasks <task 1> 257 258 259`

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[health] feat: read hourly steps without duplicates, source tie by name (mobile)` | frontend, area:health | - [ ] `HealthRepository.readStepHours` returns one `StepHour` per UTC hour with steps, without manual entries<br>- [ ] Test: two overlapping sources in one hour give the larger source's total, not the sum<br>- [ ] On Android, when two sources have the same whole-hour total, `stepHoursFromSlices` chooses the source whose name comes first, independent of the range `[from, to)`; test: in a +05:30 zone, source `a` has 60 steps from 18:00 to 18:30Z and source `b` has 60 steps from 18:30 to 19:00Z, the sum of the two days on either side of the 18:30Z boundary is 60, equal to that hour's value in `stepHours` over the whole range<br>- [ ] `HealthRepository.readDays` counts steps without manual entries, by the same rule as `readStepHours`: a test day with a manual entry gives the same steps as the sum of that day's `readStepHours` (whole-hour time zone); calories, distance and sleep are unchanged<br>- [ ] Evidence: on a real iPhone, the day's hourly sum matches the Health app's daily total, and reading 30 days takes under 3 s; Android: `Not verified: no Android device`<br>- [ ] The description of PR #279 has `Closes #<task 1>` and `Plan: docs/plans/041-hourly-steps-source-tie.md`, and no longer `Closes #256`<br>- [ ] `flutter analyze` and `flutter test` pass | none |
