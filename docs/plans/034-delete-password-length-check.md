# Plan 034: Delete account password length check

Status: approved
Approved: 2026-10-29, by the user in chat: "/approve-plan 034 https://claude.ai/artifact/1xqiFoZm9dWiAGYdafYvuX"
Issues: <filled in after approval>
Draft: https://claude.ai/artifact/1xqiFoZm9dWiAGYdafYvuX, version 1793259424-4d68

## Context

Based on: [PR #197](https://github.com/huynguyennang-agilityio/claude-code-training/pull/197) (third review, #192) · plan 031 (`docs/plans/031-delete-account.md`) · `docs/api/auth.md` (`POST /api/v1/users/me/delete`) · `ChangePasswordState` · run report 2026-10-29

### Prerequisites

- **Before `/run-tasks`:** none. No new key, secret or device.

### Problem

The backend only accepts a `current_password` of 1 to 128 characters (`DeleteAccountRequest` in `backend/app/modules/auth/schemas.py`); a longer one returns `422 validation_error`. The Delete Account screen (#191) only disables the button when the field is empty (`DeleteAccountState.canSubmit`), so pasting 129 characters still sends the request. The third review of PR #197 (#192) asked for this case to be tried, and #192 stopped because it ran out of its 2 fix rounds.

Every real password is at most 128 characters long: sign up and change password already enforce `8–128` on both mobile and backend. So a string longer than 128 is certainly wrong. If it were silently cut to 128 characters, the backend would return `403 incorrect_password` and that attempt would count toward the sign-in limit.

Also, in chat, the user wants Claude to pick the entries for `DECISIONS.md` by itself after each run from now on. Today `CLAUDE.md`, the `/run-tasks` skill and the top of both `DECISIONS.md` files still say the user picks them.

### Decided by the user

- **Option 2:** check the length on mobile, without truncating. Typing or pasting works as usual; longer than 128 characters disables the button and shows an error under the field, and no request is sent.
- **DECISIONS:** "from now on pick the DECISIONS entries yourself, no need for me to pick them".

## Open questions and assumptions

Each item has the answer the plan uses. To change an item, send its number.

1. **Error message:** `Passwords are up to 128 characters.` (in English, kept as is in code), shown through the `errorText` of the Current Password field, as in Change Password.
2. **No truncation:** no `maxLength` or `LengthLimitingTextInputFormatter`; the full string the user entered is kept.
3. **Constant:** add `DeleteAccountState.maxLength = 128`, the same value as `ChangePasswordState.maxLength`. The two constants are not merged into one place, to keep the task small.
4. **No backend or contract change:** the backend still returns `422` to anyone calling the API directly. The `422` part of `docs/api/auth.md` stays as is.
5. **#192 after task 1:** after task 1 is merged, run `/run-tasks 192` again. The child session continues on PR #197: merge `develop`, fix the sentence "422 cannot be sent" in `mobile/integration_test/delete_account_flow_test.dart` and the Evidence section (the case longer than 128 characters is blocked in the UI, `422` is checked by the remote data source test), then ask for a new review. The new run gets 2 new fix rounds.
6. **One plan for both:** the DECISIONS rule change (task 2) is in this plan to save one approval. To split it into its own plan, send "change 6".
7. **How Claude picks DECISIONS entries:** keep entries that are a gotcha or a repeatable convention; drop entries that are only follow-up work (put them in the report for planning) and entries that a test or lint already checks; merge duplicate entries; keep each file under 4 KB. The "decisions from run" PR is still opened after the run, not during it, and merged when its checks are green. The report says which entries were kept, which were dropped and why.

## Approach

### Mobile (`mobile/lib/features/auth/presentation/`)

- `bloc/delete_account_state.dart`: add `static const maxLength = 128`; a getter `lengthError` returns `Passwords are up to 128 characters.` when `password.length > maxLength`, otherwise `null`; `canSubmit` adds the condition `password.length <= maxLength`.
- `pages/delete_account_page.dart`: the Current Password field gets `errorText: form.lengthError`. No formatter is added.
- `DeleteAccountBloc` does not change: the button is disabled so there is no submit; if a submit event still arrives while `canSubmit` is false, the bloc ignores it as it does today (a test checks this again).
- Colors and spacing come from the theme and `app_tokens.dart`, with no numeric values written inline.

### Screen design

No new Figma frame. The Delete Account screen keeps the layout of #191 (based on frame `1:163`); only an error line is added under the field, in the same style as the Change Password error.

Wireframe (password too long):

```text
Delete Account
…explanation and Apple Health / Health Connect note (unchanged)…
Current Password
[•••••••••••••••••••••••••••••••••••••••••••• (129)]
Passwords are up to 128 characters.
[Delete account (disabled)]
```

### Claude rules (task 2)

- `CLAUDE.md`, the permission table, the row "Edit `backend/DECISIONS.md` or `mobile/DECISIONS.md`": Claude picks the entries by the rule in assumption 7, then opens one "decisions from run" PR after the run; merged when its checks are green. The user can still drop or add entries with a message in chat.
- `.claude/skills/run-tasks/SKILL.md`: the line "Never edit `DECISIONS.md`" and the "Decisions" part of step 5: after the report, the parent picks the entries, opens the PR `[infra] docs: decisions from run <date>`, merges it when its checks are green, and puts the PR link in the report.
- Line 8 of `backend/DECISIONS.md` and `mobile/DECISIONS.md`: "…and Claude picks them after the run" instead of "the user picks them".

### Changes the approval must cover

| Kind | Yes? | Details |
| --- | --- | --- |
| Public API / breaking contract | No | No endpoint or contract change. |
| Schema / migration that loses data | No | — |
| Auth / security boundary | No | Only a UI check is added; the backend checks as before. |
| Architecture / Claude rules | **Yes** | Task 2 changes a permission in `CLAUDE.md`: Claude picks the entries and opens and merges the "decisions from run" PR by itself. |
| Real data / production / cost | No | — |

## Risks

- **Mobile and backend limits drifting apart:** if the backend changes 128, mobile must change with it. A bloc test checks the 128/129-character boundary, and the contract test of #192 still runs the `422` case.
- **Counting characters:** Dart's `String.length` counts UTF-16 code units, while Pydantic counts code points. A password full of emoji may be blocked by mobile earlier than by the backend. Acceptable, because sign up and change password also use `String.length`.
- **Claude picking the wrong DECISIONS entries:** the PR still goes through review and CI, and the report says which entries were dropped and why; the user can drop an entry with one message.

## Verification

- **Mobile:** `flutter analyze`, `flutter test` (bloc, page, golden), a screenshot with `--dart-define=API_MODE=mock` when pasting 129 characters.
- **Infra:** `git grep -n "the user picks"` has no more results in `CLAUDE.md`, `.claude/` and both `DECISIONS.md` files; the repo's required checks and hook tests pass.
- **#192:** after task 1, PR #197 has an approving review for the new head (assumption 5).

## Ticket evidence

- **Task 1 (feature with UI):** no new Figma; the reference is the Delete Account screen of #191 (frame `1:163`) and the wireframe above. Behaviour: pasting 129 characters disables the button, shows `Passwords are up to 128 characters.`, and sends no request. The problem is real: the third review of PR #197 and `schemas.py` (`max_length=128`).
- **Task 2 (chore):** the scope is the four rule files above. Behaviour that stays the same: Claude does not edit `DECISIONS.md` during a run, each file stays under 4 KB, entries carry a date and an issue.

## Task breakdown

One task is one issue. Task 1 and task 2 do not depend on each other and can run in parallel (mobile and infra).

### Phase 1: Length check and DECISIONS rule

#### Task 1: `[auth] fix: delete account password length check (mobile)`

**Description:** The Delete Account screen disables the button and shows an error when the Current Password is longer than 128 characters, without truncating and without sending a request, as in Change Password.

**Acceptance criteria:**
- [ ] With a Current Password longer than 128 characters (typed or pasted), the Delete account button is disabled and the field shows `Passwords are up to 128 characters.`
- [ ] The field keeps every character entered (no truncation) and `AuthRepository.deleteAccount` is not called
- [ ] At 1 to 128 characters the screen behaves as before: existing tests and goldens of `delete_account_page` pass unchanged

**Verification:**
- Bloc test for `DeleteAccountState` at 128 and 129 characters (`canSubmit`, `lengthError`), and a submit event at 129 that calls no repository method
- Page test: pasting 129 characters shows the error and disables the button
- New golden `delete_account_page_too_long` at 375×667 and 430×932, text scale 1.0 and 2.0
- Screenshot with `API_MODE=mock`; `flutter analyze` and `flutter test` pass

**Dependencies:** None

**Files likely touched:**
- `mobile/lib/features/auth/presentation/bloc/delete_account_state.dart`
- `mobile/lib/features/auth/presentation/pages/delete_account_page.dart`
- `mobile/test/features/auth/presentation/bloc/delete_account_bloc_test.dart`, `pages/delete_account_page_test.dart`, `pages/delete_account_page_golden_test.dart` and the new golden
- `mobile/PROGRESS.md`

**Estimated scope:** S: 2 code files, about 20 lines, plus tests and goldens.

#### Task 2: `[infra] docs: Claude picks DECISIONS entries after a run`

**Description:** After each `/run-tasks`, Claude picks the DECISIONS entries by itself by the rule in assumption 7, opens the "decisions from run" PR and merges it when its checks are green, without the user picking them.

**Acceptance criteria:**
- [ ] The `CLAUDE.md` permission row for `backend/DECISIONS.md` and `mobile/DECISIONS.md` lets Claude pick the entries after a run, open the "decisions from run" PR and merge it when its checks are green; Claude still never edits them during a run
- [ ] `.claude/skills/run-tasks/SKILL.md` step 5 "Decisions" describes how the parent picks entries (keep repeatable gotchas and conventions, drop follow-ups and what a test or lint enforces, merge duplicates, each file under 4 KB) and lists kept and dropped entries with reasons in the report
- [ ] Line 8 of `backend/DECISIONS.md` and `mobile/DECISIONS.md` says Claude picks the entries after the run, and `git grep -n "the user picks"` finds nothing in `CLAUDE.md`, `.claude/` or either `DECISIONS.md`

**Verification:**
- `git grep` output in the Evidence
- The required checks (`backend`, `mobile`, `goldens`) and `.claude/hooks/test-block-forbidden-command.sh` pass
- The diff touches only the four files above and `backend/PROGRESS.md`

**Dependencies:** None

**Files likely touched:**
- `CLAUDE.md`
- `.claude/skills/run-tasks/SKILL.md`
- `backend/DECISIONS.md`, `mobile/DECISIONS.md` (line 8 only)
- `backend/PROGRESS.md`

**Estimated scope:** XS: 4 docs files, about 15 lines.

#### Checkpoint: After phase 1
- [ ] Task 1 and task 2 are merged, CI on `develop` is green.
- [ ] Run `/run-tasks 192` so #192 continues on PR #197 (assumption 5); PR #197 gets an approving review and is merged.
- [ ] The next run opens the decisions PR by itself under the new rule.

## Issues to create

The acceptance criteria are each task's Acceptance criteria above, word for word.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `[auth] fix: delete account password length check (mobile)` | frontend, area:auth | - [ ] With a Current Password longer than 128 characters (typed or pasted), the Delete account button is disabled and the field shows `Passwords are up to 128 characters.`<br>- [ ] The field keeps every character entered (no truncation) and `AuthRepository.deleteAccount` is not called<br>- [ ] At 1 to 128 characters the screen behaves as before: existing tests and goldens of `delete_account_page` pass unchanged | none |
| 2 | `[infra] docs: Claude picks DECISIONS entries after a run` | docs, area:infra | - [ ] The `CLAUDE.md` permission row for `backend/DECISIONS.md` and `mobile/DECISIONS.md` lets Claude pick the entries after a run, open the "decisions from run" PR and merge it when its checks are green; Claude still never edits them during a run<br>- [ ] `.claude/skills/run-tasks/SKILL.md` step 5 "Decisions" describes how the parent picks entries (keep repeatable gotchas and conventions, drop follow-ups and what a test or lint enforces, merge duplicates, each file under 4 KB) and lists kept and dropped entries with reasons in the report<br>- [ ] Line 8 of `backend/DECISIONS.md` and `mobile/DECISIONS.md` says Claude picks the entries after the run, and `git grep -n "the user picks"` finds nothing in `CLAUDE.md`, `.claude/` or either `DECISIONS.md` | none |
