# Plan 014: CI and Claude on GitHub Actions

Status: draft
Approved: <the user fills in the date>
Issues: <filled in after approval>

## Context

Run the repo's checks on every pull request, review every PR into `develop` automatically with Claude, and let collaborators ask `@claude` for help in issues and PRs. This is the top rung of the automation ladder:

| Rung | Where it runs | What it is for here | Plan |
| --- | --- | --- | --- |
| 1. `/goal`, `/loop` | One Claude session | Keep working until an issue's acceptance criteria pass; watch a PR | none needed |
| 2. Scheduled tasks | The user's Mac | Nightly integration tests on the Docker database, GitLab mirror reminder | 015, later |
| 3. Routines | Anthropic's cloud | Issue triage against the ticket evidence gate, `docs/api/` drift | 016, later |
| 4. GitHub Actions | GitHub runners | CI, automatic PR review, `@claude` mentions | **this plan** |

The repo has no CI. `CLAUDE.md` says so ("The repo has no CI right now, so say 'no pipeline'"), and the only automatic checks are the local Claude Code hooks: `check.sh` on `Stop`, `format-on-edit.sh` and `block-forbidden-command.sh`. They run only inside a Claude session on the user's Mac. A commit made by hand, or a PR from anyone else, is never checked.

Reviews have the same gap. Phase 5 step 2 runs the `code-reviewer` subagent when a PR opens, but only when Claude opened the PR in a local session.

The repo is **public** on GitHub (`huynguyennang-agilityio/claude-code-training`). Anyone can open a PR from a fork and comment on issues, so the Claude workflows must not run for strangers, must not run untrusted code next to the secret, and must not expose it.

## Open questions and assumptions

1. **Authentication: decided (the user, 2026-10-21).** The Claude workflows use a `CLAUDE_CODE_OAUTH_TOKEN` made with `claude setup-token`, so usage counts against the user's Pro/Max subscription instead of a separate API bill. The user adds the secret in the repo settings; Claude never handles the value. The README says how to switch to `ANTHROPIC_API_KEY` later (one input in each workflow).
2. **Local review: decided (the user, 2026-10-21).** The Action is the automatic review in Phase 5 step 2. Its prompt delegates to the `code-reviewer` subagent, so `.claude/agents/code-reviewer.md` and "Reviewing pull requests" in `CLAUDE.md` stay the only definition of a review. Locally, Claude runs `code-reviewer` only when the user asks (for example before pushing), or when the Action did not run: a fork PR, a missing secret, a failed workflow, or a PR into a branch other than `develop`.
3. **When to review: decided (the user, 2026-10-21).** Automatically on `opened`, `ready_for_review` and `reopened`. New commits (`synchronize`) do not trigger a review; a collaborator comments `@claude review` on the PR to get a fresh one.
4. **Model (assumption).** The review runs on `opus` (the `code-reviewer` agent's model since plan 013). The `@claude` mention workflow runs on `sonnet`, like the implementer agents.
5. **Pinned versions (assumption).** Flutter `3.38.5` (the local version), Python `3.12` (`pyproject.toml`), Postgres `17` (`docker-compose.yml`). Every third-party action is pinned to a full commit SHA, with the tag in a comment.
6. **Goldens run on Linux (assumption).** The golden tests use `alchemist` CI goldens (`goldens/ci/`), which render text as blocks and match on every platform, so `flutter test` including the `golden` tag runs on `ubuntu-latest`. If they do not match there, the mobile job skips the tag and the issue says so.
7. **Branch protection is the user's (assumption).** Making `backend` and `mobile` required checks on `develop` is a repo setting. The README lists them; the user turns it on once CI has run cleanly on a few PRs.
8. **No change to GitLab (assumption).** The workflows live in `.github/`, which GitLab ignores. The mirror is still updated by hand.

## Approach

Tooling only. No mobile, backend, API, schema or database change. It touches **security** (a secret, write permissions for a bot on a public repo) and **external cost** (Claude usage from the user's subscription on every reviewed PR). The approval must cover both.

### 1. CI workflows

- `.github/workflows/backend-ci.yml`: on `pull_request` into `develop` and `push` to `develop`, when `backend/**` or the workflow changes. One job, `backend`: install `requirements-dev.txt`, then `ruff check .`, `ruff format --check .`, `mypy`, `pytest tests/unit`, then `pytest tests/integration` against a `postgres:17` service container through `TEST_DATABASE_URL`. This also closes the gap the `Stop` hook leaves (it skips integration tests).
- `.github/workflows/mobile-ci.yml`: same triggers for `mobile/**`. One job, `mobile`: `flutter pub get`, `flutter analyze`, `flutter test`.
- Read-only token (`permissions: contents: read`), no secrets. The test database credentials are throwaway values in the workflow, used only by the service container. pip and pub caches keep the jobs fast.

### 2. The local hooks inside Actions

`.claude/settings.json` is committed, so Claude Code in Actions loads the same hooks. `block-forbidden-command.sh` keeps running there; it is the guard against pushing to `develop`. `check.sh` should not: the review runner has no Flutter or Python toolchain, so it would fail three stops in a row on every run, and the CI workflows already run those checks.

- `check.sh` exits 0 at the top when `GITHUB_ACTIONS=true`.
- `notify.sh` already does nothing off macOS; confirm it and add a test case.
- New `.claude/hooks/test-check.sh` with the skip case and a normal case.

### 3. Automatic review: `.github/workflows/claude-review.yml`

- **Triggers:** `pull_request` (never `pull_request_target`) into `develop` with types `opened`, `ready_for_review`, `reopened`; and `issue_comment` on a PR whose body starts with `@claude review`, from an `OWNER`, `MEMBER` or `COLLABORATOR`.
- **Skipped:** drafts, and every PR from a fork. For `pull_request` the `if:` compares `head.repo.full_name` with the repository. For `issue_comment` the payload does not say where the PR comes from, so a first step runs `gh pr view --json isCrossRepository` and stops the job when it is `true`. This matters beyond secrets: checking out a fork's branch would also load its `.claude/settings.json`, and its hooks would run shell commands with the token in the environment.
- **Action:** `anthropics/claude-code-action@v1`, pinned by SHA, `claude_code_oauth_token` from secrets, model `opus`, a turn limit. A `concurrency` group per PR cancels a run that a newer `@claude review` replaces.
- **Prompt:** use the `code-reviewer` subagent on this PR, following "Reviewing pull requests" in `CLAUDE.md`: the five steps in order, each under its heading, file and line for every finding, and a verdict. Also check that the PR links an issue (`Closes #`), names its plan, and that its `## Evidence` section covers each acceptance criterion of the linked issue or says `Not verified: <reason>`. Read the CI results if they are in. Post the review as one PR comment, updated on later runs instead of added again.
- **Permissions:** `contents: read`, `pull-requests: write`, `issues: read`, `id-token: write`. Allowed tools: read, grep, glob, the `Task` tool for the subagent, and read-only `git` and `gh pr`/`gh issue view` commands. No edits, no pushes.
- **Never** approves through the GitHub review API, merges, closes or labels. The verdict is text; the user still approves and merges (Phase 6).

```yaml
on:
  pull_request:
    branches: [develop]
    types: [opened, ready_for_review, reopened]
  issue_comment:
    types: [created]
concurrency:
  group: claude-review-${{ github.event.pull_request.number || github.event.issue.number }}
  cancel-in-progress: true
jobs:
  review:
    if: >-
      (github.event_name == 'pull_request' &&
       !github.event.pull_request.draft &&
       github.event.pull_request.head.repo.full_name == github.repository) ||
      (github.event_name == 'issue_comment' &&
       github.event.issue.pull_request &&
       startsWith(github.event.comment.body, '@claude review') &&
       contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association))
    permissions: { contents: read, pull-requests: write, issues: read, id-token: write }
    runs-on: ubuntu-latest
    steps:
      # issue_comment only: stop when the PR comes from a fork (gh pr view --json isCrossRepository)
      - uses: actions/checkout@<sha>  # v4
        with: { fetch-depth: 0 }
      - uses: anthropics/claude-code-action@<sha>  # v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          claude_args: --model opus --max-turns 30 --allowedTools "Read,Grep,Glob,Task,Bash(git diff:*),Bash(git log:*),Bash(gh pr view:*),Bash(gh pr diff:*),Bash(gh issue view:*)"
          prompt: |
            Use the code-reviewer subagent to review this PR ...
```

The sketch shows the shape. The issue settles the exact inputs, and how the PR head is checked out for `issue_comment`, against the action's docs at the pinned version.

### 4. `@claude` mentions: `.github/workflows/claude.yml`

- **Triggers:** `issue_comment`, `pull_request_review_comment`, `pull_request_review` and `issues` (opened, assigned) when the text contains `@claude`, except a comment that starts with `@claude review`, which belongs to `claude-review.yml`.
- **Only collaborators:** the job runs only when `author_association` is `OWNER`, `MEMBER` or `COLLABORATOR`. On a public repo, anyone else could otherwise spend the subscription or try prompt injection.
- **No fork PRs:** the same `isCrossRepository` check as the review, for the same reason (a fork's hooks would run next to the token).
- **Permissions:** `contents: write`, `pull-requests: write`, `issues: write`, `id-token: write`. It may push to its own `claude/…` branch or to the PR's branch, and open a PR into `develop`. `block-forbidden-command.sh` still refuses pushes to `develop`/`main`, force-pushes and branch deletes.
- `CLAUDE.md` applies there too. A request for non-trivial work without an approved plan gets an answer pointing at Phase 1, not code.

### 5. Docs

- `CLAUDE.md`:
  - Phase 3: the CI workflows run the same checks as the `Stop` hook, plus the integration tests.
  - Phase 5 step 2: the `claude-review.yml` Action reviews each PR into `develop` when it opens, and again on `@claude review`. Claude runs the `code-reviewer` subagent locally only when the user asks, or when the Action did not run (a fork PR, a missing secret, a failed workflow, another base branch).
  - Phase 6 step 4: report the CI result instead of "no pipeline".
  - "Reviewing pull requests" stays the single definition of the five steps.
- `docs/workflow.md`: the "no pipeline" note and the review step in the diagram.
- `README.md`: a short "CI and Claude on GitHub" section: what runs when, how to make and add `CLAUDE_CODE_OAUTH_TOKEN` (and how to switch to `ANTHROPIC_API_KEY`), how to ask for a new review, how to skip one (keep the PR in draft), and which checks to require on `develop`.

## Risks

- **CI uses up the subscription.** Runs share the user's Pro/Max limits with local work; a review took about 30 to 34 thousand tokens in the hook PRs. Contained by reviewing only on open and on request (question 3), skipping drafts, a turn limit, cancelling replaced runs, and the collaborator check. If limits become a problem, switching to an API key is one input per workflow.
- **Secret exposure or abuse on a public repo.** Contained by `pull_request` instead of `pull_request_target`, skipping every fork PR (including through `issue_comment`), the collaborator check, least-privilege permissions per job, and SHA-pinned actions.
- **Untrusted hooks.** A fork branch carries its own `.claude/settings.json`. Contained by never checking out fork code in the Claude workflows.
- **Prompt injection in PR or issue text.** The review job cannot write code or push. The mention job can, but only for collaborators, and the forbidden-command hook and branch rules still apply.
- **Flaky or slow CI.** Integration tests on a fresh Postgres and the Flutter setup can be slow. Contained by caching and by path filters, so a docs-only PR runs neither job.
- **A stale review.** Pushes after the review are not reviewed until someone asks. Contained by the README and the PR template reminder: comment `@claude review` before asking for merge.
- **A wrong review is trusted.** The verdict is advisory. Merging still needs the user's explicit approval (Phase 6).
- **The action changes behaviour at an update.** Pinned by SHA; updating it is a deliberate change.

## Verification

- `actionlint` on every workflow file.
- Each implementation PR is the test case: the CI jobs run and pass on it, and the review comment appears when it opens.
- A push to that PR triggers no review. `@claude review` from the owner account triggers one that updates the same comment.
- One throwaway PR with a deliberate failure (a `ruff` error, a failing Dart test) shows the job going red, then green after the fix.
- A draft PR gets no review. Marking it ready triggers one.
- `@claude` on a test issue from the owner account gets a reply, and `@claude review` there does not start the mention workflow.
- `.claude/hooks/test-check.sh` and `test-notify.sh` pass.
- Not verified: a fork PR and a comment from a non-collaborator. There is no second account. The `if:` conditions and the `isCrossRepository` step are reviewed instead, and the run log of the first real fork PR is checked when one arrives.

## Ticket evidence

Chore for every issue: the scope is above. Behaviour that must stay unchanged: the local hooks in a local session, the five review steps and their wording in `CLAUDE.md`, the `code-reviewer` agent definition, and every file outside `.github/`, `.claude/hooks/` and the three docs. No images needed. Verification evidence is the workflow run links, the review comment and the hook test output.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `ci: run backend and mobile checks on GitHub Actions` | chore, ci | - [ ] `backend-ci.yml` runs ruff, ruff format check, mypy, unit and integration tests against `postgres:17`<br>- [ ] `mobile-ci.yml` runs `flutter analyze` and `flutter test` on Flutter 3.38.5<br>- [ ] Path filters: a docs-only PR runs neither job<br>- [ ] Actions pinned by SHA, `contents: read` only, no secrets<br>- [ ] Evidence: `actionlint`, a green run, a red run on a deliberate failure | none |
| 2 | `chore: skip the Stop hook checks inside GitHub Actions` | chore | - [ ] `check.sh` exits 0 when `GITHUB_ACTIONS=true`; local behaviour unchanged<br>- [ ] `notify.sh` does nothing off macOS, covered by a test<br>- [ ] `block-forbidden-command.sh` is untouched<br>- [ ] Evidence: `test-check.sh` and `test-notify.sh` output | none |
| 3 | `ci: review every PR into develop with Claude` | chore, ci | - [ ] `claude-review.yml` as in Approach 3: on open, ready for review, reopen, and `@claude review` from a collaborator; not on new commits<br>- [ ] Skips drafts and every fork PR, including through `issue_comment`<br>- [ ] Delegates to the `code-reviewer` subagent; one comment with the five headings and a verdict, plus the issue, plan and Evidence checks, updated in place on later runs<br>- [ ] Read-only tools; never approves, merges, closes or labels<br>- [ ] Evidence: the review on this issue's own PR; a push with no review; `@claude review` updating the comment; a draft PR with no review | 2 |
| 4 | `ci: answer @claude mentions from collaborators` | chore, ci | - [ ] `claude.yml` as in Approach 4, ignoring `@claude review`<br>- [ ] Runs only for `OWNER`, `MEMBER` or `COLLABORATOR`, never on a fork PR<br>- [ ] Cannot push to `develop`/`main` (forbidden-command hook active)<br>- [ ] Evidence: a reply on a test issue; a `Not verified` line for a non-collaborator and a fork PR | 2 |
| 5 | `docs: describe CI and Claude on GitHub` | docs | - [ ] `CLAUDE.md` Phases 3, 5 and 6 updated as in Approach 5; no "no pipeline" text left<br>- [ ] `docs/workflow.md` matches `CLAUDE.md`<br>- [ ] `README.md` section: what runs, the secret to add, how to ask for and skip a review, checks to require<br>- [ ] Evidence: the diff and `grep -n "no pipeline"` with no match | 1, 3, 4 |

## Out of scope

- Rung 1 (`/goal`, `/loop`): no repo change, used from the next issue on.
- Rung 2, plan 015: local scheduled tasks for nightly integration tests on the Docker database, the GitLab mirror reminder (compare `origin/develop` with `gitlab/develop`, never push), and a weekly dependency report.
- Rung 3, plan 016: cloud routines for issue triage against the ticket evidence gate and for drift between `docs/api/` and `openapi.json`.
- Deploy, release or anything that touches `main`.
