# Plan 014: CI and Claude on GitHub Actions

Status: approved
Approved: 2026-10-21
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

The repo is **public** on GitHub (`huynguyennang-agilityio/claude-code-training`). Anyone can open a PR from a fork and comment on issues, so the Claude workflows must not run for strangers, must not run untrusted code next to the secret, and must not expose it. Nothing on GitHub protects `develop` or `main` today: the "never push to `develop`" rule is enforced only by `CLAUDE.md` and a best-effort local hook.

## Open questions and assumptions

1. **Authentication: decided (the user, 2026-10-21).** The Claude workflows use a `CLAUDE_CODE_OAUTH_TOKEN` made with `claude setup-token`, so usage counts against the user's Pro/Max subscription instead of a separate API bill. The user adds the secret in the repo settings; Claude never handles the value. The README says how to switch to `ANTHROPIC_API_KEY` later (one input in each workflow).
2. **Local review: decided (the user, 2026-10-21).** The Action is the automatic review in Phase 5 step 2. Its prompt delegates to the `code-reviewer` subagent, so `.claude/agents/code-reviewer.md` and "Reviewing pull requests" in `CLAUDE.md` stay the only definition of a review (Approach 5 moves the extra PR checks there). Locally, Claude runs `code-reviewer` only when the user asks (for example before pushing), or when the Action did not run: a fork PR, a missing secret, a failed workflow, or a PR into a branch other than `develop`.
3. **When to review: decided (the user, 2026-10-21).** Automatically on `opened`, `ready_for_review` and `reopened`. New commits (`synchronize`) do not trigger a review; a collaborator comments `@claude review` on the PR to get a fresh one.
4. **Branch protection is a prerequisite (the user does it).** Before issue 4 (which gives a bot `contents: write`), a ruleset on `develop` and `main` blocks direct pushes, force-pushes and deletion, and requires a PR. Required status checks (`backend`, `mobile`) are added to it once CI has run cleanly on a few PRs. These are repo settings: the plan and README list them, the user turns them on.
5. **The Claude GitHub App (the user does it).** The mention workflow needs the Claude GitHub App installed on the repo (`/install-github-app` or the App page), because it pushes branches and comments with the App's token. The review workflow does not: it uses the job's own `GITHUB_TOKEN`, so its `permissions:` block is the real limit.
6. **Model (assumption).** The review runs on `opus` (the `code-reviewer` agent's model since plan 013). The `@claude` mention workflow runs on `sonnet`, like the implementer agents.
7. **Pinned versions (assumption).** Flutter `3.38.5` (the local version; nothing in the repo pins it), Python `3.12` (`pyproject.toml`), Postgres `17` (`docker-compose.yml`). Every third-party action is pinned to a full commit SHA, with the tag in a comment.
8. **Goldens run on Linux (assumption).** `mobile/test/flutter_test_config.dart` turns platform goldens off and uses `alchemist` CI goldens (`goldens/ci/`), which render text as blocks and match on every platform, so `flutter test` including the `golden` tag runs on `ubuntu-latest`. If they do not match there, the mobile job skips the tag and the issue says so.
9. **Unknowns settled in issue 3 (assumption).** The plan was written without the action's docs at a pinned SHA. Issue 3 confirms against them: the input names, the sticky-comment option, whether the action loads the project's `.claude/settings.json` hooks, and whether the subagent tool is called `Agent` or `Task` in the bundled CLI. Where one differs, the issue follows the docs and says so in its PR; a change of design comes back to this plan.
10. **No change to GitLab (assumption).** The workflows live in `.github/`, which GitLab ignores. The mirror is still updated by hand.

## Approach

Tooling only. No mobile, backend, API, schema or database change. It touches a **security boundary** (a secret, a bot with write access on a public repo, branch protection) and **external cost** (Claude usage from the user's subscription on every reviewed PR). The approval must cover both.

### 1. CI workflows

- `.github/workflows/backend-ci.yml` and `.github/workflows/mobile-ci.yml`, both on every `pull_request` into `develop` and every `push` to `develop`, with **no** `paths:` filter on the trigger. A required check that never reports stays pending and blocks the merge, so each workflow always runs and decides inside: a first step (`dorny/paths-filter`, pinned) checks for changes, and the remaining steps run only when it matches, otherwise the job passes in seconds.
  - Backend matches `backend/**`, `docs/api/**` and the workflow file. `docs/api/**` is included because the backend's contract tests read it (`test_api_examples.py`, `test_openapi_snapshot.py`, `test_error_contract.py`, `test_*_contract.py`, `test_auth_sweep.py`).
  - Mobile matches `mobile/**`, `docs/api/**` (read by `mobile/test/contract/*_examples_test.dart`) and the workflow file.
- Job `backend`: install `requirements-dev.txt`; run `ruff check .`, `ruff format --check .`, `mypy`, `pytest tests/unit`; then `pytest tests/integration` against a `postgres:17` service container. The job sets throwaway `DATABASE_URL`, `TEST_DATABASE_URL` (a database name ending in `_test`, as `tests/integration/conftest.py` requires) and `JWT_SECRET`, because `Settings` requires them and the runner has no `.env`. This also closes the gap the `Stop` hook leaves (it skips integration tests).
- Job `mobile`: `flutter pub get`, `flutter analyze`, `flutter test`.
- Read-only token (`permissions: contents: read`), no secrets. pip and pub caches keep the jobs fast.

### 2. The local hooks inside Actions

`.claude/settings.json` is committed, so Claude Code in Actions may load the same hooks (issue 3 confirms it).

- `check.sh` exits 0 at the top when `GITHUB_ACTIONS=true`. The review runner has no Flutter or Python toolchain, and with `fetch-depth: 0` the hook would find `origin/develop`, run the checks and fail three stops in a row. The CI workflows already run them.
- `notify.sh` already exits off macOS, and `test-notify.sh` already covers it (`FAKE_UNAME=Linux`). No change.
- New `.claude/hooks/test-check.sh` with the skip case and a normal case.
- `block-forbidden-command.sh` is unchanged. In Actions it is defence in depth only: it matches the `Bash` tool, its own header says it is not a security boundary, and the action can push through its own file tools or the App token without calling `Bash`. The guard for `develop` and `main` is the ruleset (assumption 4).

### 3. Automatic review: `.github/workflows/claude-review.yml`

- **Triggers:** `pull_request` (never `pull_request_target`) into `develop` with types `opened`, `ready_for_review`, `reopened`; and `issue_comment` on a PR whose body starts with `@claude review`, from an `OWNER`, `MEMBER` or `COLLABORATOR` (`github.event.comment.author_association`).
- **Gate job first, fail closed.** A `gate` job with no checkout and no secret runs `gh pr view <n> --json isCrossRepository,isDraft,baseRefName` with `GH_TOKEN: ${{ github.token }}` and `set -euo pipefail`. It outputs `ok=true` only when the PR is not from a fork, not a draft and targets `develop`; any error fails the job. The `review` job `needs: gate` and runs only on `ok == 'true'`. This covers `issue_comment`, whose payload does not say where the PR comes from. Fork code must never be checked out here: it would bring its own `.claude/settings.json`, and its hooks would run shell commands next to the token.
- **Concurrency inside the `review` job,** not at workflow level. GitHub applies a workflow-level group before the job's `if:`, so any comment on the PR (a "thanks", the action's own comment) would start a run that cancels the review in progress. In the job, a skipped job never joins the group. Group `claude-review-<PR number>`, `cancel-in-progress: true`, so a newer `@claude review` replaces an older one.
- **Token:** `github_token: ${{ secrets.GITHUB_TOKEN }}` with job `permissions: contents: read, pull-requests: write, issues: read`. Without it the action trades OIDC for the Claude App's token, whose scope comes from the App installation and not from `permissions:`. Comments made with `GITHUB_TOKEN` also do not trigger other workflows, so the review comment cannot start a run.
- **Action:** `anthropics/claude-code-action@v1`, pinned by SHA, `claude_code_oauth_token` from secrets, model `opus`, `--max-turns 30`.
- **Prompt:** use the `code-reviewer` subagent to review this PR, following "Reviewing pull requests" in `CLAUDE.md`. Take lint and test results from the CI runs on the PR instead of running them (the runner has no toolchains).
- **Posting:** one PR comment, updated in place on later runs, through the action's sticky-comment option. If that option does not fit, the fallback is `Bash(gh pr comment:*)` with `--edit-last`. `gh pr review` (which can approve) stays out of the allowlist.
- **Allowed tools:** `Read`, `Grep`, `Glob`, the subagent tool (`Agent`, or `Task` in older CLIs), and the read-only commands `code-reviewer.md` names: `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git show:*)`, `Bash(ls:*)`, `Bash(cat:*)`, `Bash(rg:*)`, `Bash(gh pr view:*)`, `Bash(gh pr diff:*)`, `Bash(gh pr checks:*)`, `Bash(gh issue view:*)`. A headless run cannot approve anything else, so a missing entry just wastes turns on denials.
- **Never** approves through the GitHub review API, merges, closes or labels. The verdict is text; the user still approves and merges (Phase 6).

```yaml
on:
  pull_request:
    branches: [develop]
    types: [opened, ready_for_review, reopened]
  issue_comment:
    types: [created]
jobs:
  gate:
    if: >-
      github.event_name == 'pull_request' ||
      (github.event.issue.pull_request &&
       startsWith(github.event.comment.body, '@claude review') &&
       contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association))
    runs-on: ubuntu-latest
    permissions: { pull-requests: read }
    outputs: { ok: ${{ steps.check.outputs.ok }} }
    steps:
      - id: check
        env: { GH_TOKEN: ${{ github.token }}, PR: ${{ github.event.pull_request.number || github.event.issue.number }} }
        run: |
          set -euo pipefail
          gh pr view "$PR" --repo "$GITHUB_REPOSITORY" --json isCrossRepository,isDraft,baseRefName \
            --jq 'if (.isCrossRepository or .isDraft or .baseRefName != "develop") then "ok=false" else "ok=true" end' >> "$GITHUB_OUTPUT"
  review:
    needs: gate
    if: needs.gate.outputs.ok == 'true'
    concurrency:
      group: claude-review-${{ github.event.pull_request.number || github.event.issue.number }}
      cancel-in-progress: true
    runs-on: ubuntu-latest
    permissions: { contents: read, pull-requests: write, issues: read }
    steps:
      - uses: actions/checkout@<sha>  # v4, the PR head of this repo
        with: { fetch-depth: 0 }
      - uses: anthropics/claude-code-action@<sha>  # v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          use_sticky_comment: true
          claude_args: --model opus --max-turns 30 --allowedTools "Read,Grep,Glob,Agent,Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(ls:*),Bash(cat:*),Bash(rg:*),Bash(gh pr view:*),Bash(gh pr diff:*),Bash(gh pr checks:*),Bash(gh issue view:*)"
          prompt: |
            Use the code-reviewer subagent to review this PR ...
```

The sketch shows the shape; issue 3 settles the exact inputs and how the PR head is checked out for `issue_comment` (assumption 9).

### 4. `@claude` mentions: `.github/workflows/claude.yml`

- **Prerequisites:** the ruleset on `develop` and `main` (assumption 4) and the Claude GitHub App (assumption 5).
- **Triggers and who may start it.** The text and the author are read from a different field per event:

  | Event | Text | Author checked |
  | --- | --- | --- |
  | `issue_comment` (created) | `comment.body` | `comment.author_association` |
  | `pull_request_review_comment` (created) | `comment.body` | `comment.author_association` |
  | `pull_request_review` (submitted) | `review.body` | `review.author_association` |
  | `issues` (opened) | `issue.title`, `issue.body` | `issue.author_association` |

  The author must be `OWNER`, `MEMBER` or `COLLABORATOR`. `issues: assigned` is left out: the assigner is a collaborator, but the issue text may come from a stranger, and a collaborator who wants help can comment `@claude` instead. An `issue_comment` whose body starts with `@claude review` is excluded (`!startsWith(github.event.comment.body, '@claude review')`, the same field the review workflow matches).
- **No fork PRs:** on PR events, the same fail-closed `gate` job as the review (`isCrossRepository` only).
- **Token and permissions:** the Claude App's token. It may push to its own `claude/…` branch or to the PR's branch, and open a PR into `develop`; the ruleset refuses anything aimed at `develop` or `main`.
- `CLAUDE.md` applies there too. A request for non-trivial work without an approved plan gets an answer pointing at Phase 1, not code.

```yaml
jobs:
  claude:
    if: >-
      (github.event_name == 'issue_comment' &&
       contains(github.event.comment.body, '@claude') &&
       !startsWith(github.event.comment.body, '@claude review') &&
       contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association)) ||
      (github.event_name == 'pull_request_review_comment' &&
       contains(github.event.comment.body, '@claude') &&
       contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association)) ||
      (github.event_name == 'pull_request_review' &&
       contains(github.event.review.body, '@claude') &&
       contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.review.author_association)) ||
      (github.event_name == 'issues' &&
       (contains(github.event.issue.body, '@claude') || contains(github.event.issue.title, '@claude')) &&
       contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.issue.author_association))
```

### 5. Docs

- `CLAUDE.md`:
  - Phase 3: the CI workflows run the same checks as the `Stop` hook, plus the integration tests.
  - Phase 5 step 2: the `claude-review.yml` Action reviews each PR into `develop` when it opens, and again on `@claude review`. Claude runs the `code-reviewer` subagent locally only when the user asks, or when the Action did not run (a fork PR, a missing secret, a failed workflow, another base branch).
  - Phase 6 step 4: report the CI result instead of "no pipeline".
  - "Reviewing pull requests": step 1 also checks that the PR links an issue (`Closes #`) and names its plan, and step 2 checks that `## Evidence` covers each acceptance criterion of the linked issue or says `Not verified: <reason>`. These were in the workflow prompt; putting them here keeps a local and an Action review the same.
  - "Git and GitHub permissions": the Claude workflows follow the same table; the `develop`/`main` ruleset backs it on GitHub.
- `docs/workflow.md`: the "no pipeline" note and the review step in the diagram.
- `.github/pull_request_template.md`: one line above the review checklist: "Comment `@claude review` after your last push, before asking for a merge."
- `README.md`: a short "CI and Claude on GitHub" section: what runs when; the prerequisites (ruleset, Claude GitHub App, the `CLAUDE_CODE_OAUTH_TOKEN` secret and how to switch to `ANTHROPIC_API_KEY`); how to ask for a new review and how to skip one (keep the PR in draft); which status checks to require on `develop`.

## Risks

- **CI uses up the subscription.** Runs share the user's Pro/Max limits with local work; a review took about 30 to 34 thousand tokens in the hook PRs. Contained by reviewing only on open and on request, skipping drafts, a turn limit, cancelling replaced runs and the collaborator check. If limits become a problem, switching to an API key is one input per workflow.
- **Secret exposure or abuse on a public repo.** Contained by `pull_request` instead of `pull_request_target`, the fail-closed gate that skips every fork PR (including through `issue_comment`), the collaborator check per event, and SHA-pinned actions.
- **Untrusted hooks.** A fork branch carries its own `.claude/settings.json`. Contained by never checking out fork code in the Claude workflows.
- **A bot writes to `develop` or `main`.** The local hook cannot stop the action's own tools or the App token. Contained by the ruleset (assumption 4), which is a prerequisite for issue 4.
- **Token scope wider than `permissions:`.** The App token's scope comes from its installation. Contained by giving the review job `GITHUB_TOKEN`, and giving the App token only to the mention job, which is limited to collaborators.
- **A PR changes its own review.** A same-repo PR's head carries the `CLAUDE.md`, `code-reviewer.md` and `.claude/settings.json` its review reads, so the PR can change the instructions it is reviewed with. Accepted: only collaborators can push branches here, and the user still reads the diff before merging.
- **Prompt injection in PR or issue text.** The review job cannot write code or push. The mention job can, but only for collaborators, and the ruleset still applies.
- **Flaky or slow CI.** Integration tests on a fresh Postgres and the Flutter setup can be slow. Contained by caching, and by the in-job change check, so a docs-only PR passes both jobs in seconds.
- **A stale review.** Pushes after the review are not reviewed until someone asks. Contained by the README and the PR template line.
- **A wrong review is trusted.** The verdict is advisory. Merging still needs the user's explicit approval (Phase 6).
- **The action changes behaviour at an update.** Pinned by SHA; updating it is a deliberate change.

## Verification

- `actionlint` on every workflow file.
- Each implementation PR is the test case: the CI jobs run and pass on it, and the review comment appears when it opens.
- A docs-only PR (README) reports `backend` and `mobile` as passed without running their checks; a PR that only changes `docs/api/examples/` runs both.
- One throwaway PR with a deliberate failure (a `ruff` error, a failing Dart test) shows the job going red, then green after the fix.
- A draft PR gets no review. Marking it ready triggers one.
- A push to a reviewed PR triggers no review. `@claude review` from the owner account triggers one that **edits** the existing comment instead of adding a second.
- An unrelated comment ("thanks") posted while a review runs does not cancel it.
- `@claude review` on a PR into a branch other than `develop` is skipped by the gate.
- The run log of the review shows whether the project hooks loaded (the `check.sh` skip line), and the subagent was called.
- `@claude` on a test issue from the owner account gets a reply, and `@claude review` there does not start the mention workflow.
- With the ruleset on, asking `@claude` on a test issue to push a commit to `develop` is refused by GitHub, and the run log shows the refusal.
- The gate's `if:` and `jq` expression are checked against a sample fork `pull_request` payload and a sample `issue_comment` payload (for example with `act`), since there is no second account.
- `.claude/hooks/test-check.sh` and `test-notify.sh` pass.
- Not verified: a real fork PR and a comment from a real non-collaborator. There is no second account. The run log of the first real fork PR is checked when one arrives.

## Ticket evidence

Chore for every issue: the scope is above. Behaviour that must stay unchanged: the local hooks in a local session, the `code-reviewer` agent definition, the five review steps (issue 5 adds the PR checks to steps 1 and 2 and changes nothing else), and every file outside `.github/`, `.claude/hooks/` and the docs listed in Approach 5. No images needed. Verification evidence is the workflow run links, the review comment and the hook test output.

## Issues to create

The repo has no `ci` label, so every issue uses `chore` or `docs`.

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `ci: run backend and mobile checks on GitHub Actions` | chore | - [ ] `backend-ci.yml` runs ruff, ruff format check, mypy, unit and integration tests against `postgres:17`, with throwaway `DATABASE_URL`, `TEST_DATABASE_URL` and `JWT_SECRET`<br>- [ ] `mobile-ci.yml` runs `flutter analyze` and `flutter test` on Flutter 3.38.5<br>- [ ] Both always report: an in-job change check over `backend/**` or `mobile/**`, `docs/api/**` and the workflow file; otherwise the job passes without running checks<br>- [ ] Actions pinned by SHA, `contents: read` only, no secrets<br>- [ ] Evidence: `actionlint`; a green run; a red run on a deliberate failure; a docs-only PR passing both jobs; a `docs/api/examples/` PR running both | none |
| 2 | `chore: skip the Stop hook checks inside GitHub Actions` | chore | - [ ] `check.sh` exits 0 when `GITHUB_ACTIONS=true`; local behaviour unchanged<br>- [ ] New `test-check.sh` covers the skip and a normal case; the existing Linux case in `test-notify.sh` still passes<br>- [ ] `block-forbidden-command.sh` is untouched<br>- [ ] Evidence: `test-check.sh` and `test-notify.sh` output | none |
| 3 | `ci: review every PR into develop with Claude` | chore | - [ ] `claude-review.yml` as in Approach 3: on open, ready for review, reopen, and `@claude review` from a collaborator; not on new commits<br>- [ ] A fail-closed gate job skips forks, drafts and other base branches before any checkout<br>- [ ] `concurrency` in the review job; an unrelated comment does not cancel a review<br>- [ ] Uses `GITHUB_TOKEN` with read-only `contents`; delegates to `code-reviewer`; the allowlist covers the agent's read-only commands and nothing that writes, approves or merges<br>- [ ] One sticky comment, edited on later runs<br>- [ ] The unknowns in assumption 9 are confirmed against the action's docs and noted in the PR<br>- [ ] Evidence: the review on this issue's own PR; a push with no review; `@claude review` editing the comment; a draft PR with no review; the gate against sample payloads | 1, 2 |
| 4 | `ci: answer @claude mentions from collaborators` | chore | - [ ] Prerequisites in place and shown: the `develop`/`main` ruleset and the Claude GitHub App<br>- [ ] `claude.yml` as in Approach 4: the per-event author check, no `issues: assigned`, ignoring `@claude review`, the gate on PR events<br>- [ ] A request to push to `develop` is refused by GitHub<br>- [ ] Evidence: a reply on a test issue; the refused push; `Not verified` lines for a real non-collaborator and a real fork PR | 2, 3 |
| 5 | `docs: describe CI and Claude on GitHub` | docs | - [ ] `CLAUDE.md` updated as in Approach 5, including the PR checks in "Reviewing pull requests"; no "no pipeline" text left<br>- [ ] `docs/workflow.md` matches `CLAUDE.md`<br>- [ ] `.github/pull_request_template.md` has the `@claude review` line<br>- [ ] `README.md` section: what runs, the prerequisites and secret, how to ask for and skip a review, checks to require<br>- [ ] Evidence: the diff and `grep -n "no pipeline"` with no match | 1, 3, 4 |

## Out of scope

- Rung 1 (`/goal`, `/loop`): no repo change, used from the next issue on.
- Rung 2, plan 015: local scheduled tasks for nightly integration tests on the Docker database, the GitLab mirror reminder (compare `origin/develop` with `gitlab/develop`, never push), and a weekly dependency report.
- Rung 3, plan 016: cloud routines for issue triage against the ticket evidence gate and for drift between `docs/api/` and `openapi.json`.
- Deploy, release or anything that touches `main`.
